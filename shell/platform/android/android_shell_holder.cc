// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#define FML_USED_ON_EMBEDDER

#include "flutter/shell/platform/android/android_shell_holder.h"

#include <pthread.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <memory>
#include <optional>

#include <sstream>
#include <string>
#include <utility>

#include "flutter/fml/logging.h"
#include "flutter/fml/make_copyable.h"
#include "flutter/fml/message_loop.h"
#include "flutter/fml/native_library.h"
#include "flutter/fml/platform/android/jni_util.h"
#include "flutter/lib/ui/painting/image_generator_registry.h"
#include "flutter/shell/common/rasterizer.h"
#include "flutter/shell/common/run_configuration.h"
#include "flutter/shell/common/thread_host.h"
#include "flutter/shell/platform/android/android_image_generator.h"
#include "flutter/shell/platform/android/context/android_context.h"
#include "flutter/shell/platform/android/platform_view_android.h"

namespace flutter {

static PlatformData GetDefaultPlatformData() {
  PlatformData platform_data;
  platform_data.lifecycle_state = "AppLifecycleState.detached";
  return platform_data;
}

AndroidShellHolder::AndroidShellHolder(
    flutter::Settings settings,
    std::shared_ptr<PlatformViewAndroidJNI> jni_facade,
    bool is_background_view)
    : settings_(std::move(settings)), jni_facade_(jni_facade) {
  static size_t thread_host_count = 1;
  auto thread_label = std::to_string(thread_host_count++);

  thread_host_ = std::make_shared<ThreadHost>();
  if (is_background_view) {
    *thread_host_ = {thread_label, ThreadHost::Type::UI};
  } else {
    *thread_host_ = {thread_label, ThreadHost::Type::UI |
                                       ThreadHost::Type::RASTER |
                                       ThreadHost::Type::IO};
  }

  fml::WeakPtr<PlatformViewAndroid> weak_platform_view;
  Shell::CreateCallback<PlatformView> on_create_platform_view =
      [is_background_view, &jni_facade, &weak_platform_view](Shell& shell) {
        std::unique_ptr<PlatformViewAndroid> platform_view_android;
        platform_view_android = std::make_unique<PlatformViewAndroid>(
            shell,                   // delegate
            shell.GetTaskRunners(),  // task runners
            jni_facade,              // JNI interop
            shell.GetSettings()
                .enable_software_rendering,  // use software rendering
            !is_background_view              // create onscreen surface
        );
        weak_platform_view = platform_view_android->GetWeakPtr();
        auto display = Display(jni_facade->GetDisplayRefreshRate());
        shell.OnDisplayUpdates(DisplayUpdateType::kStartup, {display});
        return platform_view_android;
      };

  Shell::CreateCallback<Rasterizer> on_create_rasterizer = [](Shell& shell) {
    return std::make_unique<Rasterizer>(shell);
  };

  // The current thread will be used as the platform thread. Ensure that the
  // message loop is initialized.
  fml::MessageLoop::EnsureInitializedForCurrentThread();
  fml::RefPtr<fml::TaskRunner> raster_runner;
  fml::RefPtr<fml::TaskRunner> ui_runner;
  fml::RefPtr<fml::TaskRunner> io_runner;
  fml::RefPtr<fml::TaskRunner> platform_runner =
      fml::MessageLoop::GetCurrent().GetTaskRunner();
  if (is_background_view) {
    auto single_task_runner = thread_host_->ui_thread->GetTaskRunner();
    raster_runner = single_task_runner;
    ui_runner = single_task_runner;
    io_runner = single_task_runner;
  } else {
    raster_runner = thread_host_->raster_thread->GetTaskRunner();
    ui_runner = thread_host_->ui_thread->GetTaskRunner();
    io_runner = thread_host_->io_thread->GetTaskRunner();
  }

  flutter::TaskRunners task_runners(thread_label,     // label
                                    platform_runner,  // platform
                                    raster_runner,    // raster
                                    ui_runner,        // ui
                                    io_runner         // io
  );
  task_runners.GetRasterTaskRunner()->PostTask([]() {
    // Android describes -8 as "most important display threads, for
    // compositing the screen and retrieving input events". Conservatively
    // set the raster thread to slightly lower priority than it.
    if (::setpriority(PRIO_PROCESS, gettid(), -5) != 0) {
      // Defensive fallback. Depending on the OEM, it may not be possible
      // to set priority to -5.
      if (::setpriority(PRIO_PROCESS, gettid(), -2) != 0) {
        FML_LOG(ERROR) << "Failed to set raster task runner priority";
      }
    }
  });
  task_runners.GetUITaskRunner()->PostTask([]() {
    if (::setpriority(PRIO_PROCESS, gettid(), -1) != 0) {
      FML_LOG(ERROR) << "Failed to set UI task runner priority";
    }
  });
  task_runners.GetIOTaskRunner()->PostTask([]() {
    if (::setpriority(PRIO_PROCESS, gettid(), 1) != 0) {
      FML_LOG(ERROR) << "Failed to set IO task runner priority";
    }
  });

  shell_ =
      Shell::Create(GetDefaultPlatformData(),  // window data
                    task_runners,              // task runners
                    settings_,                 // settings
                    on_create_platform_view,   // platform view create callback
                    on_create_rasterizer       // rasterizer create callback
      );

  if (shell_) {
    shell_->GetDartVM()->GetConcurrentMessageLoop()->PostTaskToAllWorkers([]() {
      if (::setpriority(PRIO_PROCESS, gettid(), 1) != 0) {
        FML_LOG(ERROR) << "Failed to set Workers task runner priority";
      }
    });

    shell_->RegisterImageDecoder(
        [runner = task_runners.GetIOTaskRunner()](sk_sp<SkData> buffer) {
          return AndroidImageGenerator::MakeFromData(buffer, runner);
        },
        -1);
    FML_DLOG(INFO) << "Registered Android SDK image decoder (API level 28+)";
  }

  platform_view_ = weak_platform_view;
  FML_DCHECK(platform_view_);
  is_valid_ = shell_ != nullptr;
}

AndroidShellHolder::AndroidShellHolder(
    const Settings& settings,
    const std::shared_ptr<PlatformViewAndroidJNI>& jni_facade,
    const std::shared_ptr<ThreadHost>& thread_host,
    std::unique_ptr<Shell> shell,
    const fml::WeakPtr<PlatformViewAndroid>& platform_view)
    : settings_(std::move(settings)),
      jni_facade_(jni_facade),
      platform_view_(platform_view),
      thread_host_(thread_host),
      shell_(std::move(shell)) {
  FML_DCHECK(jni_facade);
  FML_DCHECK(shell_);
  FML_DCHECK(shell_->IsSetup());
  FML_DCHECK(platform_view_);
  FML_DCHECK(thread_host_);
  is_valid_ = shell_ != nullptr;
}

AndroidShellHolder::~AndroidShellHolder() {
  shell_.reset();
  thread_host_.reset();
}

bool AndroidShellHolder::IsValid() const {
  return is_valid_;
}

const flutter::Settings& AndroidShellHolder::GetSettings() const {
  return settings_;
}

std::unique_ptr<AndroidShellHolder> AndroidShellHolder::Spawn(
    std::shared_ptr<PlatformViewAndroidJNI> jni_facade,
    const std::string& entrypoint,
    const std::string& libraryUrl) const {
  FML_DCHECK(shell_ && shell_->IsSetup())
      << "A new Shell can only be spawned "
         "if the current Shell is properly constructed";

  // Pull out the new PlatformViewAndroid from the new Shell to feed to it to
  // the new AndroidShellHolder.
  //
  // It's a weak pointer because it's owned by the Shell (which we're also)
  // making below. And the AndroidShellHolder then owns the Shell.
  fml::WeakPtr<PlatformViewAndroid> weak_platform_view;

  // Take out the old AndroidContext to reuse inside the PlatformViewAndroid
  // of the new Shell.
  PlatformViewAndroid* android_platform_view = platform_view_.get();
  // There's some indirection with platform_view_ being a weak pointer but
  // we just checked that the shell_ exists above and a valid shell is the
  // owner of the platform view so this weak pointer always exists.
  FML_DCHECK(android_platform_view);
  std::shared_ptr<flutter::AndroidContext> android_context =
      android_platform_view->GetAndroidContext();
  FML_DCHECK(android_context);

  // This is a synchronous call, so the captures don't have race checks.
  Shell::CreateCallback<PlatformView> on_create_platform_view =
      [&jni_facade, android_context, &weak_platform_view](Shell& shell) {
        std::unique_ptr<PlatformViewAndroid> platform_view_android;
        platform_view_android = std::make_unique<PlatformViewAndroid>(
            shell,                   // delegate
            shell.GetTaskRunners(),  // task runners
            jni_facade,              // JNI interop
            android_context          // Android context
        );
        weak_platform_view = platform_view_android->GetWeakPtr();
        auto display = Display(jni_facade->GetDisplayRefreshRate());
        shell.OnDisplayUpdates(DisplayUpdateType::kStartup, {display});
        return platform_view_android;
      };

  Shell::CreateCallback<Rasterizer> on_create_rasterizer = [](Shell& shell) {
    return std::make_unique<Rasterizer>(shell);
  };

  // TODO(xster): could be worth tracing this to investigate whether
  // the IsolateConfiguration could be cached somewhere.
  auto config = BuildRunConfiguration(asset_manager_, entrypoint, libraryUrl);
  if (!config) {
    // If the RunConfiguration was null, the kernel blob wasn't readable.
    // Fail the whole thing.
    return nullptr;
  }

  std::unique_ptr<flutter::Shell> shell = shell_->Spawn(
      std::move(config.value()), on_create_platform_view, on_create_rasterizer);

  return std::unique_ptr<AndroidShellHolder>(
      new AndroidShellHolder(GetSettings(), jni_facade, thread_host_,
                             std::move(shell), weak_platform_view));
}

void AndroidShellHolder::Launch(std::shared_ptr<AssetManager> asset_manager,
                                const std::string& entrypoint,
                                const std::string& libraryUrl) {
  if (!IsValid()) {
    return;
  }

  asset_manager_ = asset_manager;
  auto config = BuildRunConfiguration(asset_manager, entrypoint, libraryUrl);
  if (!config) {
    return;
  }
  shell_->RunEngine(std::move(config.value()));
}

Rasterizer::Screenshot AndroidShellHolder::Screenshot(
    Rasterizer::ScreenshotType type,
    bool base64_encode) {
  if (!IsValid()) {
    return {nullptr, SkISize::MakeEmpty()};
  }
  return shell_->Screenshot(type, base64_encode);
}

fml::WeakPtr<PlatformViewAndroid> AndroidShellHolder::GetPlatformView() {
  FML_DCHECK(platform_view_);
  return platform_view_;
}

void AndroidShellHolder::NotifyLowMemoryWarning() {
  FML_DCHECK(shell_);
  shell_->NotifyLowMemoryWarning();
}

std::optional<RunConfiguration> AndroidShellHolder::BuildRunConfiguration(
    std::shared_ptr<flutter::AssetManager> asset_manager,
    const std::string& entrypoint,
    const std::string& libraryUrl) const {
  std::unique_ptr<IsolateConfiguration> isolate_configuration;
  if (flutter::DartVM::IsRunningPrecompiledCode()) {
    isolate_configuration = IsolateConfiguration::CreateForAppSnapshot();
  } else {
    std::unique_ptr<fml::Mapping> kernel_blob =
        fml::FileMapping::CreateReadOnly(
            GetSettings().application_kernel_asset);
    if (!kernel_blob) {
      FML_DLOG(ERROR) << "Unable to load the kernel blob asset.";
      return std::nullopt;
    }
    isolate_configuration =
        IsolateConfiguration::CreateForKernel(std::move(kernel_blob));
  }

  RunConfiguration config(std::move(isolate_configuration),
                          std::move(asset_manager));

  {
    if ((entrypoint.size() > 0) && (libraryUrl.size() > 0)) {
      config.SetEntrypointAndLibrary(std::move(entrypoint),
                                     std::move(libraryUrl));
    } else if (entrypoint.size() > 0) {
      config.SetEntrypoint(std::move(entrypoint));
    }
  }
  return config;
}

}  // namespace flutter
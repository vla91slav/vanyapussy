// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTER_ENGINE_INTERNAL_H_
#define FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTER_ENGINE_INTERNAL_H_

#import "flutter/shell/platform/darwin/ios/framework/Headers/FlutterEngine.h"

#include "flutter/fml/memory/weak_ptr.h"
#include "flutter/fml/task_runner.h"
#include "flutter/lib/ui/window/pointer_data_packet.h"
#include "flutter/lib/ui/window/viewport_metrics.h"
#include "flutter/shell/common/platform_view.h"
#include "flutter/shell/common/rasterizer.h"
#include "flutter/shell/common/shell.h"

// Embedder header included as an implementation detail (See BUILD.gn), iOS
// doesn't use the embedding API, just some structures from it.
#include "flutter/shell/platform/embedder/embedder.h"

#import "flutter/shell/platform/darwin/ios/framework/Headers/FlutterEngine.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterDartProject_Internal.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterPlatformPlugin.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterPlatformViews_Internal.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterRestorationPlugin.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterTextInputDelegate.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterTextInputPlugin.h"
#import "flutter/shell/platform/darwin/ios/platform_view_ios.h"

extern NSString* _Nonnull const FlutterEngineWillDealloc;

@interface FlutterEngine () <FlutterViewEngineDelegate>

- (flutter::Shell&)shell;

- (void)updateViewportMetrics:(flutter::ViewportMetrics)viewportMetrics;
- (void)dispatchPointerDataPacket:(std::unique_ptr<flutter::PointerDataPacket>)packet;

- (fml::RefPtr<fml::TaskRunner>)platformTaskRunner;
- (fml::RefPtr<fml::TaskRunner>)RasterTaskRunner;

- (fml::WeakPtr<flutter::PlatformView>)platformView;

- (flutter::Rasterizer::Screenshot)screenshot:(flutter::Rasterizer::ScreenshotType)type
                                 base64Encode:(bool)base64Encode;

- (nonnull FlutterPlatformPlugin*)platformPlugin;
- (std::shared_ptr<flutter::FlutterPlatformViewsController>&)platformViewsController;
- (nonnull FlutterTextInputPlugin*)textInputPlugin;
- (nonnull FlutterRestorationPlugin*)restorationPlugin;
- (void)launchEngine:(nullable NSString*)entrypoint libraryURI:(nullable NSString*)libraryOrNil;
- (BOOL)createShell:(nullable NSString*)entrypoint
         libraryURI:(nullable NSString*)libraryOrNil
       initialRoute:(nullable NSString*)initialRoute;
- (void)attachView;
- (void)notifyLowMemory;
- (nonnull flutter::PlatformViewIOS*)iosPlatformView;

- (void)waitForFirstFrame:(NSTimeInterval)timeout
                 callback:(nonnull void (^)(BOOL didTimeout))callback;

/**
 * Creates one running FlutterEngine from another, sharing components between them.
 *
 * This results in a faster creation time and a smaller memory footprint engine.
 * This should only be called on a FlutterEngine that is running.
 */
- (nonnull FlutterEngine*)spawnWithEntrypoint:(nullable NSString*)entrypoint
                                   libraryURI:(nullable NSString*)libraryURI;

/**
 * Dispatches the given key event data to the framework through the engine.
 * The callback is called once the response from the framework is received.
 */
- (void)sendKeyEvent:(const FlutterKeyEvent&)event
            callback:(nullable FlutterKeyEventCallback)callback
            userData:(nullable void*)userData;
@end

#endif  // FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTER_ENGINE_INTERNAL_H_

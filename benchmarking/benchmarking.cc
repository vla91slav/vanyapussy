// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "benchmarking.h"

#include "flutter/fml/backtrace.h"
#include "flutter/fml/command_line.h"
#include "flutter/fml/icu_util.h"

namespace benchmarking {

int Main(int argc, char** argv) {
  fml::InstallCrashHandler();
  fml::CommandLine cmd = fml::CommandLineFromArgcArgv(argc, argv);
  benchmark::Initialize(&argc, argv);
  std::string icudtl_path =
      cmd.GetOptionValueWithDefault("icu-data-file-path", "icudtl.dat");
  fml::icu::InitializeICU(icudtl_path);
  ::benchmark::RunSpecifiedBenchmarks();
  return 0;
}

}  // namespace benchmarking

int main(int argc, char** argv) {
  return benchmarking::Main(argc, argv);
}

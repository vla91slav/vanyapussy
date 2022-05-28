#!/bin/bash
# Copyright 2013 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


if [[ -n "${ZSH_VERSION:-}" ]]; then
  devshell_lib_dir=${${(%):-%x}:a:h}
else
  devshell_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
fi

# Note: if this file location changes this path needs to change
FLUTTER_ENGINE_SRC_DIR="$(dirname "$(dirname "$(dirname "$(dirname "$(dirname "${devshell_lib_dir}")")")")")"
export FLUTTER_ENGINE_SRC_DIR
unset devshell_lib_dir

# Find the fuchsia sdk location
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  export FLUTTER_ENGINE_FUCHSIA_SDK_DIR="${FLUTTER_ENGINE_SRC_DIR}/fuchsia/sdk/linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  export FLUTTER_ENGINE_FUCHSIA_SDK_DIR="${FLUTTER_ENGINE_SRC_DIR}/fuchsia/sdk/mac"
else
  echo "We only support linux/mac"
  exit 1
fi

function engine-is-stderr-tty {
  [[ -t 2 ]]
}

# engine-error prints a line to stderr with a red ERROR: prefix.
function engine-error {
  if engine-is-stderr-tty; then
    echo -e >&2 "\033[1;31mERROR:\033[0m $*"
  else
    echo -e >&2 "ERROR: $*"
  fi
}

function ensure_fuchsia_dir() {
  if [[ -z "${FUCHSIA_DIR}" ]]; then
    engine-error "A valid fuchsia.git checkout is required." \
     "Make sure you have a valid FUCHSIA_DIR."
    exit 1
  fi
}

#!/bin/bash
# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# This script collects the JavaScript spec definitions for core
# native modules and components, then uses react-native-codegen
# to generate native code.
# The script will use the local react-native-codegen package by
# default. Optionally, set the CODEGEN_PATH to point to the
# desired codegen library (e.g. when using react-native-codegen
# from npm).
#
# Usage:
#   ./scripts/generate-specs.sh
#
# Examples:
#  CODEGEN_PATH=.. ./scripts/generate-specs.sh

# shellcheck disable=SC2038

set -e

THIS_DIR=$(cd -P "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")" && pwd)
TEMP_DIR=$(mktemp -d /tmp/react-native-codegen-XXXXXXXX)
RN_DIR=$(cd "$THIS_DIR/.." && pwd)
CODEGEN_PATH="${CODEGEN_PATH:-$(cd "$RN_DIR/packages/react-native-codegen" && pwd)}"
YARN_BINARY="${YARN_BINARY:-$(command -v yarn)}"
USE_FABRIC="${USE_FABRIC:-0}"

cleanup () {
  set +e
  rm -rf "$TEMP_DIR"
  set -e
}

describe () {
  printf "\\n\\n>>>>> %s\\n\\n\\n" "$1"
}

main() {
  SRCS_DIR=$(cd "$RN_DIR/Libraries" && pwd)

  OUTPUT_DIR="$TEMP_DIR/out"
  COMPONENTS_DIR="$RN_DIR/ReactCommon/react/renderer/components/rncore"
  MODULES_DIR="$RN_DIR/Libraries/FBReactNativeSpec/FBReactNativeSpec"

  SCHEMA_FILE="$TEMP_DIR/schema.json"

  if [ ! -d "$CODEGEN_PATH/lib" ]; then
    describe "Building react-native-codegen package"
    pushd "$CODEGEN_PATH" >/dev/null || exit
      "$YARN_BINARY"
      "$YARN_BINARY" build
    popd >/dev/null || exit
  fi

  describe "Generating schema from flow types"
  "$YARN_BINARY" node "$CODEGEN_PATH/lib/cli/combine/combine-js-to-schema-cli.js" "$SCHEMA_FILE" "$SRCS_DIR"

  describe "Generating native code from schema (iOS)"
  pushd "$RN_DIR" >/dev/null || exit
    USE_FABRIC="$USE_FABRIC" "$YARN_BINARY" --silent node scripts/generate-specs-cli.js ios "$SCHEMA_FILE" "$OUTPUT_DIR"
  popd >/dev/null || exit

  mkdir -p "$COMPONENTS_DIR" "$MODULES_DIR"
  mv "$OUTPUT_DIR/FBReactNativeSpec.h" "$OUTPUT_DIR/FBReactNativeSpec-generated.mm" "$MODULES_DIR"
  find "$OUTPUT_DIR" -type f | xargs sed -i '' 's/FBReactNativeSpec/rncore/g'
  cp -R "$OUTPUT_DIR/." "$COMPONENTS_DIR"
}

trap cleanup EXIT
main "$@"

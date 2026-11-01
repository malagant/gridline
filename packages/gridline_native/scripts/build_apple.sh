#!/bin/bash
# Baut libgridline_ffi.a für die Architekturen des aktuellen Xcode-Builds.
# Wird als CocoaPods-Script-Phase aufgerufen (macOS und iOS).
set -euo pipefail

PLUGIN_DIR="$(cd "${PODS_TARGET_SRCROOT}/.." && pwd -P)"
ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd -P)"
OUT="${BUILT_PRODUCTS_DIR}"
export PATH="${HOME}/.cargo/bin:${PATH}"

triples=()
for arch in ${ARCHS}; do
  case "${PLATFORM_NAME}/${arch}" in
    iphoneos/arm64)         triples+=(aarch64-apple-ios) ;;
    iphonesimulator/arm64)  triples+=(aarch64-apple-ios-sim) ;;
    iphonesimulator/x86_64) triples+=(x86_64-apple-ios) ;;
    macosx/arm64)           triples+=(aarch64-apple-darwin) ;;
    macosx/x86_64)          triples+=(x86_64-apple-darwin) ;;
    *) echo "error: Architektur ${PLATFORM_NAME}/${arch} wird nicht unterstützt" >&2; exit 1 ;;
  esac
done

# Xcode-Variablen würden den Host-Build von Build-Skripten stören.
unset SDKROOT LIBRARY_PATH
libs=()
for triple in "${triples[@]}"; do
  if command -v rustup >/dev/null; then
    rustup target list --installed | grep -qx "${triple}" || rustup target add "${triple}"
  fi
  cargo build --release -p gridline-ffi --target "${triple}" --manifest-path "${ROOT}/Cargo.toml"
  libs+=("${ROOT}/target/${triple}/release/libgridline_ffi.a")
done

mkdir -p "${OUT}"
lipo -create "${libs[@]}" -output "${OUT}/libgridline_ffi.a"
echo "Rust-Kern: ${OUT}/libgridline_ffi.a (${triples[*]})"

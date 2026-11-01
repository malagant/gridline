# Baut den Rust-Kern und bündelt libgridline_ffi.so mit der App.
cmake_minimum_required(VERSION 3.10)
project(gridline_native LANGUAGES CXX)

# Flutter bindet Plugins über Symlinks ein, daher den echten Pfad auflösen.
get_filename_component(PLUGIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." REALPATH)
get_filename_component(GRIDLINE_ROOT "${PLUGIN_DIR}/../.." REALPATH)

find_program(CARGO cargo HINTS "$ENV{HOME}/.cargo/bin" REQUIRED)
set(CARGO_TARGET_DIR "${CMAKE_BINARY_DIR}/cargo")
set(GRIDLINE_FFI_LIB "${CARGO_TARGET_DIR}/release/libgridline_ffi.so")

# Läuft bei jedem Build; cargo baut nur neu, wenn sich etwas geändert hat.
add_custom_target(gridline_rust ALL
  COMMAND ${CMAKE_COMMAND} -E env "CARGO_TARGET_DIR=${CARGO_TARGET_DIR}"
          "${CARGO}" build --release -p gridline-ffi --manifest-path "${GRIDLINE_ROOT}/Cargo.toml"
  BYPRODUCTS "${GRIDLINE_FFI_LIB}"
  WORKING_DIRECTORY "${GRIDLINE_ROOT}"
  COMMENT "Rust-Kern (gridline-ffi) bauen"
  VERBATIM
)

set(gridline_native_bundled_libraries
  "${GRIDLINE_FFI_LIB}"
  PARENT_SCOPE
)

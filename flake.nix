{
  description = "Gridline – Entwicklungsumgebung (Rust-Kern + Flutter-App) mit Starship-Prompt";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, rust-overlay, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [ rust-overlay.overlays.default ];
            }
          )
        );
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          inherit (pkgs) lib stdenv;
          isDarwin = stdenv.hostPlatform.isDarwin;

          # Stable-Toolchain wie in der CI (dtolnay/rust-toolchain@stable),
          # auf macOS mit den Apple-Zielen für build_apple.sh.
          rust = pkgs.rust-bin.stable.latest.default.override {
            extensions = [
              "clippy"
              "rustfmt"
              "rust-src"
              "rust-analyzer"
            ];
            targets = lib.optionals isDarwin [
              "aarch64-apple-darwin"
              "x86_64-apple-darwin"
              "aarch64-apple-ios"
              "aarch64-apple-ios-sim"
              "x86_64-apple-ios"
            ];
          };

          common = [
            rust
            pkgs.flutter
            pkgs.starship
            pkgs.pkg-config
          ];

          # Entspricht den apt-Paketen der Linux-Jobs in .github/workflows/ci.yml.
          linuxDeps = with pkgs; [
            clang
            cmake
            ninja
            gtk3
            alsa-lib
          ];

          # Xcode und das SDK kommen auf macOS vom System; CocoaPods für die Plugins.
          darwinDeps = [ pkgs.cocoapods ];

          # Auf macOS ohne Nix-C-Compiler, damit Xcode seine eigene Toolchain nutzt.
          mkShell = if isDarwin then pkgs.mkShellNoCC else pkgs.mkShell;
        in
        {
          default = mkShell {
            name = "gridline";
            packages =
              common ++ lib.optionals stdenv.hostPlatform.isLinux linuxDeps ++ lib.optionals isDarwin darwinDeps;

            RUST_SRC_PATH = "${rust}/lib/rustlib/src/rust/library";

            shellHook = ''
              ${lib.optionalString isDarwin ''
                # Nix-SDK-Variablen stören xcodebuild und build_apple.sh.
                unset DEVELOPER_DIR SDKROOT MACOSX_DEPLOYMENT_TARGET
              ''}
              export GRIDLINE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
              export STARSHIP_CONFIG="$GRIDLINE_ROOT/starship.toml"

              # Starship nur in interaktiven Shells starten (nicht bei `nix develop -c …`).
              if [[ $- == *i* ]]; then
                eval "$(${pkgs.starship}/bin/starship init bash)"
              fi

              if [[ $- == *i* && -z "''${GRIDLINE_QUIET:-}" ]]; then
                echo "Gridline-Dev-Shell: $(rustc --version)"
                echo "Prüfen: cargo fmt --all --check && cargo clippy --workspace --all-targets -- -D warnings && cargo test --workspace"
              fi
            '';
          };
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}

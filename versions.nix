# Denial build pins — the single source of truth for versions and hashes.
#
# - flake.nix declares the flake *inputs* (denial / denialShell / rust-overlay);
#   this file pins everything the build needs on top of those inputs.
# - denial-update-check (denial/update-check.sh) prints what to change here
#   when a new Denial release exists.
{
  # Flake input URLs, mirrored here so the update check can follow each input.
  # Keep in sync with my-nixOS/flake.nix inputs.
  inputs = {
    # Compositor + packaging (deniald/denialctl/denial-session, engine release).
    denial = { url = "github:denialwm/denial/v0.2.15"; flake = false; };
    # Dart shell source. Currently the same repository as `denial`; when the
    # shell moves to its own repository, change only this URL (and drop the
    # sourceRoot in package.nix if the layout changes).
    denialShell = { url = "github:denialwm/denial/v0.2.15"; flake = false; };
    # Pinned Rust toolchain for the compositor (matches denial's rust-toolchain.toml).
    rust-overlay = { url = "github:oxalica/rust-overlay"; };
  };

  # Official prebuilt release packages.  Using these skips Nix-side Rust/Dart
  # builds entirely: the Denial shell bundle, Settings app, compositor, and
  # release Flutter engine all come from upstream artifacts.
  release = {
    version = "0.2.15";
    denial = {
      url = "https://github.com/denialwm/denial/releases/download/v0.2.15/denial-0.2.15-1-x86_64.pkg.tar.zst";
      sha256 = "a6d409a52fedac4a246238e8934d7e57f4c63818721fb5f2650dba6179c0d619";
    };
    engine = {
      version = "1.0.2.15";
      url = "https://github.com/denialwm/denial/releases/download/v0.2.15/denial-flutter-engine-1.0.2.15-1-x86_64.pkg.tar.zst";
      sha256 = "024debf38ade03a8c9d664d4b017602113a1ea050e66b9f240c28b2dd6d4434e";
    };
  };

  # Prebuilt fork Flutter toolchain (denial-ui-development release package).
  uiDev = {
    version = "0.2.15";
    url = "https://github.com/denialwm/denial/releases/download/v0.2.15/denial-ui-development-0.2.15-1-x86_64.pkg.tar.zst";
    sha256 = "8740f1a314995c4f0cbb92e0933351aa5e8cf2cca2ea6cb3f76e1e19101cb429";
  };

  # Flutter version of the pinned toolchain (must equal what the shell's
  # dart_shell/pubspec.yaml asks for; enforced at eval time).
  flutterVersion = "3.44.7";

  # The UI development archive intentionally omits flutter_tools/bin. The GTK
  # runner still calls these two files, so fetch them from the exact Denial
  # Flutter revision recorded in the archive's flutter.version.json.
  flutterFramework = {
    repository = "https://github.com/denialwm/flutter";
    revision = "802536a7b2fc6bcd75f8fb998b50f9d1cc50a24b";
    toolBackendShellSha256 = "2f926c1d3295ae158e7c267c0f5e22ef547a9ace0c901a11fd4515bd38abdae5";
    toolBackendDartSha256 = "5a082d3307dade01f5f688d10b97354afe667e6413d5569891df2eb39500257a";
  };
}

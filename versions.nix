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
    denial = { url = "github:denialwm/denial/v0.3.1"; flake = false; };
    # Dart shell source. Currently the same repository as `denial`; when the
    # shell moves to its own repository, change only this URL (and drop the
    # sourceRoot in package.nix if the layout changes).
    denialShell = { url = "github:denialwm/denial/v0.3.1"; flake = false; };
    # Pinned Rust toolchain for the compositor (matches denial's rust-toolchain.toml).
    rust-overlay = { url = "github:oxalica/rust-overlay"; };
  };

  # Official prebuilt release packages.  Using these skips Nix-side Rust/Dart
  # builds entirely: the Denial shell bundle, Settings app, compositor, and
  # release Flutter engine all come from upstream artifacts.
  release = {
    version = "0.3.1";
    denial = {
      url = "https://github.com/denialwm/denial/releases/download/v0.3.1/denial-0.3.1-1-x86_64.pkg.tar.zst";
      sha256 = "sha256-oKI+C4UIIe9pd3nkLzDYpTeF1OwPV29LHV+CXwRCbQM=";
    };
    engine = {
      version = "1.0.3.1";
      url = "https://github.com/denialwm/denial/releases/download/v0.3.1/denial-flutter-engine-1.0.3.1-1-x86_64.pkg.tar.zst";
      sha256 = "sha256-moyDvDyzMUTaxIHtBwSlYDzjiqBNczyElRzkSCM058w=";
    };
  };

  # Prebuilt fork Flutter toolchain (denial-ui-development release package).
  uiDev = {
    version = "0.3.1";
    url = "https://github.com/denialwm/denial/releases/download/v0.3.1/denial-ui-development-0.3.1-1-x86_64.pkg.tar.zst";
    sha256 = "sha256-v35GRv9JYPbnzG6LsZFMkNzpdo7aL3x4MzTh1Vt86yw=";
  };

  # Flutter version of the pinned toolchain (must equal what the shell's
  # dart_shell/pubspec.yaml asks for; enforced at eval time).
  flutterVersion = "3.44.7";

  # The UI development archive intentionally omits flutter_tools/bin. The GTK
  # runner still calls these two files, so fetch them from the exact Denial
  # Flutter revision recorded in the archive's flutter.version.json.
  flutterFramework = {
    repository = "https://github.com/denialwm/flutter";
    revision = "d728e61e7d835e02c453c70ae9523a40f6c03215";
    toolBackendShellSha256 = "sha256-L5JsHTKVrhWOfCZ8D14i71R6ms4MkBoR/UUVvTir2uU=";
    toolBackendDartSha256 = "sha256-WggtMwfa3gH19ojRC5c1Sv5mfmQT1VaYkd8us5UAJXo=";
  };
}

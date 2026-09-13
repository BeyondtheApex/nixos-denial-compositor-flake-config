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
    denial = { url = "github:denialwm/denial/v0.4.0"; flake = false; };
    # Dart shell source. Currently the same repository as `denial`; when the
    # shell moves to its own repository, change only this URL (and drop the
    # sourceRoot in package.nix if the layout changes).
    denialShell = { url = "github:denialwm/denial/v0.4.0"; flake = false; };
    # Pinned Rust toolchain for the compositor (matches denial's rust-toolchain.toml).
    rust-overlay = { url = "github:oxalica/rust-overlay"; };
  };

  # Official prebuilt release packages.  Using these skips Nix-side Rust/Dart
  # builds entirely: the Denial shell bundle, Settings app, compositor, and
  # release Flutter engine all come from upstream artifacts.
  release = {
    version = "0.4.0";
    denial = {
      url = "https://github.com/denialwm/denial/releases/download/v0.4.0/denial-0.4.0-1-x86_64.pkg.tar.zst";
      sha256 = "sha256-9l3HPZuQupPBWl0DIhS4//KFN6TycjUTrps+oG036zI=";
    };
    engine = {
      version = "1.0.4.0";
      url = "https://github.com/denialwm/denial/releases/download/v0.4.0/denial-flutter-engine-1.0.4.0-1-x86_64.pkg.tar.zst";
      sha256 = "sha256-+DunVmm/szsd40SaVGSvpWCgof+6doIUJVeHjJD+Q24=";
    };
  };

  # Prebuilt fork Flutter toolchain (denial-ui-development release package).
  uiDev = {
    version = "0.4.0";
    url = "https://github.com/denialwm/denial/releases/download/v0.4.0/denial-ui-development-0.4.0-1-x86_64.pkg.tar.zst";
    sha256 = "sha256-1FkDDjDo2EZgENcrwDUijhAk5vjAsL2HNy3FqivSFKY=";
  };

  # Flutter version of the pinned toolchain (must equal what the shell's
  # dart_shell/pubspec.yaml asks for; enforced at eval time).
  flutterVersion = "3.44.7";

  # The UI development archive intentionally omits flutter_tools/bin. The GTK
  # runner still calls these two files, so fetch them from the exact Denial
  # Flutter revision recorded in the archive's flutter.version.json.
  flutterFramework = {
    repository = "https://github.com/denialwm/flutter";
    revision = "c8894357b3a91902c358e8ad5cf0ebc85d45e83e";
    toolBackendShellSha256 = "sha256-L5JsHTKVrhWOfCZ8D14i71R6ms4MkBoR/UUVvTir2uU=";
    toolBackendDartSha256 = "sha256-WggtMwfa3gH19ojRC5c1Sv5mfmQT1VaYkd8us5UAJXo=";
  };
}

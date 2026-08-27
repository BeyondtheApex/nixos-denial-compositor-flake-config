# NixOS Denial Compositor Flake Configuration

A NixOS flake configuration for the
[Denial](https://github.com/denialwm/denial) Flutter-native Wayland compositor.

The flake provides a NixOS module, package variants, and an update checker for
two deployment styles:

- an official-release mode that uses Denial's upstream prebuilt artifacts; and
- a source/profile mode that builds the Rust compositor and compiles a custom
  Dart shell profile AOT bundle with Denial's prebuilt UI development toolchain.

## What This Flake Provides

| Output | Purpose |
|---|---|
| `nixosModules.default` | NixOS module under `services.denial.*` |
| `packages.x86_64-linux.default` | Official prebuilt Denial release package |
| `packages.x86_64-linux.withUiDevelopment` | Official release package with UI development tools enabled |
| `packages.x86_64-linux.officialRelease` | Official release package without UI development tools |
| `packages.x86_64-linux.officialReleaseWithUiDevelopment` | Official release package with `denial-ui`, wrapped `denialctl`, and a Settings-compatible FHS wrapper |
| `packages.x86_64-linux.sourceProfile` | Source/profile package: builds the Rust compositor and compiles the shell profile AOT bundle |
| `packages.x86_64-linux.sourceProfileWithUiDevelopment` | Source/profile package with live UI development tools enabled |
| `packages.x86_64-linux.settingsApp` | Source-built standalone Settings app for source/profile mode |
| `packages.x86_64-linux.update-check` | Prints upstream release changes and the hashes to update |

## Prebuilt Artifacts

The official-release mode uses these upstream Denial release artifacts:

| Artifact | Used For |
|---|---|
| `denial-<version>-1-x86_64.pkg.tar.zst` | prebuilt `deniald`, `denialctl`, `denial-session`, official shell AOT bundle, and official Settings app |
| `denial-flutter-engine-1.<version>-1-x86_64.pkg.tar.zst` | official release Flutter engine and ICU data |
| `denial-ui-development-<version>-1-x86_64.pkg.tar.zst` | optional UI development tools, Flutter SDK, pub cache, source template, debug engine, profile engine, and profile `gen_snapshot` |

The source/profile mode does not compile the Flutter engine. It still uses
`denial-ui-development` for the pinned Flutter fork, SDK, pub cache,
`gen_snapshot`, and matching profile engine.

## Behavior Matrix

| `services.denial.useOfficialRelease` | `services.denial.uiDevelopment.enable` | Selected package | Nix builds Denial code? | `denialShell` input used? | Settings UI development page |
|---|---:|---|---:|---:|---|
| `true` | `false` | `officialRelease` | No | No | Not available |
| `true` | `true` | `officialReleaseWithUiDevelopment` | No | No | Available through an FHS-wrapped official Settings app |
| `false` | `false` | `sourceProfile` | Yes: Rust compositor and Dart shell profile AOT bundle | Yes | Not available |
| `false` | `true` | `sourceProfileWithUiDevelopment` | Yes: Rust compositor and Dart shell profile AOT bundle | Yes | Available through the source-built Settings app |

## Module Logic

The module option `services.denial.package` defaults to `null`. When it is not
set, the module selects a package from this flake:

```text
if useOfficialRelease:
  if uiDevelopment.enable:
    officialReleaseWithUiDevelopment
  else:
    officialRelease
else:
  if uiDevelopment.enable:
    sourceProfileWithUiDevelopment
  else:
    sourceProfile
```

The resolved package is exposed as `services.denial.selectedPackage`. Use this
value when another module needs the actual session package, for example in
`services.displayManager.sessionPackages`.

## NixOS Options

| Option | Default | Meaning |
|---|---|---|
| `services.denial.enable` | `false` | Enables the Denial session integration |
| `services.denial.useOfficialRelease` | `true` | Uses upstream prebuilt Denial packages instead of Nix-building Denial code |
| `services.denial.package` | `null` | Optional package override; leave unset for automatic package selection |
| `services.denial.selectedPackage` | internal | The resolved package selected by the module |
| `services.denial.uiDevelopment.enable` | `false` | Adds `denial-ui`, wrapped `denialctl`, and live UI development session wiring |
| `services.denial.settings.enable` | `false` | Installs a Settings app package when one is separate from the selected package |
| `services.denial.settings.package` | `null` | Optional Settings app package override |
| `services.denial.updateCheck` | `null` | Optional `denial-update-check` package |
| `services.denial.user` | `"kevin"` | Session user added to `video`, `input`, `render`, and `seat` |
| `services.denial.startLocked` | `false` | Adds `--start-locked` to the session command |
| `services.denial.renderer` | `"impeller"` | Flutter renderer: `impeller` or `skia` |
| `services.denial.xwaylandScaleMode` | `"fractional"` | Xwayland scale mode: `fractional` or `integer` |
| `services.denial.shellProfile` | `"desktop"` | Shell profile: `desktop` or `mobile` |
| `services.denial.drmDevice` | `null` | Optional DRM card override |
| `services.denial.renderDevice` | `null` | Optional render node override |
| `services.denial.outputs` | `[ ]` | Initial `/etc/denial/outputs.conf` template lines |
| `services.denial.extraOutputsConf` | `""` | Raw extra output configuration |
| `services.denial.extraSessionConf` | `{ }` | Extra `KEY=VALUE` entries for `/etc/denial/session.conf` |
| `services.denial.enableXwayland` | `true` | Installs Xwayland |
| `services.denial.enablePortals` | `true` | Installs and routes ScreenCast/Screenshot portals through `xdg-desktop-portal-wlr` |

## Basic Usage

```nix
{
  inputs.denial-nixos.url =
    "github:BeyondtheApex/nixos-denial-compositor-flake-config";

  outputs = { self, nixpkgs, denial-nixos, ... }:
  {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        denial-nixos.nixosModules.default
        {
          services.denial = {
            enable = true;
            user = "kevin";
          };

          services.displayManager.gdm.enable = true;
          services.displayManager.defaultSession = "denial";
        }
      ];
    };
  };
}
```

This uses the default official-release mode and does not compile Denial code in
Nix.

## Developing a Custom Shell

For shell iteration, point the flake's `denialShell` input at your own fork or
repository and use `sourceProfileWithUiDevelopment`.

```nix
{
  inputs.denial-nixos.url =
    "github:BeyondtheApex/nixos-denial-compositor-flake-config";

  inputs.my-denial-shell = {
    url = "github:your-name/your-denial-shell";
    flake = false;
  };

  inputs.denial-nixos.inputs.denialShell.follows = "my-denial-shell";

  outputs = { self, nixpkgs, denial-nixos, ... }:
  {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        denial-nixos.nixosModules.default
        ({ config, ... }: {
          services.denial = {
            enable = true;
            useOfficialRelease = false;
            uiDevelopment.enable = true;
            settings.enable = true;
            user = "kevin";
          };

          services.displayManager.gdm.enable = true;
          services.displayManager.defaultSession = "denial";
          services.displayManager.sessionPackages = [
            config.services.denial.selectedPackage
          ];
        })
      ];
    };
  };
}
```

With this mode:

1. Open the Denial Settings app.
2. Use the UI development page to create or select an editable shell workspace.
3. Iterate on the Dart shell.
4. Commit your shell changes to the repository used by the `denialShell` input.
5. Run a flake update in your NixOS configuration.
6. The next rebuild compiles the updated shell into the profile AOT bundle used
   by `sourceProfile`.

This keeps the live UI development workflow and the declarative Nix build path
connected: Settings is used for shell development, while committed shell changes
become the next profile shell through Nix.

## Update Checker

Build or install `packages.x86_64-linux.update-check` and run:

```sh
denial-update-check
denial-update-check --json
denial-update-check --force
```

The checker reports:

- the latest upstream Denial release;
- the latest upstream main revision;
- official release package URLs and hashes;
- official Flutter engine package URLs and hashes;
- UI development package URLs and hashes;
- the Flutter fork revision used for `tool_backend.sh` and
  `tool_backend.dart`; and
- the fields to edit in `versions.nix` and `flake.nix`.

## Automated Updates

This repository includes a GitHub Actions workflow named
`Auto-update Denial pins`. It runs every two hours and can also be started
manually from the Actions tab.

On each run, the workflow:

- runs `scripts/update-denial-pins.py`;
- updates `flake.nix`, `flake.lock`, and `versions.nix` when a new upstream
  Denial release is available;
- validates the result with `nix flake check`;
- builds `.#officialRelease`, `.#officialReleaseWithUiDevelopment`, and
  `.#update-check`; and
- commits the updated pins back to `main` when validation succeeds.

## Upstream Project

Denial is developed at
[github.com/denialwm/denial](https://github.com/denialwm/denial).

This flake packages and wires Denial for NixOS. It does not replace the
upstream project.

## License

This repository is published under the GNU General Public License.

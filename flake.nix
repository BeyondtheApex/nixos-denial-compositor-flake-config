{
  description = "NixOS Denial Compositor Flake Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    denial = {
      url = "github:denialwm/denial/v0.2.15";
      flake = false;
    };

    # Override this input with your own Dart shell repository when iterating on
    # the shell with sourceProfile/sourceProfileWithUiDevelopment.
    denialShell = {
      url = "github:denialwm/denial/v0.2.15";
      flake = false;
    };

    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs =
    inputs@{ self, nixpkgs, denial, denialShell, rust-overlay, ... }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkPackages = system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        import ./package.nix {
          inherit pkgs denial denialShell rust-overlay;
        };
    in
    {
      packages = forAllSystems (system:
        let
          denialPackages = mkPackages system;
        in
        {
          default = denialPackages.default;
          withUiDevelopment = denialPackages.withUiDevelopment;
          officialRelease = denialPackages.officialRelease;
          officialReleaseWithUiDevelopment = denialPackages.officialReleaseWithUiDevelopment;
          sourceProfile = denialPackages.sourceProfile;
          sourceProfileWithUiDevelopment = denialPackages.sourceProfileWithUiDevelopment;
          settingsApp = denialPackages.settingsApp;
          update-check = denialPackages.update-check;
        });

      nixosModules.default = args:
        import ./module.nix (args // { inherit inputs; });

      formatter = forAllSystems (system:
        nixpkgs.legacyPackages.${system}.nixpkgs-fmt);
    };
}

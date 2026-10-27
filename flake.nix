{
  description = "Scott's macOS dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Pinned to the commit that ships Homebrew 6.0.22. 6.0.16 is the first
    # Homebrew that understands the `postflight_steps do run ... end` cask DSL
    # the nikitabobko/tap AeroSpace cask moved to on 2026-09-05; the previous
    # lock (Homebrew 6.0.12) failed every `brew bundle` with "undefined method
    # 'run'". Deliberately not upstream head (Homebrew 7.x, new build sandbox):
    # unpin when moving to 7.x, alongside the nixpkgs 26.11 migration.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew/09a921d0181146cf6163ec2cc1db7b6fd539a885";
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, nixpkgs }:
    let
      # The one username line to change if this is applied to a different Mac.
      # bootstrap.sh offers to rewrite this if the macOS username differs.
      user = "scottjrainey";
    in
    {
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user; };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit user; };
            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };
    };
}

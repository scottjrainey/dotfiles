{
  description = "Scott's macOS dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Tracks upstream; flake.lock decides the Homebrew version (7.x). Needs
    # Homebrew 6.0.16+ for the AeroSpace cask's `postflight_steps` DSL.
    # History: from 2026-10-28 this was pinned to commit 09a921d0 (Homebrew
    # 6.0.22). That got past 6.0.12, which failed every `brew bundle` with
    # "undefined method 'run'", while holding back 7.x, whose new sandbox
    # could deadlock on wedged macOS sandboxd state (Homebrew/brew#24235).
    # That issue closed unresolved as a probable macOS bug, and the pin was
    # lifted in November 2026 after 7.x's sandbox probes passed on 27.2.1.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
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

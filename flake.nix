{
  description = "B3 DevOps Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    argonaut = {
      url = "github:darksworm/argonaut";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, argonaut }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            kubectl
            kubernetes-helm
            argocd
            argonaut.packages.${system}.default
            k9s
            pre-commit

            # opentofu
            # terraform
            # ansible
          ];
        };
      }
    );
}

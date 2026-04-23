{
  description = "Ambiente para Laboratório de Linguagens Regulares - IFES";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            (haskellPackages.ghcWithPackages (p: [ p.yaml p.aeson p.process p.containers ])) 
            graphviz
            haskell-language-server
            emacs-nox
            ripgrep
            fd
          ];

        shellHook = ''
          echo "Bem-vindo ao ambiente de Teoria da Computação!"
          echo "Emacs e Haskell prontos para uso."
        '';
      };
    };
}
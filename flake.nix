{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # 動作システム
      system = "x86_64-linux";
      # 動作システムに関連するnix packageの読み込み
      pkgs = import nixpkgs { inherit system; };
    in {
      # 開発シェル定義
      devShells.${system}.default = pkgs.mkShell {
        name = "nodejs";
        buildInputs = [
          pkgs.nodejs_22
        ];
      };
    };
}

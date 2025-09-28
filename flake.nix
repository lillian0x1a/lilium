{
  description = "lilium compiler development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        
        # Rustツールチェーンのカスタマイズ
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "rust-src"
            "rust-analyzer"
            "clippy"
            "rustfmt"
          ];
          targets = [ "wasm32-unknown-unknown" ];
        };
        
        # より新しいLLVMバージョンを使用（デフォルトまたは最新安定版）
        llvm = pkgs.llvmPackages;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rustツールチェーン
            rustToolchain
            
            # LLVMツール群
            llvm.llvm
            llvm.clang
            llvm.lld
            llvm.bintools
            
            # 依存関係
            pkg-config
            openssl
            zlib
          ];
          
          # 環境変数の設定
          LIBCLANG_PATH = "${llvm.libclang.lib}/lib";
          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
          BINDGEN_EXTRA_CLANG_ARGS = "-I${llvm.llvm.dev}/include";
          
          # シェルの起動時メッセージ
          shellHook = ''
            echo "🚀 lilium compiler development environment"
            echo "Rust version: $(rustc --version)"
            echo "LLVM version: $(llvm-config --version)"
            echo ""
            echo "Available commands:"
            echo "  cargo build    - Build the compiler"
            echo "  cargo test     - Run tests"
            echo "  cargo clippy   - Lint code"
            echo "  nix develop    - Enter this environment"
          '';
        };
      });
}
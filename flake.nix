{
  description = "VeriPacket: Rust + Charon + Aeneas + Lean development shell";

  inputs = {
    aeneas.url = "github:AeneasVerif/aeneas";
    nixpkgs.follows = "aeneas/nixpkgs";
  };

  outputs = { self, nixpkgs, aeneas }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          aeneasTools = aeneas.packages.${system};
          # Reuse the same Rust toolchain used to build the pinned Charon.
          # Same toolchain plus rust-analyzer, so editor diagnostics match it.
          rustToolchain = aeneas.inputs.charon.packages.${system}.rustToolchain.override (old: {
            extensions = (old.extensions or [ ]) ++ [ "rust-analyzer" ];
          });
        in {
          default = pkgs.mkShell {
            packages = [
              aeneasTools.aeneas
              aeneasTools.charon
              rustToolchain
              pkgs.elan
              pkgs.git
              pkgs.gnumake
              pkgs.pkg-config
            ];
            AENEAS_SOURCE = aeneas.outPath;
            # Locked Git revision of Aeneas; proofs/lakefile.toml must pin the same rev.
            AENEAS_REV = aeneas.rev;
            shellHook = ''
              echo "VeriPacket dev shell: Rust / Charon / Aeneas / elan"
              echo "Aeneas source: $AENEAS_SOURCE"
              echo "Aeneas rev:    $AENEAS_REV"
              echo "Lean version is pinned in proofs/lean-toolchain (once created)."
            '';
          };
        });
    };
}

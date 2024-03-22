{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-centos.url = "github:NixOS/nixpkgs/ab6453c483e406b07c63503bca5038838c187ecf";
    nixpkgs-centos.flake = false;
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      perSystem =
        {
          lib,
          config,
          self',
          inputs',
          system,
          pkgs,
          ...
        }:
        let
          sliceBuildHost = p: p.__spliced.pkgsBuildHost or p;
          pkgs' = import inputs.nixpkgs {
            inherit system;
            config.replaceStdenv =
              { pkgs }:
              let
                pkgsCentos = import inputs.nixpkgs-centos { inherit (pkgs.hostPlatform) system; };
                glibc-centos =
                  (
                    p:
                    lib.extendDerivation true {
                      pname = p.pname or "glibc";
                      version = p.version or (lib.removePrefix "glibc-" p.name);

                      # Nixpkgs 24.05 expects more outputs from glibc:
                      bin = p.bin or p;
                      getent = p.getent or p;
                    } p
                  )
                    pkgsCentos.glibc;
                bintools-centos = pkgs.bintools.override { libc = glibc-centos; };
                # bintools-centos = pkgs.wrapBintoolsWith {
                #   bintools = pkgsCentos.binutils;
                #   libc = glibc-centos;
                # };
                cc-centos = pkgs.gcc.override {
                  libc = glibc-centos;
                  bintools = bintools-centos;
                  gccForLibs = (p: p.cc or p.gcc) pkgsCentos.gcc;
                  useCcForLibs = true;
                };
                centosStdenv = pkgs.stdenvAdapters.overrideCC pkgs.stdenv (sliceBuildHost cc-centos);
              in
              centosStdenv;
            overlays = [ (final: prev: { }) ];
          };
        in
        {
          legacyPackages.pkgsCentos = import inputs.nixpkgs-centos { inherit system; };
          legacyPackages.crossToCentos = pkgs';
          legacyPackages.crossToMusl = pkgs.pkgsMusl;
          packages = {
            inherit (pkgs') cowsay hello;
            inherit (pkgs'.python3Packages) opencv4;

            default = config.packages.hello;
            pythonWithOpencv = pkgs'.python3.withPackages (ps: [ ps.opencv4 ]);
            pythonWithOpencvMusl = pkgs.pkgsMusl.python3.withPackages (ps: [ ps.opencv4 ]);
          };
        };
      flake = { };
    };
}

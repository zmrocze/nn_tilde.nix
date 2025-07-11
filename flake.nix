{
  description = "Hello world flake using uv2nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nn-tilde = {
      url = "git+https://github.com/acids-ircam/nn_tilde?submodules=1";  #&submodules=1
      flake = false;
    };

    pure-data = {
      url = github:pure-data/pure-data;
      flake = false;
    };

    my-lib.url = "github:zmrocze/nix-lib";
    flake-parts.url = "github:hercules-ci/flake-parts";

  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      uv2nix,
      pyproject-nix,
      pyproject-build-systems,
      nn-tilde,
      pure-data,
      flake-parts,
      my-lib,
      ...
    }:

    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        my-lib.flakeModules.pkgs
      ];
      systems = [ "x86_64-linux" ];
      pkgsConfig = {
        extraConfig.config.allowUnfree = true;
        overlays = [
          my-lib.overlays.default
        ];
      };
      perSystem = { system, config, pkgs, lib, ... }:
        let

        # note:
        # Created uv.lock with:
        # > nix develop .#impure
        # $ uv lock

        # build nn-tilde (pd package) from source, builds into a binary.
        # `libcurl.so` put into env to mimic what cmake build expects in curl being installed in conda environment.
        nn-tilde-pd = pkgs.runCommand "rave-pd" {
            nativeBuildInputs = [
              pkgs.llvmPackages_20.libcxxClang
              pkgs.python313Packages.cmake
              pkgs.libtorch-bin
              pkgs.puredata
              pkgs.curlFull.dev
              pkgs.curlFull.out
            ];
          } 
          
          ''
            cp -r ${nn-tilde} src
            chmod -R u+w src
            cd src
            mkdir -p build/pd_include
            chmod -R u+w build
            mkdir src/pd_include

            cp -r ${pkgs.puredata}/include/m_pd.h build/pd_include/
            cp -r ${pkgs.puredata}/include/m_pd.h src/pd_include/

            mkdir env
            cp -r ${pkgs.curlFull.out}/lib env/
            cd build

            chmod -R u+rw ..
            cmake ../src -DCMAKE_BUILD_TYPE=Release -DPUREDATA_INCLUDE_DIR=$(pwd)/pd_include
            cmake --build . --config Release
            
            cp -r ./frontend/puredata $out/
          '';

        in {
          packages = {
            inherit nn-tilde-pd;

            pd-w-nn = pkgs.puredata-with-plugins [ nn-tilde-pd ];
          };
        };
    };
}

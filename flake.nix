{
  description = "virtual environments";

  inputs.devshell.url = "github:numtide/devshell";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";
  inputs.nucleus.url = "github:nucleus-labs/nix-flake";
  inputs.dtc.url = "github:MaxTheMooshroom/dtc/dev";

  outputs = inputs@{ self, flake-parts, devshell, nixpkgs, nucleus, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devshell.flakeModule
      ];

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "i686-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem = { pkgs, system, ... }: {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          overlays = [
            devshell.overlays.default
          ];

          config.permittedInsecurePackages = [
            "python-2.7.18.6"
          ];
        };

        devshells.default = {
          imports = [
            "${pkgs.devshell.extraModulesDir}/language/c.nix"
          ];

          packages = with pkgs; [
            automake
            autoconf
            gnumake
            bc
            binutils
            cpio
            elfutils.dev
            file
            flock
            flex
            #openssl.dev
            perl
            rsync
            unzip
            wget
            which
            help2man
            tree
            zlib
            python
          ];

          language.c = {
            compiler = pkgs.gcc;

            includes = with pkgs; [
              ncurses.dev
              zlib
              zlib.static
              openssl
            ];

            libraries = with pkgs; [
              zlib.static
              ncurses
            ];
          };

          commands = [
            {
              category = "tools";
              package = nucleus.packages.${system}.buildg;
            }
            {
              category = "tools";
              package = pkgs.lazydocker;
            }
            {
              category = "tools";
              # package = pkgs.libcamera;
              name = "cam";
              command = "${pkgs.libcamera}/bin/cam -l $@";
            }
            {
              category = "tools";
              package = pkgs.tree;
            }
          ];
        
          env = [
            # {
            #   name = "LD_LIBRARY_PATH";
            #   unset = true;
            # }
            {
              name = "PATH";
              prefix = "";
            }
            { name = "INCLUDE_PATH"; eval = "$C_INCLUDE_PATH"; }
            { name = "INCLUDE"; eval = "$C_INCLUDE_PATH"; }
            { name = "LIBRARY_PATH"; eval = "$LD_LIBRARY_PATH"; }
          ];
        };

        packages = let
          cross = pkgs;
          # .pkgsCross.riscv64;
        in {
          linux = cross.linuxPackages_latest;
          busybox = cross.busybox;

          mediamtx = cross.buildGoModule {
            name = "mediamtx";

            src = cross.fetchFromGitHub {
              owner = "bluenviron";
              repo = "mediamtx";
              rev = "91ada9bf07487371f2c0189ab73201ddbaef468e";
            };

            vendorHash = "sha256-J6RQFbpe+dBM2Rp0nh437ntxgwknVqHcYUzjm5cLETI=";
          };
        };
      };
    };
}

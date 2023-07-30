{
  description = "virtual environments";

  inputs.devshell.url = "github:numtide/devshell";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";
  inputs.nucleus.url = "git+file:../nix-flake";

  outputs = inputs@{ self, flake-parts, devshell, nixpkgs, nucleus }:
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
        devshells.default = {
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
            gcc
            openssl.dev
            ncurses.dev
            perl
            rsync
            unzip
            wget
            which
            help2man
          ];

          commands = [
            {
              category = "tools";
              name = "ct-ng";
              package = nucleus.packages.${system}.crosstool-ng;
            }
          ];
        
          env = [
            {
              name = "LD_LIBRARY_PATH";
              unset = true;
            }
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

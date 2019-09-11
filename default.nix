{
  pkgs ? import (
    fetchTarball "https://github.com/NixOS/nixpkgs/archive/19.03.tar.gz") {},
}:

with pkgs;

let
  self = rec {
    logwarrior = stdenv.mkDerivation rec {
      pname = "logwarrior";
      version = "0.1.0";

      src = ./.;
      buildInputs = [ldc meson ninja];
    };
  };
in
  self.logwarrior

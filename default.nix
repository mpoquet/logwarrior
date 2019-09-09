{
  pkgs ? import (
    fetchTarball "https://github.com/NixOS/nixpkgs/archive/19.03.tar.gz") {},
}:

with pkgs;

let
  self = rec {
    logwarrior-hook = stdenv.mkDerivation rec {
      pname = "logwarrior-hook";
      version = "0.1.0";

      src = ./.;
      buildInputs = [ldc meson ninja];
    };
  };
in
  self.logwarrior-hook

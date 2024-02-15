{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation rec {
  pname = "scrap-project-manager";
  version = "1.0";

  src = ./.;

  buildInputs = with pkgs; [ nushell gum ];

  installPhase = ''
    mkdir -p $out/bin
    echo "#!${pkgs.stdenv.shell}" > $out/bin/spm
    echo "exec ${pkgs.nushell}/bin/nu $src/scrap_project_manager.nu" >> $out/bin/spm
    chmod +x $out/bin/spm
  '';

  meta = {
    description = "A nix project manager";
    maintainers = with pkgs.stdenv.lib.maintainers; [ ];
  };
}

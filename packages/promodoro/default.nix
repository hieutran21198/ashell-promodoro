{
  pkgs,
  lib,
  ...
}:
pkgs.stdenv.mkDerivation {
  pname = "promodoro";
  version = "0.1.0";

  src = ../../bin/promodoro;
  dontUnpack = true;

  nativeBuildInputs = [ pkgs.shellcheck ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    shellcheck $src
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/promodoro
    patchShebangs $out/bin/promodoro
    runHook postInstall
  '';

  meta = with lib; {
    description = "Tiny pomodoro timer designed as an ashell custom-module source";
    homepage = "https://github.com/hieutran21198/ashell-promodoro";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "promodoro";
  };
}

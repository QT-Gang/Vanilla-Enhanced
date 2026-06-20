{
  lib,
  stdenv,
  fetchFromGitHub,
  gradle_9,
  jdk25,
  libGL,
}:
let
  gradle = gradle_9;
  jdk = jdk25;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "moc-gui";
  version = "0.5.0-dev";

  src = fetchFromGitHub {
    owner = "Raconteur32";
    repo = "ModpackOptionControl";
    rev = "b1dc5930f500f55c1229f26a1c7e4a0cf494c152";
    hash = "sha256-+n0lVBGpf0Z9pDtecXUpUBrAyTzlwgetPG6ZjBEDSAo=";
  };

  nativeBuildInputs = [
    gradle
  ];

  patches = [
    ./exit-window-fix.patch
    ./gui-build.patch
  ];

  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs;
    data = ./deps.json;
  };

  gradleFlags = [
    "-Dorg.gradle.java.home=${jdk}"
  ];

  gradleBuildTask = "createDistributable";
  gradleUpdateTask = "createDistributable";
  enableParallelUpdating = false;

  installPhase = ''
    runHook preInstall

    BUILD_DIR="gui/build/compose/binaries/main/app/gui"

    mkdir $out
    cp -r $BUILD_DIR/bin $out/bin
    rm -rf $BUILD_DIR/lib/runtime
    cp -r $BUILD_DIR/lib $out/lib
    ln -s ${jdk}/lib/openjdk $out/lib/runtime

    mv $out/bin/{,moc-}gui
    mv $out/lib/app/{,moc-}gui.cfg
    
    runHook postInstall
  '';

  postFixup = ''
    patchelf $out/lib/app/libskiko-linux-x64.so \
      --add-rpath ${lib.makeLibraryPath [ libGL ]}
  '';

  meta = {
    mainProgram = "moc-gui";
  };
})

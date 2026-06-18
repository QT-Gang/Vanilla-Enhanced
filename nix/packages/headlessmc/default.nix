{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  stripJavaArchivesHook,
  jre,

  libGL,
  udev,
  flite,
  alsa-lib,
  libpulseaudio,
}:

stdenv.mkDerivation rec {
  pname = "headlessmc";
  version = "2.9.0";

  src = fetchurl {
    url = "https://github.com/headlesshq/headlessmc/releases/download/${version}/headlessmc-launcher-wrapper-${version}.jar";
    hash = "sha256-+P5adpl3MJFJ46XtCeNaGazQi84GTv+i/iwJSAYt9E4=";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
    stripJavaArchivesHook
  ];

  runtimeLibs = lib.makeLibraryPath [
    libGL # needed for GUI support
    udev # needed for new input device support
    flite.lib # needed for narrator support
    alsa-lib # might be needed for narrator
    libpulseaudio # needed for audio support
  ];

  installPhase = ''
    runHook preInstall

    install -Dm644 $src $out/share/headlessmc/headlessmc-launcher-wrapper.jar
    makeWrapper ${lib.getExe jre} $out/bin/headlessmc \
      --add-flags "--enable-native-access=ALL-UNNAMED" \
      --add-flags "-jar $out/share/headlessmc/headlessmc-launcher-wrapper.jar" \
      --prefix LD_LIBRARY_PATH : ${runtimeLibs}

    runHook postInstall
  '';
}

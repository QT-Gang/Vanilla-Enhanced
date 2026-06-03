{ pkgs }:
{
  src,
  side ? "server",
}:
let
  inherit (builtins)
    dirOf
    filter
    map
    match
    removeAttrs
    replaceStrings
    ;
  inherit (pkgs) fetchurl lib stdenvNoCC;
  inherit (lib) concatMapStringsSep flip importTOML;

  packTOML = importTOML (src + "/pack.toml");
  indexTOML = importTOML (src + "/${packTOML.index.file}");

  pname = packTOML.name;
  inherit (packTOML) version;

  toCurseForgeUrl =
    filename: file-id:
    replaceStrings [
      "ID1"
      "ID2"
    ] (match "([0-9]{4})([0-9]{0,4})" file-id) "https://edge.forgecdn.net/files/ID1/ID2/${filename}";

  resolveMetafile =
    file:
    let
      pwTOML = importTOML (src + "/${file}");
      inherit (pwTOML) filename download;
      inherit (download) hash hash-format;
    in
    {
      path = dirOf file + "/${filename}";
      fileSrc = fetchurl {
        name = filename;
        ${hash-format} = hash;
        url = builtins.replaceStrings [ " " ] [ "%20" ] (
          let
            file-id = toString pwTOML.update.curseforge.file-id;
          in
          download.url or (toCurseForgeUrl filename file-id)
        );
      };
      inherit (pwTOML) side;
    };

  files = flip map indexTOML.files (
    {
      file,
      metafile ? false,
      ...
    }:
    if metafile then
      (resolveMetafile file)
      // {
        local = false;
      }
    else
      {
        path = file;
        fileSrc = src + "/${file}";
        side = "both";
        local = true;
      }
  );

  relevantFiles = filter (f: f.side == "both" || f.side == side) files;
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  dontUnpack = true;

  installPhase = concatMapStringsSep "\n" (
    {
      path,
      fileSrc,
      local,
      ...
    }:
    ''
      mkdir -p "$out/$(dirname "${path}")"

      ${if local then "cp -P" else "ln -s"} ${fileSrc} "$out/${path}"
    ''
  ) relevantFiles;

  passthru = removeAttrs packTOML [
    "index"
    "options"
  ];
}

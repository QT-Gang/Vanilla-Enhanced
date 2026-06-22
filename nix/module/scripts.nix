{
  pkgs,
  lib,
  writeShellApplication,
  writers,
}:

let
  inherit (lib)
    flip
    genAttrs'
    getName
    nameValuePair
    ;
in

flip genAttrs' (drv: nameValuePair (getName drv) drv) [
  (writeShellApplication rec {
    name = "bluemap-worldspawn";
    runtimeInputs = with pkgs; [
      python3Packages.nbtlib
      yq-go
    ];
    text = ''
      spawn="$(nbt -r ./world/level.dat --path "Data.spawn" --json)"
      export spawn
      yq -n '
        env(spawn) |
        "World Spawn: {x: \(.pos[0]), z: \(.pos[2]), dimension: \"\(.dimension)\"}"
      '

      for file in ./config/bluemap/maps/*.conf; do
        # shellcheck disable=SC2016
        yq -i '
          env(spawn) as $spawn |
          (select(.dimension == $spawn.dimension) | .start-pos) = {
            "x": $spawn.pos[0],
            "z": $spawn.pos[2]
          }
        ' "$file"
      done
    '';

    derivationArgs = {
      nativeBuildInputs = runtimeInputs;
      postCheck = ''
        WORLD=./world
        MAPS=./config/bluemap/maps
        mkdir -p "$WORLD" "$MAPS"
        nbt -w '{Data: {spawn: {pos: [I; 45, 70, 90], dimension: "minecraft:overworld"}}}' "$WORLD"/level.dat

        install -m644 /dev/stdin "$MAPS"/foo.conf <<'EOF'
        dimension: "minecraft:overworld"
        start-pos: {x: 0, z: 0}
        EOF
        install -m644 /dev/stdin "$MAPS"/bar.conf <<'EOF'
        dimension: "minecraft:the_end"
        start-pos: {x: 0, z: 0}
        EOF
        install -m644 /dev/stdin "$MAPS"/baz.conf <<'EOF'
        dimension: "minecraft:overworld"
        start-pos: {x: 0, z: 0}
        EOF

        $target

        (($(yq '.start-pos.x' "$MAPS"/foo.conf) == 45))
        (($(yq '.start-pos.x' "$MAPS"/bar.conf) == 0))
        (($(yq '.start-pos.z' "$MAPS"/baz.conf) == 90))
      '';
    };
  })

  (writers.writePython3Bin "bluemap-html-patch"
    {
      libraries = pypkgs: with pypkgs; [ lxml ];
    }
    ''
      import argparse
      from pathlib import Path

      from lxml import html


      def ResolvedExistingPath(path_str: str) -> Path:
          path = Path(path_str)
          if path.exists():
              return path.resolve()
          raise argparse.ArgumentTypeError(f"file: {path} does not exist")


      parser = argparse.ArgumentParser()

      parser.add_argument(
          "file", type=ResolvedExistingPath, help="HTML file to patch"
      )

      parser.add_argument(
          "-i",
          action="store_true",
          help="modify file in place",
          dest="inplace",
      )

      parser.add_argument(
          "--set",
          nargs=3,
          metavar=("ELEMENT_PATH", "PROPERTY", "VALUE"),
          action="append",
          required=True,
      )

      args = parser.parse_args()

      file_path = args.file

      tree = html.parse(file_path)

      for epath, prop, value in args.set:
          elem = tree.find(epath)

          if elem is None:
              raise ValueError(f"No element matched: {epath}")

          elem.set(prop, value)

      if args.inplace:
          tree.write(file_path, method="html")
      else:
          print(
              html.tostring(
                  tree, pretty_print=True, method="html", encoding="unicode"
              )
          )
    ''
  )
]

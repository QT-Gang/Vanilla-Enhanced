set lazy

mc_version := `yq -p toml -ot .versions.minecraft ./pack.toml`
fabric_version := `yq -p toml -ot .versions.fabric ./pack.toml`
canonical_version := f"fabric-loader-{{fabric_version}}-{{mc_version}}"
version_path := f"./mc-libassets/versions/{{canonical_version}}"
jvmargs := `yq -p ini -ot \
	'.General | "-Xms\(.MinMemAlloc)M -Xmx\(.MaxMemAlloc)M \(.JvmArgs)"' \
	instance.cfg`

[default]
@list-recipes:
	just --list --unsorted

[group: 'server testing']
@vm-server:
	@# exit with 'Ctrl+a x'
	mkdir -p qemu-mount
	setfattr -n user.virtfs.uid -v 0x00000000 qemu-mount
	setfattr -n user.virtfs.gid -v 0x00000000 qemu-mount
	nixos-shell --flake .#vm

[group: 'production']
update-vinfo:
	yq -p toml -oj 'pick(["name","author","version"])' ./pack.toml > ./versioninfo.json

[group: 'client testing']
launch-client: ensure-version packwiz-install (headlessmc "launch" canonical_version)

[group: 'client testing']
packwiz-install:
	mkdir -p ./.minecraft
	cd ./.minecraft; java -jar "$PACKWIZ_INSTALLER_BOOTSTRAP_JAR" --no-gui \
		http://localhost:8080/pack.toml

[group: 'client testing']
[no-exit-message]
packwiz-server REV="":
	#!/usr/bin/env bash
	set -euo pipefail
	exec &>/dev/null
	if [[ -z "{{REV}}" ]]; then
		packwiz serve
	else
		DIR="$(mktemp -d)"
		trap 'git worktree remove --force "$DIR"' TERM

		git worktree add --detach "$DIR" "{{REV}}"
		packwiz serve --pack-file "$DIR/pack.toml"
	fi

[group: 'client testing']
[env("JAVA_TOOL_OPTIONS", f"-Dhmc.jvmargs={{jvmargs}}")]
headlessmc *ARGS:
	headlessmc {{ if ARGS != "" { "--command " + ARGS } else { "" } }}

[private]
[group: 'client testing']
ensure-version:
	{{ if path_exists(version_path) == "true" {
		""
	} else {
		f"just headlessmc fabric {{mc_version}} --uid {{fabric_version}}"
	} }}

[group: 'client testing']
set-dev-configs:
	# enable fancymenu dev mode
	sed -i "s/B:modpack_mode = 'true';/B:modpack_mode = 'false';/" \
		./.minecraft/config/fancymenu/options.txt

[group: 'development']
fmt:
	nix fmt

alias vm := vm-server
alias pw := packwiz-server
alias client := launch-client

@vm:
	@# exit with 'Ctrl+a x'
	mkdir -p qemu-mount
	setfattr -n user.virtfs.uid -v 0x00000000 qemu-mount
	setfattr -n user.virtfs.gid -v 0x00000000 qemu-mount
	nixos-shell --flake .#vm

update-vinfo:
	yq -p toml -oj 'pick(["name","author","version"])' ./pack.toml > ./versioninfo.json

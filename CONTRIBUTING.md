# Contributing

This project requires [Nix](https://github.com/DeterminateSystems/nix-installer) with Flakes support.

All commands assume you are inside the development shell:

```sh
nix develop
```

## Testing with the Client

On first use, authenticate with Microsoft:

```sh
just headlessmc auth
```

Start a local Packwiz server:

```sh
just packwiz-server
```

Optionally provide a Git revision as an argument to serve a specific version of the pack.

In another terminal, install/update the pack and launch the client:

```sh
just launch-client
```

This downloads the pack from the local Packwiz server and start Minecraft using [HeadlessMC](https://headlesshq.github.io/headlessmc/).

The development shell also provides wrapper functions for running the Packwiz server in the background:

* `pw`: start the local Packwiz server
* `pw-stop`: stop the local Packwiz server

`pw` supports tab completion for branches, tags, and other Git refs.
`pw` accepts the same optional Git ref as `just packwiz-server` and supports tab completion for branches and tags.

## Testing with the Server

Launch the NixOS VM used for server testing:

```sh
just vm-server
```

The client can then be launched from another terminal and connect to the VM.

Exit the VM with `Ctrl+a x`.

# pyright: strict

import argparse
import hashlib
import io
import json
import logging
import re
import sys
import tomllib
import zipfile
from collections.abc import Sequence
from configparser import ConfigParser
from enum import StrEnum, auto
from pathlib import Path
from typing import Any, Final, Literal, TypedDict

import requests

logger = logging.getLogger(__name__)

META: Final[str] = "https://meta.prismlauncher.org/v1"

type Loader = Literal["fabric", "quilt", "forge", "neoforge", "vanilla"]


class LogLevel(StrEnum):
    NOTSET = auto()
    DEBUG = auto()
    INFO = auto()
    WARNING = auto()
    ERROR = auto()
    CRITICAL = auto()


class LoaderInfo(TypedDict):
    uid: str | None
    deps: Sequence[str]


class MMCPackData(TypedDict):
    components: list[Any]
    formatVersion: int


LOADER_CHAINS: dict[Loader, LoaderInfo] = {
    "fabric": {
        "uid": "net.fabricmc.fabric-loader",
        "deps": ["net.fabricmc.intermediary"],
    },
    "quilt": {
        "uid": "org.quiltmc.quilt-loader",
        "deps": ["net.fabricmc.intermediary"],
    },
    "forge": {
        "uid": "net.minecraftforge",
        "deps": [],
    },
    "neoforge": {
        "uid": "net.neoforged",
        "deps": [],
    },
    "vanilla": {
        "uid": None,
        "deps": [],
    },
}


def get_component(uid: str, version: str):
    url: str = f"{META}/{uid}/{version}.json"
    logger.debug(f"Requesting: {url}")
    r = requests.get(url)
    r.raise_for_status()
    return r.json()


def make_entry(data: dict[str, Any], uid: str, version: str, **flags: Any):
    comp = {
        "cachedName": data["name"],
        "cachedVersion": version,
        "uid": uid,
        "version": version,
    }
    if "requires" in data:
        comp["cachedRequires"] = data["requires"]
    if data.get("volatile"):
        comp["cachedVolatile"] = True
    comp.update(flags)
    return comp


def build_mmc_pack(
    mc_version: str, loader_name: Loader, loader_version: str | None = None
) -> MMCPackData:
    chain = LOADER_CHAINS[loader_name]

    logger.debug("Fetching component...")
    mc_data = get_component("net.minecraft", mc_version)
    logger.debug("Done!")
    components = [make_entry(mc_data, "net.minecraft", mc_version, important=True)]

    lwjgl_uid = next(
        r["uid"]
        for r in mc_data.get("requires", [])
        if r["uid"].startswith("org.lwjgl")
    )
    lwjgl_version = next(
        r.get("suggests") or r.get("equals")
        for r in mc_data.get("requires", [])
        if r["uid"] == lwjgl_uid
    )
    lwjgl_data = get_component(lwjgl_uid, lwjgl_version)
    components.append(
        make_entry(lwjgl_data, lwjgl_uid, lwjgl_version, dependencyOnly=True)
    )

    for dep_uid in chain["deps"]:
        dep_data = get_component(dep_uid, mc_version)
        components.append(
            make_entry(dep_data, dep_uid, mc_version, dependencyOnly=True)
        )

    if chain["uid"] and loader_version:
        loader_data = get_component(chain["uid"], loader_version)
        components.append(make_entry(loader_data, chain["uid"], loader_version))

    return {"components": components, "formatVersion": 1}


def create_zip(
    mmc_pack_data: MMCPackData,
    instance_config: ConfigParser,
    icon_obj: tuple[str, bytes],
    output_path: Path,
):
    packwiz_installer_bootstrap = Path("@packwiz-installer-bootstrap@")
    instance_config_buf = io.StringIO()
    instance_config.write(instance_config_buf, space_around_delimiters=False)

    MIN_DATE = (1980, 1, 1, 0, 0, 0)
    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("mmc-pack.json", json.dumps(mmc_pack_data, indent=4))
        zf.writestr("instance.cfg", instance_config_buf.getvalue())

        with open(packwiz_installer_bootstrap, "rb") as f:
            data = f.read()
        zi = zipfile.ZipInfo("minecraft/packwiz-installer-bootstrap.jar")
        zi.date_time = MIN_DATE
        zf.writestr(zi, data)

        zf.writestr(*icon_obj)

    logger.info(f"Wrote to {output_path}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output file or directory path",
    )
    parser.add_argument(
        "-D",
        "--dev",
        action="store_true",
        help="Use http://localhost:8080 for PreLaunchCommand",
    )
    parser.add_argument(
        "--level",
        type=LogLevel,
        help="Logging level as defined by the logging module (lowercase)",
        default=LogLevel.INFO,
    )
    args = parser.parse_args()
    logging.basicConfig(level=args.level.upper())

    pack_toml: Path = Path("./pack.toml")
    instance_file: Path = Path("./instance.cfg")
    icon: Path = Path("./icon.png")

    logger.info("Loading pack.toml data")
    pack_data = tomllib.loads(pack_toml.read_text())
    instance_config: ConfigParser = ConfigParser()
    instance_config.optionxform = lambda optionstr: str(optionstr)
    logger.info("Loading instance.cfg data")
    instance_config.read(instance_file)
    logger.info("Loading icon data")
    icon_data: bytes = icon.read_bytes()
    icon_hash: str = hashlib.sha256(icon_data).hexdigest()[:8]
    logger.debug(f"Icon hash: {icon_hash}")
    icon_key: str = f"{pack_data['name']}_{icon_hash}"
    icon_obj = (f"{icon_key}.png", icon_data)

    instance_config["General"]["iconKey"] = icon_key

    if args.dev:
        logger.info("Dev mode enabled, modifying PreLaunchCommand command")
        instance_config["General"]["PreLaunchCommand"] = re.sub(
            r"http\S*(/pack.toml)",
            "http://localhost:8080\\1",
            instance_config["General"]["PreLaunchCommand"],
        )

    out_name: str = f"{pack_data['name']}.zip"

    if args.output is None:
        output = Path(f"./{out_name}")
    else:
        output = args.output
        if output.is_dir():
            output /= out_name

    match pack_data["versions"]:
        case {"minecraft": mc_version, **remainder}:
            if remainder:
                ((loader_name, loader_version),) = remainder.items()
            else:
                loader_name = "vanilla"
                loader_version = None
        case _:
            raise Exception("Couldn't parse pack.toml")

    logger.info(
        "\n".join(
            [
                "Got:",
                f"    {mc_version = }",  # noqa: E251, E202
                f"    {loader_name = }",  # noqa: E251, E202
                f"    {loader_version = }",  # noqa: E251, E202
            ]
        )
    )

    try:
        logger.info("Building mmc-pack.json data")
        mmc_pack_data = build_mmc_pack(mc_version, loader_name, loader_version)
        logger.info("Creating Zip File")
        create_zip(mmc_pack_data, instance_config, icon_obj, output)
    except requests.HTTPError as e:
        logger.error(f"Failed to fetch metadata: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

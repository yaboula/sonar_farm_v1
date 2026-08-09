"""Build and verify synchronized ox_inventory + Business Hub item artwork."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OX_DIR = ROOT / "inventory_images"
WEB_DIR = ROOT / "web" / "public" / "assets" / "items"
SOURCE_DIR = ROOT / "tmp" / "imagegen"
SAFE_MIN, SAFE_MAX = 30, 482


def item_ids() -> list[str]:
    text = (ROOT / "data" / "ox_inventory_items.lua").read_text(encoding="utf-8")
    return re.findall(r'^    \["([^"]+)"\] = \{$', text, re.MULTILINE)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()


def normalize(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    bbox = alpha_bbox(image)
    if not bbox:
        raise ValueError(f"{source.name}: no opaque subject")
    subject = image.crop(bbox)
    subject.thumbnail((SAFE_MAX - SAFE_MIN, SAFE_MAX - SAFE_MIN), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    canvas.alpha_composite(subject, ((512 - subject.width) // 2, (512 - subject.height) // 2))
    pixels = canvas.load()
    for y in range(512):
        for x in range(512):
            r, g, b, a = pixels[x, y]
            if a == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return canvas


def build() -> None:
    (OX_DIR / "previews" / "64").mkdir(parents=True, exist_ok=True)
    (OX_DIR / "previews" / "128").mkdir(parents=True, exist_ok=True)
    WEB_DIR.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, dict[str, object]] = {}
    for item_id in item_ids():
        source = SOURCE_DIR / f"{item_id}-alpha.png"
        if not source.exists():
            raise FileNotFoundError(source)
        image = normalize(source)
        ox_path = OX_DIR / f"{item_id}.png"
        image.save(ox_path, format="PNG", optimize=True)
        shutil.copyfile(ox_path, WEB_DIR / ox_path.name)
        for size in (64, 128):
            preview = image.resize((size, size), Image.Resampling.LANCZOS)
            preview.save(OX_DIR / "previews" / str(size) / ox_path.name, format="PNG", optimize=True)
        manifest[item_id] = {"sha256": digest(ox_path), "bytes": ox_path.stat().st_size, "width": 512, "height": 512}
    (OX_DIR / "manifest.json").write_text(json.dumps({"version": 1, "items": manifest}, indent=2) + "\n", encoding="utf-8")


def check() -> None:
    expected = set(item_ids())
    actual = {path.stem for path in OX_DIR.glob("*.png")}
    errors: list[str] = []
    if actual != expected:
        errors.append(f"asset names differ: missing={sorted(expected-actual)} extra={sorted(actual-expected)}")
    hashes: dict[str, str] = {}
    for item_id in sorted(expected):
        ox_path, web_path = OX_DIR / f"{item_id}.png", WEB_DIR / f"{item_id}.png"
        if not ox_path.exists() or not web_path.exists():
            errors.append(f"{item_id}: synchronized copies missing")
            continue
        with Image.open(ox_path) as image:
            if image.mode != "RGBA" or image.size != (512, 512):
                errors.append(f"{item_id}: expected RGBA 512x512, got {image.mode} {image.size}")
                continue
            bbox = alpha_bbox(image)
            if not bbox or bbox[0] < SAFE_MIN or bbox[1] < SAFE_MIN or bbox[2] > SAFE_MAX or bbox[3] > SAFE_MAX:
                errors.append(f"{item_id}: alpha bbox {bbox} violates safe area {SAFE_MIN}..{SAFE_MAX}")
            for x, y in ((0, 0), (511, 0), (0, 511), (511, 511)):
                if image.getpixel((x, y))[3] != 0:
                    errors.append(f"{item_id}: corner is not transparent")
                    break
            pixels = image.load()
            if any((pixels[x, y][0] or pixels[x, y][1] or pixels[x, y][2])
                   for y in range(512) for x in range(512) if pixels[x, y][3] == 0):
                errors.append(f"{item_id}: RGB residue exists under alpha zero")
        ox_hash = digest(ox_path)
        if digest(web_path) != ox_hash:
            errors.append(f"{item_id}: web and ox hashes differ")
        if ox_hash in hashes:
            errors.append(f"{item_id}: duplicates {hashes[ox_hash]}")
        hashes[ox_hash] = item_id
        for size in (64, 128):
            preview = OX_DIR / "previews" / str(size) / ox_path.name
            if not preview.exists() or Image.open(preview).size != (size, size):
                errors.append(f"{item_id}: {size}px preview missing or invalid")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"asset QA passed: {len(expected)} synchronized transparent items")


parser = argparse.ArgumentParser()
parser.add_argument("--check", action="store_true")
args = parser.parse_args()
if not args.check:
    build()
check()

"""Build the installable addon ZIP; no repository or publishing operation."""
from pathlib import Path
import argparse
import re
import zipfile

root = Path(__file__).resolve().parents[1]
addon = root / "addon" / "QuestStrangTracker"
toc_path = addon / "QuestStrangTracker.toc"

def build(tag=None):
    toc = toc_path.read_text(encoding="utf-8")
    match = re.search(r"^## Version: (\d+\.\d+\.\d+)$", toc, re.M)
    if not match:
        raise ValueError("Missing or invalid TOC version")
    version = match.group(1)
    core = (addon / "Core.lua").read_text(encoding="utf-8")
    if f'ns.version = "{version}"' not in core:
        raise ValueError("Core and TOC versions differ")
    if tag is not None and tag != f"v{version}":
        raise ValueError("Tag does not match committed addon version")
    listed = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    if len(listed) != len(set(listed)):
        raise ValueError("Duplicate TOC entry")
    for name in listed:
        path = (addon / name).resolve()
        if addon.resolve() not in path.parents or not path.is_file():
            raise ValueError(f"Invalid or missing TOC file: {name}")
    if set(listed) != {path.name for path in addon.glob("*.lua")}:
        raise ValueError("Lua files and TOC differ")
    output = root / "outputs" / f"QuestStrangTracker-v{version}.zip"
    output.parent.mkdir(exist_ok=True)
    entries = [(path.relative_to(addon).as_posix(), path.read_bytes())
               for path in sorted(addon.rglob("*")) if path.is_file()]
    entries.append(("LICENSE", (root / "LICENSE").read_bytes()))
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in entries:
            info = zipfile.ZipInfo("QuestStrangTracker/" + name, date_time=(2026, 10, 8, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, data)
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        assert archive.namelist() == ["QuestStrangTracker/" + name for name, _ in entries]
        assert not any(".tools" in name or name.startswith("/") for name in archive.namelist())
    print(f"Built {output.name}: {len(entries)} files, {output.stat().st_size} bytes")
    return output

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", help="Required to match TOC version if supplied")
    args = parser.parse_args()
    try:
        build(args.tag)
    except ValueError as error:
        parser.error(str(error))

#!/usr/bin/env bash
# Build dist/com.aadi.huddock.plasmoid from ./package
set -euo pipefail
cd "$(dirname "$0")"
python3 - <<'PY'
import json
import os
from pathlib import Path
import re
import tempfile
import zipfile

package = Path("package")
metadata_path = package / "metadata.json"
metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
plugin = metadata["KPlugin"]
version = plugin["Version"]
identifier = r"(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
match = re.fullmatch(
    rf"((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
    rf"(?:-{identifier}(?:\.{identifier})*)?)(?:\+(0|[1-9][0-9]*))?",
    version,
)
if match is None:
    raise SystemExit(f"Invalid version {version!r}: expected MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD], with numeric BUILD")

plugin["Version"] = f"{match[1]}+{int(match[2] or 0) + 1}"
metadata_text = json.dumps(metadata, ensure_ascii=False, indent=2) + "\n"
plugin_id = plugin["Id"]
if not re.fullmatch(r"[A-Za-z0-9_.-]+", plugin_id):
    raise SystemExit(f"Invalid plugin ID: {plugin_id!r}")

dist = Path("dist")
dist.mkdir(exist_ok=True)
output = dist / f"{plugin_id}.plasmoid"
with tempfile.TemporaryDirectory(prefix=".build-", dir=dist) as temporary:
    archive_path = Path(temporary) / output.name
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(package.rglob("*")):
            relative = path.relative_to(package)
            if "__pycache__" in relative.parts or path.suffix == ".pyc" or not path.is_file():
                continue
            if path == metadata_path:
                archive.writestr(str(relative), metadata_text)
            else:
                archive.write(path, str(relative))
    os.replace(archive_path, output)

# Persist the counter only after the package has been built successfully.
metadata_path.write_text(metadata_text, encoding="utf-8")
print(f"Built {output} (version {plugin['Version']})")
PY

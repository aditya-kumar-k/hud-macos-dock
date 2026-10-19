#!/usr/bin/env python3
"""Print installed desktop applications as a JSON array: [{id, name, icon, path}]."""
import configparser
import glob
import json
import os

home = os.path.expanduser("~")
data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
dirs = [
    "/usr/share",
    "/var/lib/flatpak/exports/share",
    os.path.join(home, ".local/share/flatpak/exports/share"),
    os.path.join(home, ".local/share"),
] + data_dirs

apps = {}
for base in dirs:
    for path in glob.glob(os.path.join(base, "applications", "*.desktop")):
        parser = configparser.RawConfigParser(strict=False, interpolation=None)
        parser.optionxform = str
        try:
            parser.read(path, encoding="utf-8")
            entry = parser["Desktop Entry"]
        except Exception:
            continue
        if entry.get("Type") != "Application":
            continue
        if entry.get("NoDisplay", "false").lower() == "true" or entry.get("Hidden", "false").lower() == "true":
            continue
        name = entry.get("Name")
        if not name:
            continue
        # Later directories (user-local) override earlier ones with the same id
        apps[os.path.basename(path)] = {
            "id": os.path.basename(path),
            "name": name,
            "icon": entry.get("Icon", "application-x-executable"),
            "path": path,
        }

print(json.dumps(sorted(apps.values(), key=lambda a: a["name"].lower())))

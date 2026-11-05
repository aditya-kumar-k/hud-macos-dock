#!/usr/bin/env python3
"""List installed apps, or read dropped file URLs with --desktop-files."""
import configparser
import glob
import json
import os
import sys
from urllib.parse import unquote, urlsplit


def read_app(path, *, dropped=False):
    parser = configparser.RawConfigParser(strict=False, interpolation=None)
    parser.optionxform = str
    with open(path, encoding="utf-8") as desktop_file:
        parser.read_file(desktop_file)
    if not parser.has_section("Desktop Entry"):
        raise ValueError("Missing Desktop Entry section")
    entry = parser["Desktop Entry"]
    if entry.get("Type") != "Application":
        raise ValueError("Not an application")
    if entry.get("Hidden", "false").lower() == "true":
        raise ValueError("Application is hidden")
    if not dropped and entry.get("NoDisplay", "false").lower() == "true":
        raise ValueError("Application is excluded from menus")
    name = entry.get("Name", "").strip()
    if not name:
        raise ValueError("Missing application name")
    if dropped and not entry.get("Exec", "").strip() and entry.get("DBusActivatable", "false").lower() != "true":
        raise ValueError("Missing application launch command")
    return {
        "id": os.path.basename(path),
        "name": name,
        "icon": entry.get("Icon", "application-x-executable"),
        "path": path,
    }


def dropped_apps(urls):
    apps = []
    errors = []
    for url in urls:
        try:
            parsed = urlsplit(url)
            if parsed.scheme != "file" or parsed.netloc not in ("", "localhost") or parsed.query or parsed.fragment:
                raise ValueError("Only local desktop files are supported")
            path = unquote(parsed.path, errors="strict")
            if not os.path.isabs(path) or not path.endswith(".desktop"):
                raise ValueError("Expected a .desktop file")
            apps.append(read_app(path, dropped=True))
        except (OSError, ValueError, UnicodeError, configparser.Error) as error:
            errors.append(f"{url}: {error}")
    return {"apps": apps, "errors": errors}


def installed_apps():
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
            try:
                app = read_app(path)
            except (OSError, ValueError, UnicodeError, configparser.Error):
                continue
            # Later directories (user-local) override earlier ones with the same id
            apps[app["id"]] = app
    return sorted(apps.values(), key=lambda a: a["name"].lower())


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--desktop-files":
        print(json.dumps(dropped_apps(sys.argv[2:])))
    else:
        print(json.dumps(installed_apps()))

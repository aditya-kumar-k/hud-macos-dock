#!/usr/bin/env python3
"""Duplicate a dock through Plasma's public desktop scripting interface."""
import json
import shutil
import subprocess
import sys


MARKER = "HUD_DOCK_DUPLICATE:"
PLUGIN = "com.aadi.huddock"


def build_script(payload):
    for key in ("containmentId", "appletId"):
        if type(payload.get(key)) is not int or payload[key] <= 0:
            raise ValueError(f"Invalid {key}")
    if payload.get("plugin") != PLUGIN:
        raise ValueError("Unexpected widget plugin")
    if not isinstance(payload.get("settings"), dict):
        raise ValueError("Missing dock settings")
    data = json.dumps(payload, ensure_ascii=True)
    return """
(function () {
    var data = PAYLOAD;
    var copy = null;
    try {
        var container = desktopById(data.containmentId) || panelById(data.containmentId);
        if (!container || container.locked)
            throw new Error("The desktop or panel is unavailable or locked");
        var original = container.widgetById(data.appletId);
        if (!original || original.type !== data.plugin || original.locked)
            throw new Error("The source widget is unavailable or locked");
        var geometry = original.geometry;
        copy = container.addWidget(data.plugin, Math.max(0, geometry.x + 32),
            Math.max(0, geometry.y + 32), geometry.width, geometry.height);
        if (!copy || !copy.id || typeof copy.writeConfig !== "function")
            throw new Error("Plasma could not create another widget");
        copy.currentConfigGroup = ["General"];
        Object.keys(data.settings).forEach(function (key) {
            copy.writeConfig(key, data.settings[key]);
            if (copy.configKeys.indexOf(key) < 0 || copy.readConfig(key, data.settings[key]) !== data.settings[key])
                throw new Error("Could not copy dock setting: " + key);
        });
        print("HUD_DOCK_DUPLICATE:" + JSON.stringify({id: copy.id}));
    } catch (error) {
        if (copy && typeof copy.remove === "function")
            copy.remove();
        print("HUD_DOCK_DUPLICATE:" + JSON.stringify({error: String(error)}));
    }
})();
""".replace("PAYLOAD", data)


def duplicate(payload):
    script = build_script(payload)
    executable = next((path for name in ("qdbus6", "qdbus-qt6", "qdbus")
                       if (path := shutil.which(name))), None)
    if not executable:
        raise RuntimeError("qdbus6 was not found. Install the Qt D-Bus command-line tools.")
    result = subprocess.run(
        [executable, "org.kde.plasmashell", "/PlasmaShell",
         "org.kde.PlasmaShell.evaluateScript", script],
        capture_output=True, text=True, timeout=30, check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or
                           f"D-Bus call failed with exit code {result.returncode}")
    lines = [line[len(MARKER):] for line in result.stdout.splitlines() if line.startswith(MARKER)]
    if len(lines) != 1:
        raise ValueError("Plasma did not confirm widget duplication: " + result.stdout.strip())
    response = json.loads(lines[0])
    if not isinstance(response, dict):
        raise ValueError("Invalid response from Plasma")
    if "error" in response:
        raise RuntimeError(response["error"])
    if type(response.get("id")) is not int or response["id"] <= 0:
        raise ValueError("Plasma returned an invalid widget ID")
    return response


def main(args):
    try:
        if len(args) != 1:
            raise ValueError("Expected one JSON duplication request")
        payload = json.loads(args[0])
        if not isinstance(payload, dict):
            raise ValueError("Expected a JSON object")
        print(json.dumps(duplicate(payload)))
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

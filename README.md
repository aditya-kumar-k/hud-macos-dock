# HUD Dock

A macOS-style dock for KDE Plasma 6 that shows **only the apps you choose**. Running
apps are not added to it.

- **Icon magnification** — icons grow in a smooth wave under the pointer
- **Launch bounce** — the icon bounces when you start an app
- **Frosted-glass shelf** — a blurred copy of your wallpaper behind the icons
- **Pop-up shortcut** — assign a shortcut and the dock appears over any open window
- **Horizontal or vertical**, with adjustable icon size, spacing, zoom and labels
- A settings window with a searchable app picker, launcher editing, reordering and glass controls
- **Spacers and Latte-style separator bars** to organize apps into groups
- **Drag to reorder** in settings and on the live dock, including the shortcut pop-up
- **Desktop-file synchronization** keeps launcher names and icons up to date while
  preserving dock-specific customizations

## Screenshots

Horizontal, along the bottom edge:

![HUD Dock, horizontal](screenshots/dock-horizontal.png)

Vertical, on the left edge:

![HUD Dock, vertical](screenshots/dock-vertical.png)

## Requirements

- KDE Plasma 6.0 or newer
- `python3` and `gio` (both ship with a standard Fedora, Arch or Ubuntu KDE install)

Developed and tested on Plasma 6.7 on Fedora 44. Other versions should work but have
not been tested.

## Install

From a release `.plasmoid` file:

```sh
kpackagetool6 --type Plasma/Applet --install com.aadi.huddock.plasmoid
```

From this repository:

```sh
kpackagetool6 --type Plasma/Applet --install "$(pwd)/package"
```

Run this from the repository root. Use an absolute package path so KPackage does
not interpret `package` as an installed plugin name.

To update an existing install:

```sh
kpackagetool6 --type Plasma/Applet --upgrade "$(pwd)/package"
```

Then restart
plasmashell (`kquitapp6 plasmashell; kstart plasmashell`).

Then right-click the desktop, choose **Enter Edit Mode → Add Widgets**, and drag
**HUD Dock** onto the desktop.

## Use

- Drag one or more local `.desktop` application files onto the dock to append them.
  The shelf highlights while dragging; existing entries are not duplicated. This
  also works in the shortcut pop-up and in either orientation. Files are read, not
  copied or launched, so keep them at their original paths. Only add launchers you
  trust: clicking their icons later runs the applications they define.
- Right-click the dock → **Configure** to add, edit, reorder and remove apps or
  separators and to change the look.
- In **Apps**, use **Add application…** to search installed applications, or
  **Add from .desktop file…** to enter a local launcher's absolute path. Use the
  edit button to change an app's display name, theme icon name (or absolute image
  path), and `.desktop` file, or choose another installed application. Changes
  affect only the dock, not the original launcher file. Desktop files are validated
  before saving; duplicate apps are not added.
- Use **Add separator…** to insert an empty **Spacer** or a **Separator bar**.
  Reorder them with the same arrows as apps; edit to switch between the two types.
  Bars are vertical on a horizontal dock and horizontal on a vertical dock.
  Separators do not magnify, launch applications or show labels, and work in the
  shortcut pop-up too. Right-click a separator to remove it.
- **Reorder by dragging:** in **Apps**, drag the six-dot grip at the left of a row onto
  another row. On the running dock, drag an icon or separator onto another item.
  A floating preview follows the pointer while neighboring items slide smoothly
  to make room. The faded source marks the proposed position; release to place it.
  The grip shows a hand cursor and a tooltip. Outside a valid destination, the
  preview dims; dropping there cancels and the items slide back. A drag never launches an app;
  ordinary clicks still do. This works horizontally, vertically and in the pop-up.
  Settings changes use the configuration window's usual **Apply** action; changes
  made directly on the dock are saved immediately.
- Right-click an icon for **Open**, **Remove from dock** and **Dock settings**.
- **Pop-up shortcut:** in edit mode, right-click the dock → *Configure → Keyboard
  Shortcuts*, and assign a key to *Activate HUD Dock Widget*. Pressing it shows a copy
  of the dock above the windows. It hides itself a few seconds after you stop using it.

## Settings

| Tab | Option | What it does |
| --- | --- | --- |
| Apps | Add / edit / reorder / remove | The apps shown, with custom names, icons and desktop files |
| Apps | Separators | Empty spacers or Latte-style bars between groups of apps |
| Apps | Drag to reorder | Use the six-dot grip, with a floating preview and animated placement |
| Appearance | Orientation | Horizontal or vertical |
| Appearance | Icon size, spacing | Size of icons and the gap between them |
| Appearance | Magnification | How much the icon under the pointer grows (1.0 = off) |
| Appearance | Launch bounces | Number of bounces on launch (0 = off) |
| Appearance | Labels | Show the app name above the hovered icon |
| Appearance | Glass: tint, blur, sheen | Darkness of the glass, blur strength, top highlight |

### Synchronizing desktop files

The dock reads each referenced local `.desktop` file at startup and every five
seconds. Changes to `Name` and `Icon` update the dock and its shortcut pop-up
without restarting Plasma. The settings page uses the same synchronization,
paused while editing a launcher, choosing an application or dragging.

Names and icons customized in the dock are preserved independently: changing
only the name still allows the icon to follow the file, and vice versa. Choosing
an installed application in the editor and saving its original values restores
automatic synchronization for those fields. Neither synchronization nor editing
modifies or launches the referenced file.

If a file disappears or becomes invalid, the last known values remain visible
and an error is reported. Synchronization resumes when the file is readable
again, including when an external editor replaces it atomically. Removed items
are not re-added by pending synchronization requests.

Older saved entries did not record whether values were customized. On their first
successful synchronization, values matching the current file start following it;
differences are conservatively preserved as customizations. Re-select the
installed application in the editor to adopt its current values.

## How the glass works

Plasma does not blur the wallpaper behind desktop widgets. The dock takes a snapshot of
the wallpaper layer, blurs it, and clips it to the shelf. The snapshot is refreshed at
start-up and every few seconds, so a changed wallpaper is picked up. Where there is no
wallpaper to sample (for example, in a panel), it falls back to a plain translucent card.

## Known limitations

- The dock is a **desktop widget**, not a screen-edge dock. Windows can cover it and it
  does not reserve screen space.
- The pop-up copy is a notification-type window, so it cannot take keyboard focus (Esc
  will not close it) and shows a darker, un-blurred shelf because it sits above other
  windows.
- The bounce runs a fixed number of times; it does not wait for the app to open.
- There are no running-app indicators by design.

## Local development

Use [dev.sh](dev.sh) for common local development commands. It resolves paths
relative to the script, so it also works when called from another directory.
Run it as your desktop user, without `sudo`.

```sh
./dev.sh install         # first local installation
./dev.sh update          # update directly from source; no version bump
./dev.sh restart         # reload Plasma to pick up QML changes
./dev.sh update-restart  # update and reload in one command
./dev.sh test            # Python and QML tests, using offscreen rendering
./dev.sh build           # generate the archive and increment the build version
./dev.sh help
```

`update` requires an existing installation; use `install` first if needed.
Neither command changes the dock's saved settings. Updating from source does
not regenerate the release archive.

**Restarting Plasma briefly closes and recreates the desktop and panels.**
The restart commands require an active user `plasma-plasmashell.service`;
`update-restart` checks this before updating and does not restart if the update
fails. On non-systemd sessions, use `update` and restart Plasma manually with your
session launcher.

Tests require Python 3, Qt 6 QtTest and the KDE QML modules described below.
The script locates the Qt 6 runner with `qtpaths6`, avoiding Qt 5 executables
that may also be on `PATH`. If `qtpaths6` is unavailable or you want to use a
specific Qt 6 installation, provide the runner location:

```sh
QMLTESTRUNNER=/usr/lib/qt6/bin/qmltestrunner ./dev.sh test
```

## Packaging

```sh
./make-package.sh        # creates dist/com.aadi.huddock.plasmoid
```

Each successful build increments the numeric SemVer build metadata in
`KPlugin.Version` in [package/metadata.json](package/metadata.json), for example
`1.1.0` -> `1.1.0+1` -> `1.1.0+2`. The saved version and the version inside the
package match. Major, minor, patch and any prerelease suffix are preserved; setting
a new release version without `+BUILD` restarts its build counter at 1.
The build requires Python 3 and uses its standard-library ZIP support.

## Tests

Run the importer, development-script and packaging tests with Python 3. If PyQt6
is installed, this also tests native file drag-and-drop events and desktop-file
synchronization (the latter requires the KDE Plasma QML modules):

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software python3 -m unittest discover -s tests -v
```

Run the shared QML helper, settings and live-dock gesture tests with the Qt 6
`qmltestrunner` (its location depends on the distribution). The settings tests
require the KDE Plasma, Kirigami and KCMUtils QML modules. Tests validate launchers
and simulate dragging in both orientations and the pop-up without launching apps:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input tests
```

## Support

HUD Dock is free and always will be. If you enjoy it, you can support its development:

- On the KDE Store page, use the **Donate** button.
<!-- Add your own links below, then delete this comment:
- GitHub Sponsors: https://github.com/sponsors/<your-username>
- Ko-fi: https://ko-fi.com/<your-name>
- Liberapay: https://liberapay.com/<your-name>
-->

Bug reports and ideas are welcome too.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).

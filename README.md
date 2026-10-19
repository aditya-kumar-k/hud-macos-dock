# HUD Dock

A macOS-style dock for KDE Plasma 6 that shows **only the apps you choose**. Running
apps are not added to it.

- **Icon magnification** — icons grow in a smooth wave under the pointer
- **Launch bounce** — the icon bounces when you start an app
- **Frosted-glass shelf** — a blurred copy of your wallpaper behind the icons
- **Pop-up shortcut** — assign a shortcut and the dock appears over any open window
- **Horizontal or vertical**, with adjustable icon size, spacing, zoom and labels
- A settings window with a searchable app picker, reordering and glass controls

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
kpackagetool6 --type Plasma/Applet --install package
```

To update an existing install use `--upgrade` instead of `--install`, then restart
plasmashell (`kquitapp6 plasmashell; kstart plasmashell`).

Then right-click the desktop, choose **Enter Edit Mode → Add Widgets**, and drag
**HUD Dock** onto the desktop.

## Use

- Right-click the dock → **Configure** to add, reorder and remove apps and to change
  the look.
- Right-click an icon for **Open**, **Remove from dock** and **Dock settings**.
- **Pop-up shortcut:** in edit mode, right-click the dock → *Configure → Keyboard
  Shortcuts*, and assign a key to *Activate HUD Dock Widget*. Pressing it shows a copy
  of the dock above the windows. It hides itself a few seconds after you stop using it.

## Settings

| Tab | Option | What it does |
| --- | --- | --- |
| Apps | Add / reorder / remove | The apps shown, in order |
| Appearance | Orientation | Horizontal or vertical |
| Appearance | Icon size, spacing | Size of icons and the gap between them |
| Appearance | Magnification | How much the icon under the pointer grows (1.0 = off) |
| Appearance | Launch bounces | Number of bounces on launch (0 = off) |
| Appearance | Labels | Show the app name above the hovered icon |
| Appearance | Glass: tint, blur, sheen | Darkness of the glass, blur strength, top highlight |

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

## Packaging

```sh
./make-package.sh        # creates dist/com.aadi.huddock.plasmoid
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

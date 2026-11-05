#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'HELP'
Usage: ./dev.sh <command>

  install        Install the widget locally for the first time.
  update         Update the local widget from source without building a package.
  restart        Restart Plasma using its active user systemd service.
  update-restart Update the widget, then restart Plasma.
  build          Build the .plasmoid archive (increments the build version).
  test           Run Python and QML tests offscreen.
  help           Show this help.

Run from any directory. No sudo is needed.
Restarting Plasma briefly closes and recreates the desktop and panels.
The restart commands require an active plasma-plasmashell.service.
Tests locate Qt 6 through qtpaths6, or use an explicit QMLTESTRUNNER path.
HELP
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$1" >&2
        exit 1
    fi
}

install_widget() {
    require_command kpackagetool6
    kpackagetool6 --type Plasma/Applet "--$1" "$ROOT/package"
}

check_plasma_service() {
    require_command systemctl
    if ! systemctl --user is-active --quiet plasma-plasmashell.service; then
        printf '%s\n' \
            'Plasma user service is not active; automatic restart was not attempted.' \
            'For non-systemd sessions, restart Plasma manually using your session launcher.' >&2
        exit 1
    fi
}

restart_plasma() {
    systemctl --user restart plasma-plasmashell.service
    systemctl --user is-active --quiet plasma-plasmashell.service
    printf '%s\n' 'Plasma service restarted successfully.'
}

run_tests() {
    require_command python3
    local runner="${QMLTESTRUNNER:-}"
    if [[ -z "$runner" ]]; then
        require_command qtpaths6
        runner="$(qtpaths6 --query QT_INSTALL_BINS)/qmltestrunner"
    fi
    require_command "$runner"
    cd -- "$ROOT"
    export QT_QPA_PLATFORM=offscreen
    export QT_QUICK_BACKEND=software
    python3 -m unittest discover -s tests -v
    "$runner" -input tests
}

if (( $# > 1 )); then
    usage >&2
    exit 2
fi

case "${1:-help}" in
    help|-h|--help)
        usage
        ;;
    install)
        install_widget install
        ;;
    update)
        install_widget upgrade
        printf '%s\n' 'Widget updated. Run ./dev.sh restart to reload QML in Plasma.'
        ;;
    restart)
        check_plasma_service
        restart_plasma
        ;;
    update-restart)
        check_plasma_service
        install_widget upgrade
        restart_plasma
        ;;
    build)
        require_command python3
        bash "$ROOT/make-package.sh"
        ;;
    test)
        run_tests
        ;;
    *)
        printf 'Unknown command: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "dev.sh"


class DevelopmentScriptTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hud development ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copy2(SCRIPT, self.root / "dev.sh")
        (self.root / "package").mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "commands.log"
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "DEV_TEST_LOG": str(self.log),
        }
        self.env.pop("QMLTESTRUNNER", None)
        for name in ("kpackagetool6", "systemctl", "python3", "qmltestrunner"):
            self.write_command(name, """
printf '%s\\n' "${0##*/}" "$@" >> "$DEV_TEST_LOG"
""")
        self.write_command("qtpaths6", 'printf "%s\\n" "${0%/*}"\n')

    def write_command(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/sh\nset -eu\n" + body)
        path.chmod(0o755)

    def run_script(self, *args):
        return subprocess.run(
            ["bash", str(self.root / "dev.sh"), *args],
            cwd=self.root.parent, env=self.env, text=True, capture_output=True,
        )

    def commands(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_help_has_no_side_effects(self):
        for args in ((), ("help",), ("--help",)):
            result = self.run_script(*args)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("update-restart", result.stdout)
        self.assertEqual(self.commands(), [])

    def test_invalid_arguments_have_no_side_effects(self):
        for args in (("unknown",), ("update", "unexpected")):
            result = self.run_script(*args)
            self.assertEqual(result.returncode, 2)
        self.assertEqual(self.commands(), [])

    def test_install_and_update_use_absolute_path(self):
        for command, option in (("install", "--install"), ("update", "--upgrade")):
            with self.subTest(command=command):
                result = self.run_script(command)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.commands()[-5:], [
                    "kpackagetool6", "--type", "Plasma/Applet", option,
                    str(self.root / "package"),
                ])
        self.assertNotIn("systemctl", self.commands())

    def test_update_failure_does_not_restart(self):
        self.write_command("kpackagetool6", "echo 'Update failed' >&2\nexit 7\n")
        result = self.run_script("update-restart")
        self.assertEqual(result.returncode, 7)
        self.assertNotIn("restart", self.commands())
        self.assertNotIn("successfully", result.stdout)

    def test_inactive_service_prevents_update(self):
        self.write_command("systemctl", "exit 3\n")
        result = self.run_script("update-restart")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not active", result.stderr)
        self.assertEqual(self.commands(), [])

    def test_update_restart_orders_commands_and_checks_service(self):
        result = self.run_script("update-restart")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.commands(), [
            "systemctl", "--user", "is-active", "--quiet", "plasma-plasmashell.service",
            "kpackagetool6", "--type", "Plasma/Applet", "--upgrade", str(self.root / "package"),
            "systemctl", "--user", "restart", "plasma-plasmashell.service",
            "systemctl", "--user", "is-active", "--quiet", "plasma-plasmashell.service",
        ])

    def test_restart_failure_is_reported(self):
        self.write_command("systemctl", """
if [ "$2" = restart ]; then
    echo 'Restart failed' >&2
    exit 8
fi
""")
        result = self.run_script("restart")
        self.assertEqual(result.returncode, 8)
        self.assertIn("Restart failed", result.stderr)
        self.assertNotIn("successfully", result.stdout)

    def test_build_delegates_to_existing_script(self):
        (self.root / "make-package.sh").write_text(
            '#!/bin/sh\nprintf "%s\\n" build >> "$DEV_TEST_LOG"\n'
        )
        result = self.run_script("build")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.commands(), ["build"])

    def test_tests_run_offscreen_from_repository(self):
        self.write_command("qmltestrunner", """
printf '%s\\n' "$PWD" "$QT_QPA_PLATFORM" "$QT_QUICK_BACKEND" "$@" >> "$DEV_TEST_LOG"
""")
        self.env["QMLTESTRUNNER"] = str(self.bin / "qmltestrunner")
        result = self.run_script("test")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.commands(), [
            "python3", "-m", "unittest", "discover", "-s", "tests", "-v",
            str(self.root), "offscreen", "software", "-input", "tests",
        ])

    def test_python_failure_stops_qml_tests(self):
        self.write_command("python3", "exit 9\n")
        result = self.run_script("test")
        self.assertEqual(result.returncode, 9)
        self.assertEqual(self.commands(), [])

    def test_default_runner_uses_qt6_installation(self):
        result = self.run_script("test")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.commands()[-3:], ["qmltestrunner", "-input", "tests"])

    def test_missing_explicit_runner_is_reported_before_tests(self):
        self.env["QMLTESTRUNNER"] = str(self.root / "missing-qmltestrunner")
        result = self.run_script("test")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Required command not found", result.stderr)
        self.assertEqual(self.commands(), [])


if __name__ == "__main__":
    unittest.main()

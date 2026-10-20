"""Run the isolated ledger integration test on a specified Android device."""

import argparse
from pathlib import Path
import shutil
import subprocess
import sys

APP_DIR = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("serial", help="adb device serial; never targets the default device")
    serial = parser.parse_args().serial
    subprocess.run(["adb", "-s", serial, "get-state"], check=True, timeout=30, stdout=subprocess.DEVNULL)
    subprocess.run(["adb", "-s", serial, "shell", "input", "keyevent", "KEYCODE_WAKEUP"], check=True, timeout=30)
    original_screen_timeout = subprocess.run(
        ["adb", "-s", serial, "shell", "settings", "get", "system", "screen_off_timeout"],
        check=True, capture_output=True, text=True, timeout=30,
    ).stdout.strip()
    subprocess.run(["adb", "-s", serial, "shell", "settings", "put", "system", "screen_off_timeout", "600000"], check=True, timeout=30)
    subprocess.run(["adb", "-s", serial, "shell", "am", "force-stop", "com.lendentracker.lenden_tracker.acceptance"], check=True, timeout=30)
    subprocess.run(["adb", "-s", serial, "forward", "--remove-all"], check=True, timeout=30)
    # Flutter discovers the VM service through logcat; stale ports can strand the harness.
    subprocess.run(["adb", "-s", serial, "logcat", "-c"], check=True, timeout=30)
    flutter = shutil.which("flutter.bat") or shutil.which("flutter")
    if flutter is None:
        raise FileNotFoundError("Flutter executable not found on PATH")
    try:
        result = subprocess.run(
            [
                flutter, "test", "integration_test/ledger_test.dart", "-d", serial,
                "--flavor", "acceptance", "--timeout", "90s", "--reporter", "expanded",
            ],
            cwd=APP_DIR, timeout=600, check=True,
        )
    finally:
        if original_screen_timeout.isdigit():
            subprocess.run(
                ["adb", "-s", serial, "shell", "settings", "put", "system", "screen_off_timeout", original_screen_timeout],
                check=True, timeout=30,
            )
    print(f"ledger_test completed successfully on {serial} (exit {result.returncode})", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print(f"ledger_test runner failed: {error}", file=sys.stderr, flush=True)
        sys.exit(1)

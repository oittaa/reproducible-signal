#! /usr/bin/env python3

import os
from pathlib import Path
import subprocess

SIGNAL_APK=os.path.join(Path.home(), "Signal.apk")

def test_reproducible_signal():
    popen = subprocess.Popen(
        ["./reproducible-signal.sh", SIGNAL_APK],
        stdout=subprocess.PIPE, universal_newlines=True, bufsize=1
    )
    for line in popen.stdout:
        current_line = line.rstrip()
        print(current_line)
    assert current_line == "APKs match!"

#! /usr/bin/env python3

import contextlib
import io
import os
from pathlib import Path
import subprocess
import tempfile
import time
import shutil
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
from apkdiff3 import ApkDiff

SIGNAL_APK = os.path.join(Path.home(), "Signal.apk")
TEST_RUNNING = True

def test_reproducible_signal():
    global TEST_RUNNING
    popen = subprocess.Popen(
        ["./reproducible-signal.sh", SIGNAL_APK],
        stdout=subprocess.PIPE, universal_newlines=True, bufsize=1
    )
    for line in popen.stdout:
        current_line = line.rstrip()
        print(current_line)
    TEST_RUNNING = False
    assert current_line == "APKs match!"

# The tests below have sleep loops to prolong their runs,
# because Travis times out if there isn't any output in 10 minutes.
def test_apkdiff_siganl_apk_itself():
    count = 0
    while TEST_RUNNING and count < 300:
        time.sleep(1)
        count = count + 1
    temp_dir = tempfile.gettempdir()
    copy_filename = str(time.time()) + "-Signal_copy.apk"
    copy_path = os.path.join(temp_dir, copy_filename)
    shutil.copy2(SIGNAL_APK, copy_path)
    f = io.StringIO()
    with contextlib.redirect_stdout(f):
        ApkDiff().compare(SIGNAL_APK, copy_path)
    assert f.getvalue().rstrip() == "APKs match!"

def test_apkdiff_signal_and_demo():
    count = 0
    while TEST_RUNNING and count < 300:
        time.sleep(1)
        count = count + 1
    f = io.StringIO()
    with contextlib.redirect_stdout(f):
        ApkDiff().compare(SIGNAL_APK, "test/demo.apk")
    assert f.getvalue().splitlines()[-1] == "APKs don't match!"

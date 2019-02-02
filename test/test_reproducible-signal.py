#! /usr/bin/env python3

from contextlib import redirect_stdout
from io import StringIO
from os import path
from pathlib import Path
from subprocess import PIPE, Popen
from tempfile import gettempdir
from time import sleep, time
from shutil import copy2
from sys import path as syspath
syspath.append(path.dirname(path.dirname(path.realpath(__file__))))
from apkdiff3 import ApkDiff

SIGNAL_APK = path.join(Path.home(), "Signal.apk")
TEST_RUNNING = True

def test_reproducible_signal():
    global TEST_RUNNING
    popen = Popen(
        ["./reproducible-signal.sh", SIGNAL_APK],
        stdout=PIPE, universal_newlines=True, bufsize=1
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
        sleep(1)
        count = count + 1
    temp_dir = gettempdir()
    copy_filename = str(time()) + "-Signal_copy.apk"
    copy_path = path.join(temp_dir, copy_filename)
    copy2(SIGNAL_APK, copy_path)
    f = StringIO()
    with redirect_stdout(f):
        ApkDiff().compare(SIGNAL_APK, copy_path)
    assert f.getvalue().rstrip() == "APKs match!"

def test_apkdiff_signal_and_demo():
    count = 0
    while TEST_RUNNING and count < 300:
        sleep(1)
        count = count + 1
    f = StringIO()
    with redirect_stdout(f):
        ApkDiff().compare(SIGNAL_APK, "test/demo.apk")
    assert f.getvalue().splitlines()[-1] == "APKs don't match!"

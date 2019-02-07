#! /usr/bin/env python3

from contextlib import redirect_stdout
from io import StringIO
from os import path
from pathlib import Path
from subprocess import PIPE, Popen
from tempfile import NamedTemporaryFile
from shutil import copy2
from sys import path as syspath
syspath.append(path.dirname(path.dirname(path.realpath(__file__))))
from apkdiff3 import ApkDiff

SIGNAL_APK = path.join(Path.home(), "Signal.apk")

def test_apkdiff_siganl_apk_itself():
    copy_file = NamedTemporaryFile()
    copy_path = copy_file.name
    copy2(SIGNAL_APK, copy_path)
    f = StringIO()
    with redirect_stdout(f):
        ApkDiff().compare(SIGNAL_APK, copy_path)
    assert f.getvalue().rstrip() == "APKs match!"

def test_apkdiff_signal_and_demo():
    f = StringIO()
    with redirect_stdout(f):
        ApkDiff().compare(SIGNAL_APK, "test/demo.apk")
    assert f.getvalue().splitlines()[-1] == "APKs don't match!"

def test_docker_build_image():
    popen = Popen(
        ["./reproducible-signal.sh", "--docker-image-only", SIGNAL_APK],
        stdout=PIPE, universal_newlines=True, bufsize=1
    )
    for line in popen.stdout:
        current_line = line.rstrip()
        print(current_line)
    popen.wait()
    assert popen.returncode == 0

def test_reproducible_signal():
    popen = Popen(
        ["./reproducible-signal.sh", "--website", SIGNAL_APK],
        stdout=PIPE, universal_newlines=True, bufsize=1
    )
    for line in popen.stdout:
        current_line = line.rstrip()
        print(current_line)
    popen.wait()
    assert current_line == "APKs match!"
    assert popen.returncode == 0

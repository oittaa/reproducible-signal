#! /usr/bin/env python3

from contextlib import redirect_stdout
from hashlib import sha256
from io import StringIO
import os
from pathlib import Path
import pytest
import requests
from subprocess import PIPE, Popen
from tempfile import mkstemp
from shutil import copy2
from sys import path
path.append(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
from apkdiff3 import ApkDiff

SIGNAL_JSON_URL = "https://updates.signal.org/android/latest.json"
SIGNAL_DOCID = "org.thoughtcrime.securesms"

def sha256sum(filename):
    h  = sha256()
    b  = bytearray(128*1024)
    mv = memoryview(b)
    with open(filename, 'rb', buffering=0) as f:
        for n in iter(lambda : f.readinto(mv), 0):
            h.update(mv[:n])
    return h.hexdigest()

def test_download_signal_from_website(signal_apk):
    r = requests.get(SIGNAL_JSON_URL)
    data = r.json()
    r = requests.get(data["url"])
    with open(signal_apk, "wb") as f:
        f.write(r.content)
    assert data["sha256sum"] == sha256sum(signal_apk)

def test_apkdiff_siganl_apk_itself(signal_apk):
    fd, copy_path = mkstemp()
    copy2(signal_apk, copy_path)
    f = StringIO()
    with redirect_stdout(f):
        ApkDiff().compare(signal_apk, copy_path)
    os.close(fd)
    os.remove(copy_path)
    assert f.getvalue().rstrip() == "APKs match!"

def test_apkdiff_signal_and_demo(signal_apk):
    f = StringIO()
    with redirect_stdout(f):
        ApkDiff().compare(signal_apk, "test/demo.apk")
    assert f.getvalue().splitlines()[-1] == "APKs don't match!"

def test_building_docker_image(signal_apk):
    popen = Popen(
        ["./reproducible-signal.sh", "--docker-image-only", signal_apk],
        stdout=PIPE, universal_newlines=True, bufsize=1
    )
    for line in popen.stdout:
        current_line = line.rstrip()
        print(current_line)
    popen.wait()
    assert popen.returncode == 0

def test_reproducible_signal_from_website(signal_apk):
    popen = Popen(
        ["./reproducible-signal.sh", "--website", signal_apk],
        stdout=PIPE, universal_newlines=True, bufsize=1
    )
    for line in popen.stdout:
        current_line = line.rstrip()
        print(current_line)
    popen.wait()
    assert current_line == "APKs match!"
    assert popen.returncode == 0

def test_reproducible_signal_from_play_store(signal_apk):
    gsfId = int(os.getenv("GPAPI_GSFID", 0))
    authSubToken = os.getenv("GPAPI_TOKEN")
    if not gsfId or not authSubToken:
        pytest.skip("GPAPI_GSFID or GPAPI_TOKEN missing")

    from gpapi.googleplay import GooglePlayAPI, RequestError
    server = GooglePlayAPI()
    server.login(None, None, gsfId, authSubToken)
    try:
        server.log(SIGNAL_DOCID)
    except RequestError as err:
        pytest.skip("Couldn't fetch APK information from Play Store: {}".format(err))
    fl = server.download(SIGNAL_DOCID)
    with open(signal_apk, "wb") as apk_file:
        for chunk in fl.get("file").get("data"):
            apk_file.write(chunk)
    popen = Popen(
        ["./reproducible-signal.sh", "--play", signal_apk],
        stdout=PIPE, universal_newlines=True, bufsize=1
    )
    for line in popen.stdout:
        current_line = line.rstrip()
        print(current_line)
    popen.wait()
    assert current_line == "APKs match!"
    assert popen.returncode == 0

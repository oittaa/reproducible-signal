#! /usr/bin/env python3

import json
import subprocess
import urllib.request
import wget

SIGNAL_APP_JSON="https://updates.signal.org/android/latest.json"

def test_reproducible_signal():
    data = json.loads(urllib.request.urlopen(SIGNAL_APP_JSON).read())
    apk_filename = wget.download(data['url'])
    popen = subprocess.Popen(
        ["./reproducible-signal.sh", apk_filename],
        stdout=subprocess.PIPE, universal_newlines=True, bufsize=1
    )
    for line in popen.stdout:
        current_line = line.strip()
        print(current_line)
    assert current_line == "APKs match!"

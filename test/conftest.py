from tempfile import mkdtemp
import os
from pathlib import Path
import pytest

@pytest.fixture(scope="session")
def signal_apk():
    temp_dir = mkdtemp()
    temp_signal_apk = Path(temp_dir) / 'Signal.apk'
    yield temp_signal_apk
    os.remove(temp_signal_apk)
    os.rmdir(temp_dir)

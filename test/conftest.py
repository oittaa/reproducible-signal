asdfrom tempfile import mkstemp
import os
import pytest

@pytest.fixture(scope="session")
def signal_apk():
    fd, temp_path = mkstemp()
    yield temp_path
    os.close(fd)
    os.remove(temp_path)

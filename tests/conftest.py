import os
import sys
import glob
import tempfile
import subprocess

import pytest
import requests

from lazyasd import lazyobject
from xonsh.lib.os import rmtree

from conda.api import SubdirData

from conda_press.condatools import artifact_to_wheel


PLATFORM_TO_SUBDIR = {
    "linux": "linux-64",
    "win32": "win-64",
    "darwin": "osx-64",
}

CACHE_DIR = os.path.join(os.path.dirname(__file__), 'artifact-cache')


@lazyobject
def subdir_data():
    subdir = PLATFORM_TO_SUBDIR[sys.platform]
    return SubdirData('conda-forge/' + subdir)


def download_artifact(artifact_ref):
    pkg_records = subdir_data.query(artifact_ref)
    if pkg_records:
        pkg_record = pkg_records[0]
    else:
        raise RuntimeError(f"could not find {artifact_ref} on conda-forge")
    os.makedirs(CACHE_DIR, exist_ok=True)
    local_fn = os.path.join(CACHE_DIR, pkg_record.fn)
    if os.path.isfile(local_fn):
        return local_fn
    resp = requests.get(pkg_record.url)
    with open(local_fn, 'wb') as f:
        f.write(resp.content)
    return local_fn


@pytest.fixture()
def pip_install_artifact(request):
    test_env = tempfile.mkdtemp(prefix="test-env")
    def create_wheel_and_install(artifact_ref):
        artifact_path = download_artifact(artifact_ref)
        wheel = artifact_to_wheel(artifact_path)
        subprocess.run(['virtualenv', test_env], check=True)
        site_packages = glob.glob(os.path.join(test_env, 'lib', 'python*', 'site-packages'))[0]
        if sys.platform.startswith('win'):
            raise RuntimeError("cannot activate on windows yet")
        else:
            code = f"source {test_env}/bin/activate; pip install {wheel.filename}"
            subprocess.run(["bash", "-c", code], check=True)
        return wheel, test_env, site_packages

    yield create_wheel_and_install
    rmtree(test_env, force=True)
    wheels = glob.glob(os.path.join(os.path.dirname(__file__), "*.whl"))
    for w in wheels:
        os.remove(w)

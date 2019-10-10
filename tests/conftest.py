import os
import sys
import glob
import tempfile
import builtins
import subprocess

import pytest
import requests

from lazyasd import lazyobject
from xonsh.lib.os import rmtree

from conda.api import SubdirData

from conda_press.config import Config
from conda_press.wheel import fatten_from_seen
from conda_press.condatools import artifact_to_wheel, CACHE_DIR, artifact_ref_dependency_tree_to_wheels


PLATFORM_TO_SUBDIR = {
    "linux": "linux-64",
    "win32": "win-64",
    "darwin": "osx-64",
}


@lazyobject
def subdir_data_arch():
    subdir = PLATFORM_TO_SUBDIR[sys.platform]
    return SubdirData('conda-forge/' + subdir)


@lazyobject
def subdir_data_noarch():
    return SubdirData('conda-forge/noarch')


def download_artifact(artifact_ref):
    if artifact_ref.startswith('noarch/'):
        noarch = True
        subdir_data = subdir_data_noarch
        _, _, artifact_ref = artifact_ref.partition("/")
    else:
        noarch = False
        subdir_data = subdir_data_arch
    pkg_records = subdir_data.query(artifact_ref)

    # if a python package, get only the ones matching this versuon of python
    pytag = "py{vi.major}{vi.minor}".format(vi=sys.version_info)
    if noarch:
        pass
    else:
        filtered_records = []
        for r in pkg_records:
            if 'py' in r.build:
                if pytag in r.build:
                    filtered_records.append(r)
            else:
                filtered_records.append(r)
        pkg_records = filtered_records
    if pkg_records:
        pkg_record = pkg_records[-1]
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
    wheel = None
    test_env = tempfile.mkdtemp(prefix="test-env")
    def create_wheel_and_install(artifact_ref, include_requirements=True):
        nonlocal wheel
        artifact_path = download_artifact(artifact_ref)
        wheel = artifact_to_wheel(artifact_path, include_requirements=include_requirements)
        subprocess.run(['virtualenv', test_env], check=True)
        if sys.platform.startswith('win'):
            site_packages = os.path.join(test_env, 'Lib', 'site-packages')
            code = f"{test_env}\\Scripts\\activate & pip install {wheel.filename}"
            subprocess.run(code, check=True, shell=True)
        else:
            site_packages = glob.glob(os.path.join(test_env, 'lib', 'python*', 'site-packages'))[0]
            code = f"source {test_env}/bin/activate; pip install {wheel.filename}"
            # uncomment the following when we handle dependencies
            #import_tests = os.path.join(wheel.basedir, 'info', 'test', 'run_test.py')
            #if os.path.isfile(import_tests):
            #    code += f"; python {import_tests}"
            subprocess.run(["bash", "-c", code], check=True)
        return wheel, test_env, site_packages

    yield create_wheel_and_install
    if wheel is not None:
        wheel.clean()
    rmtree(test_env, force=True)
    wheels = glob.glob(os.path.join(os.path.dirname(__file__), "*.whl"))
    for w in wheels:
        os.remove(w)


@pytest.fixture()
def pip_install_artifact_tree(request):
    wheels = {}
    test_env = tempfile.mkdtemp(prefix="test-env")
    def create_wheels_and_install(artifact_ref, include_requirements=True,
                                  skip_python=False, fatten=False, skipped_deps=None):
        nonlocal wheels
        seen = artifact_ref_dependency_tree_to_wheels(
            artifact_ref,
            seen=wheels,
            config=Config(
                skip_python=skip_python,
                include_requirements=include_requirements,
                fatten=fatten,
                subdir=PLATFORM_TO_SUBDIR[sys.platform],
            ),
        )
        if fatten:
            wheels = fatten_from_seen(seen, skipped_deps=skipped_deps)
        subprocess.run(['virtualenv', test_env], check=True)
        wheel_filenames = " ".join(reversed([w.filename for w in wheels.values()
                                             if w is not None]))
        if sys.platform.startswith('win'):
            site_packages = os.path.join(test_env, 'Lib', 'site-packages')
            code = f"{test_env}\\Scripts\\activate & pip install {wheel_filenames}"
            print("Running:\n  " + code)
            subprocess.run(code, check=True, shell=True)
        else:
            site_packages = glob.glob(os.path.join(test_env, 'lib', 'python*', 'site-packages'))[0]
            code = f"source {test_env}/bin/activate; pip install {wheel_filenames}"
            # uncomment the following when we handle dependencies
            #import_tests = os.path.join(wheel.basedir, 'info', 'test', 'run_test.py')
            #if os.path.isfile(import_tests):
            #    code += f"; python {import_tests}"
            print("Running:\n  " + code)
            subprocess.run(["bash", "-c", code], check=True)
        return wheels, test_env, site_packages

    yield create_wheels_and_install
    for wheel in wheels.values():
        if wheel is None:
            continue
        wheel.clean()
    rmtree(test_env, force=True)
    wheel_names = glob.glob(os.path.join(os.path.dirname(__file__), "*.whl"))
    for w in wheel_names:
        os.remove(w)


@pytest.fixture()
def xonsh(request):
    sess = builtins.__xonsh__
    if sess.shell is None:
        from xonsh.shell import Shell
        sess.shell = Shell(sess.execer, ctx=sess.ctx, shell_type="none")
    return sess


@pytest.fixture
def data_folder(request):
    return os.path.join(os.path.dirname(request.module.__file__), "data")

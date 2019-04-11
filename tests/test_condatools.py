import os
import stat
import subprocess

import pytest


def isexecutable(filepath):
    st = os.stat(filepath)
    return bool(st.st_mode & stat.S_IXUSR)


def test_no_symlinks(pip_install_artifact):
    # pip cannot unpack real symlinks, so insure it isn't
    wheel, test_env, sp = pip_install_artifact("re2=2016.11.01")
    should_be_symlink = os.path.join(sp, 'lib', 'libre2.so')
    assert os.path.isfile(should_be_symlink)
    assert not os.path.islink(should_be_symlink)


def test_scripts_to_bin(pip_install_artifact):
    wheel, test_env, sp = pip_install_artifact("patchelf=0.9")
    exc = os.path.join(test_env, 'bin', 'patchelf')
    assert os.path.isfile(exc)
    assert isexecutable(exc)
    proc = subprocess.run([exc, "--version"], check=True, encoding="utf-8", stdout=subprocess.PIPE)
    assert proc.stdout.strip() == "patchelf 0.9"


def test_entrypoints(pip_install_artifact):
    wheel, test_env, sp = pip_install_artifact("noarch/conda-smithy=3.3.2")

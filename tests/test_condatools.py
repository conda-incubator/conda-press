import os
import sys
import stat
import glob
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
    exc = os.path.join(test_env, 'bin', 'conda-smithy')
    assert os.path.isfile(exc)
    assert isexecutable(exc)


def test_numpy(pip_install_artifact):
    wheel, test_env, sp = pip_install_artifact("numpy=1.14.6")
    exc = os.path.join(test_env, 'bin', 'f2py')
    assert os.path.isfile(exc)
    assert isexecutable(exc)
    with open(exc, 'r') as f:
        shebang = f.readline()
    assert shebang.startswith('#!')
    assert 'conda' not in shebang
    assert 'python' in shebang
    if sys.platform.startswith('linux'):
        multiarray = glob.glob(os.path.join(sp, 'numpy', 'core', 'multiarray.*so'))
        malib = multiarray[-1]
        proc = subprocess.run(['patchelf', '--print-rpath', malib], check=True, encoding="utf-8", stdout=subprocess.PIPE)
        assert "lib" in proc.stdout

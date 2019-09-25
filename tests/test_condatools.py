import os
import sys
import ast
import stat
import glob
import subprocess

import pytest

from conda_press.condatools import SYSTEM, SO_EXT, artifact_to_wheel, ArtifactInfo, get_only_deps_on_pypi


ON_LINUX = (SYSTEM == "Linux")
ON_WINDOWS = (SYSTEM == "Windows")
ON_MAC = (SYSTEM == "Darwin")

skip_if_not_on_linux = pytest.mark.skipif(not ON_LINUX, reason="can only be run on Linux")
skip_if_on_windows = pytest.mark.skipif(ON_WINDOWS, reason="can not be run on Windows")


def isexecutable(filepath):
    if ON_WINDOWS:
        # punt on this assert for now
        return True
    st = os.stat(filepath)
    return bool(st.st_mode & stat.S_IXUSR)


def test_no_symlinks(pip_install_artifact, xonsh):
    # pip cannot unpack real symlinks, so insure it isn't
    wheel, test_env, sp = pip_install_artifact("re2=2016.11.01", include_requirements=False)
    if ON_WINDOWS:
        should_be_symlink = os.path.join(sp, 'Library', 'bin', 're2' + SO_EXT)
    else:
        should_be_symlink = os.path.join(sp, 'lib', 'libre2' + SO_EXT)
    assert os.path.isfile(should_be_symlink)
    assert not os.path.islink(should_be_symlink)
    # check the license file
    assert os.path.isfile(os.path.join(sp, 're2-2016.11.01.dist-info/LICENSE'))


@skip_if_not_on_linux
def test_scripts_to_bin(pip_install_artifact):
    wheel, test_env, sp = pip_install_artifact("patchelf=0.9", include_requirements=False)
    exc = os.path.join(test_env, 'bin', 'patchelf')
    assert os.path.isfile(exc)
    assert isexecutable(exc)
    proc = subprocess.run([exc, "--version"], check=True, encoding="utf-8", stdout=subprocess.PIPE)
    assert proc.stdout.strip() == "patchelf 0.9"


def test_entrypoints(pip_install_artifact):
    wheel, test_env, sp = pip_install_artifact("noarch/conda-smithy=3.3.2", include_requirements=False)
    if ON_WINDOWS:
        exc = os.path.join(test_env, 'Scripts', 'conda-smithy.exe')
    else:
        exc = os.path.join(test_env, 'bin', 'conda-smithy')
    assert os.path.isfile(exc)
    assert isexecutable(exc)


def test_numpy(pip_install_artifact):
    wheel, test_env, sp = pip_install_artifact("numpy=1.14.6", include_requirements=False)
    if ON_WINDOWS:
        exc = os.path.join(sp, 'Scripts', 'f2py.py')
    else:
        exc = os.path.join(sp, 'bin', 'f2py')
    assert os.path.isfile(exc)
    assert isexecutable(exc)
    with open(exc, 'r') as f:
        shebang = f.readline()
    assert shebang.startswith('#!')
    assert 'conda' not in shebang
    assert 'python' in shebang
    # check rpath changes
    if ON_LINUX:
        multiarray = glob.glob(os.path.join(sp, 'numpy', 'core', 'multiarray.*so'))
        malib = multiarray[-1]
        proc = subprocess.run(['patchelf', '--print-rpath', malib], check=True, encoding="utf-8", stdout=subprocess.PIPE)
        assert "lib" in proc.stdout


def test_libcblas(pip_install_artifact):
    wheel, test_env, sp = pip_install_artifact("libcblas=3.8.0=4_mkl", include_requirements=False)
    if SYSTEM == "Linux":
        fname = os.path.join(sp, 'lib', 'libcblas.so.3')
    elif SYSTEM == "Darwin":
        fname = os.path.join(sp, 'lib', "libcblas.3.dylib")
    elif SYSTEM == "Windows":
        fname = os.path.join(sp, 'Library', 'bin', "libcblas.dll")
    else:
        fname = None
    assert os.path.isfile(fname)


def test_nasm_executes(pip_install_artifact):
    wheel, test_env, sp = pip_install_artifact("nasm=2.13.02", include_requirements=False)
    if ON_WINDOWS:
        exc = os.path.join(test_env, 'Scripts', 'nasm.bat')
    else:
        exc = os.path.join(test_env, 'bin', 'nasm')
    assert os.path.isfile(exc)
    assert isexecutable(exc)
    proc = subprocess.run([exc, "-v"], check=True, encoding="utf-8", stdout=subprocess.PIPE)
    assert proc.stdout.strip().startswith("NASM version 2.13.02")


def test_xz_tree(pip_install_artifact_tree):
    # tests that execuatbles which link to lib work
    wheels, test_env, sp = pip_install_artifact_tree("xz=5.2.4")
    if ON_WINDOWS:
        exc = os.path.join(test_env, 'Scripts', 'xz.bat')
    else:
        exc = os.path.join(test_env, 'bin', 'xz')
    assert os.path.isfile(exc)
    assert isexecutable(exc)
    proc = subprocess.run([exc, "--version"], check=True, encoding="utf-8", stdout=subprocess.PIPE)
    assert proc.stdout.strip().startswith("xz (XZ Utils) 5.2.4")


def test_python(pip_install_artifact_tree, xonsh):
    # this tests that PYTHONPATH is getting set properly
    spec = "python={0}.{1}.{2}".format(*sys.version_info[:3])
    wheels, test_env, sp = pip_install_artifact_tree(spec)
    if ON_WINDOWS:
        exc = os.path.join(test_env, 'Scripts', 'python.bat')
    else:
        exc = os.path.join(test_env, 'bin', 'python')
    assert os.path.isfile(exc)
    assert isexecutable(exc)
    proc = subprocess.run([exc, "--version"], check=True, encoding="utf-8", stdout=subprocess.PIPE)
    assert proc.stdout.strip().startswith("Python {0}.{1}.{2}".format(*sys.version_info[:3]))
    # now check that site-packages is in sys.path
    proc = subprocess.run([exc, "-c", "import sys; print(sys.path)"], check=True, encoding="utf-8", stdout=subprocess.PIPE)
    out = proc.stdout.strip()
    sys_path = ast.literal_eval(out)
    norm_sys_path = [os.path.normpath(p) for p in sys_path]
    norm_sp = os.path.normpath(sp)
    assert norm_sp in norm_sys_path


def test_click(pip_install_artifact_tree, xonsh):
    # tests that we can create a click package
    # see https://github.com/regro/conda-press/issues/15
    wheels, test_env, sp = pip_install_artifact_tree("click=7.0=py_0", skip_python=True)


@skip_if_on_windows
def test_uvloop(pip_install_artifact_tree, xonsh):
    wheel, test_env, sp = pip_install_artifact_tree("uvloop=0.12.2", skip_python=True, fatten=True)


def test_exclude_add_deps(xonsh, data_folder, tmpdir):
    with tmpdir.as_cwd():
        conda_pkg = os.path.join(data_folder, "test-deps-0.0.1-py_0.tar.bz2")
        wheel = artifact_to_wheel(conda_pkg)
        assert "opencv" in wheel.artifact_info.run_requirements

        wheel = artifact_to_wheel(conda_pkg, exclude_deps=["opencv"])
        assert "opencv" not in wheel.artifact_info.run_requirements

        wheel = artifact_to_wheel(
            conda_pkg, exclude_deps=["opencv"], add_deps=["opencv-python"]
        )
        assert "opencv" not in wheel.artifact_info.run_requirements
        assert "opencv-python" in wheel.artifact_info.run_requirements

        wheel = artifact_to_wheel(
            conda_pkg, add_deps=["six"]
        )
        assert "opencv" in wheel.artifact_info.run_requirements
        assert "six" in wheel.artifact_info.run_requirements



@pytest.mark.parametrize("extension", [".tar", ".tar.gz", ".tar.bz2", ".zip"])
def test_from_tarballs(xonsh, tmpdir, data_folder, extension):
    ArtifactInfo.from_tarball(os.path.join(data_folder, f"test-deps-0.0.1-py_0{extension}"))


def test_get_only_deps_on_pypi_by_artifact(tmpdir, xonsh, data_folder):
    with tmpdir.as_cwd():
        conda_pkg = os.path.join(data_folder, "test-deps-0.0.1-py_0.tar.bz2")
        wheel = artifact_to_wheel(conda_pkg, add_deps=["pytest"], only_pypi=True)
        assert "opencv" not in wheel.artifact_info.run_requirements
        assert "pytest" in wheel.artifact_info.run_requirements


def test_get_only_deps_on_pypi():
    assert get_only_deps_on_pypi(["pytest", "pytest-xdist"]) == {"pytest", "pytest-xdist"}
    assert get_only_deps_on_pypi(["pytest", "NOT_PACKAGE_000"]) == {"pytest"}
    assert get_only_deps_on_pypi(["pytest", "requests"]) == {"pytest", "requests"}


def test_xeus_python(pip_install_artifact_tree, xonsh):
    wheel, test_env, sp = pip_install_artifact_tree("xeus-python=0.5.1", skip_python=True, fatten=True)


@skip_if_not_on_linux
def test_pygobject(pip_install_artifact_tree, xonsh):
    wheel, test_env, sp = pip_install_artifact_tree(
        "pygobject=3.30.4", skip_python=True, fatten=True, skipped_deps={"gobject-introspection"},
    )

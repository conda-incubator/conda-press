"""Some tools for converting conda packages to wheels"""
import os
import tarfile
import tempfile

from xonsh.lib.os import rmtree, indir

from conda_press.wheel import Wheel


def artifact_to_wheel(path):
    """Converts an artifact to a wheel."""
    # setup names
    base = os.path.basename(path)
    name, _, extra = base.partition('-')
    version, _, extra = extra.partition('-')
    extra, _, build = extra.rpartition('-')
    build = os.path.splitext(build)[0]
    while build and not build.isdigit():
        build = build[1:]
    if not build:
        build = None
    # unzip the artifact
    tmpdir = tempfile.mkdtemp(prefix=name)
    if base.endswith('.tar.bz2'):
        mode = 'r:bz2'
    elif base.endswith('.tar'):
        mode - 'r:'
    else:
        mode = 'r'
    with tarfile.TarFile.open(path, mode=mode) as tf:
        tf.extractall(path=tmpdir)
    # create wheel
    wheel = Wheel(name, version, build_tag=build)
    wheel.basedir = tmpdir
    with indir(tmpdir):
        wheel.scripts = g`bin/**`
        wheel.includes = g`include/**`
        wheel.files = g`lib/**` + g`lib64/**`
    wheel.write()
    rmtree(tmpdir, force=True)

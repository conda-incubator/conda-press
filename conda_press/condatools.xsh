"""Some tools for converting conda packages to wheels"""
import os
import json
import tarfile
import tempfile

from xonsh.lib.os import rmtree, indir

from ruamel.yaml import YAML

from conda_press.wheel import Wheel


def wheel_safe_build(build, build_string=None):
    if build is None:
        pass
    elif build_string is None:
        pass
    elif not build.isdigit():
        while build and not build.isdigit():
            build = build[1:]
        if not build:
            build = None
    elif build_string.endswith('_' + build):
        build = build + '_' + build_string[:-(len(build) + 1)]
    else:
        build = build + '_' + build_string
    return build


def index_json_exists(basedir=None, fname=None, info=None):
    return info.index_json is not None


def package_spec_from_index_json(basedir=None, fname=None, info=None):
    idx = info.index_json
    build = wheel_safe_build(str(idx.get("build_number", "0")), idx.get("build", None))
    return idx["name"], idx["version"], build


def meta_yaml_exists(basedir=None, fname=None, info=None):
    return info.meta_yaml is not None


def package_spec_from_meta_yaml(basedir=None, fname=None, info=None):
    meta_yaml = info.meta_yaml
    name = meta_yaml['package']['name']
    version = meta_yaml['package']['version']
    build = meta_yaml['build'].get('number', '0')
    build_string = meta_yaml['build'].get('string', None)
    build = wheel_safe_build(build, build_string)
    return name, version, build


def valid_package_name(basedir=None, fname=None, info=None):
    return fname.count('-') >= 3


def package_spec_from_filename(basedir=None, fname=None, info=None):
    extra, _, build = extra.rpartition('-')
    name, _, version = extra.rpartition('-')
    build = os.path.splitext(build)[0]
    if '_' in build:
        build_string, _, build = build.rpartition('_')
    build = wheel_safe_build(build, build_string)
    return name, version, build


PACKAGE_SPEC_GETTERS = (
    # (checker, getter) tuples in priority order
    (index_json_exists, package_spec_from_index_json),
    (package_spec_from_index_json, package_spec_from_meta_yaml),
    (valid_package_name, package_spec_from_filename),
)


def _group_files(wheel, pkg_files):
    scripts = []
    includes = []
    files = []
    for fname in pkg_files:
        if fname.startswith('bin/'):
            scripts.append(fname)
        elif fname.startswith('include/'):
            includes.append(fname)
        else:
            files.append(fname)
    wheel.scripts = scripts
    wheel.includes = includes
    wheel.files = files


class ArtifactInfo:
    """Representation of artifact info/ directory."""

    def __init__(self, artifactdir):
        self._artifactdir = None
        self.index_json = None
        self.meta_yaml = None
        self.files = None
        self.artifactdir = artifactdir

    @property
    def artifactdir(self):
        return self._artifactdir

    @artifactdir.setter
    def artifactdir(self, value):
        self._artifactdir = value
        # load index.json
        idxfile = os.path.join(value, 'info', 'index.json')
        if os.path.isfile(idxfile):
            with open(idxfile, 'r') as f:
                self.index_json = json.load(f)
        else:
            self.index_json = None
        # load meta.yaml
        metafile = os.path.join(value, 'info', 'recipe', 'meta.yaml')
        if os.path.isfile(metafile):
            yaml = YAML(typ='safe')
            with open(metafile) as f:
                self.meta_yaml = yaml.load(f)
        else:
            self.meta_yaml = None
        # load file listing
        self._load_files()

    def _load_files(self):
        filesname = os.path.join(self._artifactdir, 'info', 'files')
        if os.path.isfile(filesname):
            with open(filesname, 'r') as f:
                raw = f.read().strip()
            self.files = raw.splitlines()
        else:
            with indir(self._artifactdir):
                self.files = set(g`**`) - set(g`info/**`)


def artifact_to_wheel(path):
    """Converts an artifact to a wheel."""
    # unzip the artifact
    base = os.path.basename(path)
    if base.endswith('.tar.bz2'):
        mode = 'r:bz2'
        canonical_name = base[:-8]
    elif base.endswith('.tar'):
        mode - 'r:'
        canonical_name = base[:-4]
    else:
        mode = 'r'
        canonical_name = base
    tmpdir = tempfile.mkdtemp(prefix=canonical_name)
    with tarfile.TarFile.open(path, mode=mode) as tf:
        tf.extractall(path=tmpdir)
    info = ArtifactInfo(tmpdir)
    # get names from meta.yaml
    for checker, getter in PACKAGE_SPEC_GETTERS:
        if checker(basedir=tmpdir, fname=base, info=info):
            name, version, build = getter(basedir=tmpdir, fname=base, info=info)
            break
    else:
        raise RuntimeError(f'could not compute name, version, and build for {path!r}')
    # create wheel
    wheel = Wheel(name, version, build_tag=build)
    wheel.basedir = tmpdir
    _group_files(wheel, info.files)
    wheel.write()
    rmtree(tmpdir, force=True)

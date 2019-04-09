"""Some tools for converting conda packages to wheels"""
import os
import json
import tarfile
import tempfile

from xonsh.lib.os import rmtree, indir

from ruamel.yaml import YAML

from conda_press.wheel import Wheel


def wheel_safe_build(build, build_string=None):
    print("build", build, "build_string", build_string)
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


def index_json_exists(basedir=None, fname=None):
    return os.path.isfile(os.path.join(basedir, 'info', 'index.json'))


def package_spec_from_index_json(basedir=None, fname=None):
    with open(os.path.join(basedir, 'info', 'index.json'), 'r') as f:
        idx = json.load(f)
    build = wheel_safe_build(str(idx.get("build_number", "0")), idx.get("build", None))
    return idx["name"], idx["version"], build


def meta_yaml_exists(basedir=None, fname=None):
    return os.path.isfile(os.path.join(basedir, 'info', 'recipe', 'meta.yaml'))


def package_spec_from_meta_yaml(basedir=None, fname=None):
    yaml = YAML(typ='safe')
    with open(os.path.join(basedir, 'info', 'recipe', 'meta.yaml')) as f:
        meta_yaml = yaml.load(f)
    name = meta_yaml['package']['name']
    version = meta_yaml['package']['version']
    build = meta_yaml['build'].get('number', '0')
    build_string = meta_yaml['build'].get('string', None)
    build = wheel_safe_build(build, build_string)
    return name, version, build


def valid_package_name(basedir=None, fname=None):
    return fname.count('-') >= 3


def package_spec_from_filename(basedir=None, fname=None):
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


def info_files_exists(basedir):
    return os.path.isfile(os.path.join(basedir, 'info', 'files'))


def package_files_from_info(basedir):
    with open(os.path.join(basedir, 'info', 'files'), 'r') as f:
        raw = f.read().strip()
    files = raw.splitlines()
    return files


def can_glob_files(basedir):
    return os.path.isdir(basedir)


def package_files_from_glob(basedir):
    with indir(basedir):
        files = g`**`
    return files


PACKAGE_FILE_GETTERS = (
    # (checker, getter) tuples in priority order
    (info_files_exists, package_files_from_info),
    (can_glob_files, package_files_from_glob),
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
    # get names from meta.yaml
    for checker, getter in PACKAGE_SPEC_GETTERS:
        if checker(basedir=tmpdir, fname=base):
            name, version, build = getter(basedir=tmpdir, fname=base)
            break
    else:
        raise RuntimeError(f'could not compute name, version, and build for {path!r}')
    # create wheel
    wheel = Wheel(name, version, build_tag=build)
    wheel.basedir = tmpdir
    for checker, getter in PACKAGE_FILE_GETTERS:
        if checker(tmpdir):
            pkg_files = getter(tmpdir)
            break
    else:
        raise RuntimeError(f'could not get package files from {path!r}')
    _group_files(wheel, pkg_files)
    wheel.write()
    rmtree(tmpdir, force=True)

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


def _defer_symbolic_links(files):
    first = []
    defer = []
    for f in files:
        if os.path.islink(f):
            defer.append(f)
        else:
            first.append(f)
    return first + defer

def _group_files(wheel, info):
    scripts = []
    includes = []
    files = []
    for fname in info.files:
        if fname.startswith('bin/'):
            scripts.append(fname)
        #elif fname.startswith('include/'):
        # pip places files into "include/site/pythonX.Y/package/" rather
        # than "includes/" This should be reserved for python packages that
        # expect this behavior, and we'll dump the other includes into
        # site-packages, like with lib, etc.
        #    includes.append(fname)
        else:
            files.append(fname)
    wheel.scripts = _defer_symbolic_links(scripts)
    wheel.includes = _defer_symbolic_links(includes)
    wheel.files = _defer_symbolic_links(files)


def major_minor(ver):
    major, _, extra = ver.partition('.')
    minor, _, extra = extra.partition('.')
    return major, minor


PLATFORM_SUBDIRS_TO_TAGS = {
    "noarch": "any",
    "linux-32": "linux_i386",
    "linux-64": "linux_x86_64",
    "osx-64": "macosx_10_9_x86_64",
    "win-32": "win32",
    "win-64": "win_amd64",
}


class ArtifactInfo:
    """Representation of artifact info/ directory."""

    def __init__(self, artifactdir):
        self._artifactdir = None
        self._python_tag = None
        self._abi_tag = None
        self._platform_tag = None
        self._run_requirements = None
        self._noarch = None
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
        # clean up lazy values
        self._python_tag = None
        self._abi_tag = None
        self._platform_tag = None
        self._run_requirements = None
        self._noarch = None

    def _load_files(self):
        filesname = os.path.join(self._artifactdir, 'info', 'files')
        if os.path.isfile(filesname):
            with open(filesname, 'r') as f:
                raw = f.read().strip()
            self.files = raw.splitlines()
        else:
            with indir(self._artifactdir):
                self.files = set(g`**`) - set(g`info/**`)

    @property
    def run_requirements(self):
        if self._run_requirements is not None:
            return self._run_requirements
        reqs = self.meta_yaml.get('requirements', {}).get('run', ())
        rr = dict([x.partition(' ')[::2] for x in reqs])
        self._run_requirements = rr
        return self._run_requirements

    @property
    def noarch(self):
        if self._noarch is not None:
            return self._noarch:
        if self.index_json is not None:
            na = self.index_json.get('noarch', False)
        elif self.meta_yaml is not None:
            na = self.meta_yaml.get('build', {}).get('noarch', False)
        else:
            # couldn't find, assume noarch
            na = False
        self._noarch = na
        return self._noarch

    @property
    def python_tag(self):
        if self._python_tag is not None:
            return self._python_tag
        if 'python' in self.run_requirements:
            pyver = self.run_requirements['python']
            if pyver:
                if pyver.startswith('=='):
                    pytag = 'cp' + ''.join(major_minor(pyver[2:]))
                elif pyver[0].isdigit():
                    pytag = 'cp' + ''.join(major_minor(pyver))
                elif pytag.startswith('>='):
                    pytag = 'cp' + major_minor(pyver)[0]
                else:
                    # couldn't choose, pick no-arch
                    pytag = 'py2.py3'
            else:
                # noarch python, effectively
                pytag = 'py2.py3'
        else:
            # no python dependence, so valid for all Pythons
            pytag = 'py2.py3'
        self._python_tag = pytag
        return self._python_tag

    @property
    def abi_tag(self):
        # explanation of ABI tag at https://www.python.org/dev/peps/pep-0425/#abi-tag
        if self._abi_tag is not None:
            return self._abi_tag
        if self.python_tag == 'py2.py3':
            # no arch or no Python dependnce
            atag = 'none'
        elif self.python_tag == "cp3":
            atag = "abi3"
        elif self.python_tag.startswith('cp'):
            # explanation of ABI suffix at https://www.python.org/dev/peps/pep-3149/
            atag = self.python_tag + 'm'
        else:
            # could not determine, use no-arch setting
            atag = "none"
        self._abi_tag = atag
        return self._abi_tag

    @property
    def platform_tag(self):
        if self._platform_tag is not None:
            return self._platform_tag
        if self.noarch:
            ptag = 'any'
        else:
            platform_subdir = self.index_json["subdir"]
            ptag = PLATFORM_SUBDIRS_TO_TAGS[platform_subdir]
        self._platform_tag = ptag
        return self._platform_tag


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
    wheel = Wheel(name, version, build_tag=build, python_tag=info.python_tag,
                  abi_tag=info.abi_tag, platform_tag=info.platform_tag)
    wheel.basedir = tmpdir
    _group_files(wheel, info)
    wheel.write()
    rmtree(tmpdir, force=True)

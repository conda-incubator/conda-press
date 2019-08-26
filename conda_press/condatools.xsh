"""Some tools for converting conda packages to wheels"""
import os
import re
import sys
import json
import shutil
import platform
import tarfile
import tempfile

from lazyasd import lazyobject
from xonsh.platform import ON_LINUX
from xonsh.tools import print_color
from xonsh.lib.os import rmtree, indir

from ruamel.yaml import YAML

import requests

from conda.api import SubdirData, Solver

from conda_press.wheel import Wheel


CACHE_DIR = os.path.join(tempfile.gettempdir(), 'artifact-cache')
DEFAULT_CHANNELS = ('conda-forge', 'anaconda', 'main', 'r')
SYSTEM = platform.system()
if SYSTEM == "Linux":
    SO_EXT = ".so"
elif SYSTEM == "Darwin":
    SO_EXT = ".dylib"
elif SYSTEM == "Windows":
    SO_EXT = ".dll"
else:
    SO_EXT = None


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


def index_json_exists(info=None):
    return info.index_json is not None


def package_spec_from_index_json(info=None):
    idx = info.index_json
    build = wheel_safe_build(str(idx.get("build_number", "0")), idx.get("build", None))
    return idx["name"], idx["version"], build


def meta_yaml_exists(info=None):
    return info.meta_yaml is not None


def package_spec_from_meta_yaml(info=None):
    meta_yaml = info.meta_yaml
    name = meta_yaml['package']['name']
    version = meta_yaml['package']['version']
    build = meta_yaml['build'].get('number', '0')
    build_string = meta_yaml['build'].get('string', None)
    build = wheel_safe_build(build, build_string)
    return name, version, build


def valid_package_name(info=None):
    fname = os.path.basename(info.artifactdir)
    return fname.count('-') >= 3


def package_spec_from_filename(info=None):
    fname = os.path.basename(info.artifactdir)
    extra, _, build = fname.rpartition('-')
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
    bindir = "Scripts/" if info.subdir.startswith("win") else "bin/"
    for fname in info.files:
        if fname.startswith(bindir):
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


def root_ext(s):
    """gets the extention of the root directory"""
    # in info/files, the path separator is always "/"
    # even on windows
    return os.path.splitext(s.split("/")[0])[1]


BAD_ROOT_EXTS = frozenset([".egg-info", ".dist-info"])


def _remap_noarch_python(wheel, info):
    new_files = []
    for fsname, arcname in wheel.files:
        if arcname.startswith('site-packages/'):
            new_arcname = arcname[14:]
            if root_ext(new_arcname) in BAD_ROOT_EXTS:
                # skip other pip metadata
                continue
        else:
            new_arcname = arcname
        new_files.append((fsname, new_arcname))
    wheel.files = new_files


@lazyobject
def re_site_packages_file_unix():
    return re.compile(r'lib/python\d\.\d/site-packages/(.*)')


@lazyobject
def re_site_packages_file_win():
    return re.compile(r'Lib/site-packages/(.*)')


def is_shared_lib(fname):
    _, ext = os.path.splitext(fname)
    if sys.platform.startswith('linux'):
        rtn = (ext == '.so')
    elif sys.platform.startswith('darwin'):
        rtn = (ext == '.dylib') || (ext == '.so') # cpython extensions use .so because ...?
    elif sys.platform.startswith('win'):
        rtn = (ext == '.dll')
    else:
        rtn = False
    return rtn


def is_elf(fname):
    """Whether or not a file is an ELF binary file."""
    if not ON_LINUX:
        return False
    with ${...}.swap(RAISE_SUBPROC_ERROR=False):
        return bool(!(patchelf @(fname) e>o))


def _remap_site_packages(wheel, info):
    new_files = []
    moved_so = []
    re_site_packages_file = re_site_packages_file_win if info.subdir.startswith("win") else re_site_packages_file_unix
    for fsname, arcname in wheel.files:
        m = re_site_packages_file.match(arcname)
        if m is None:
            new_arcname = arcname
            moved = False
        else:
            new_arcname = m.group(1)
            if root_ext(new_arcname) in BAD_ROOT_EXTS:
                # skip other pip metadata
                continue
            moved = True
        elem = (fsname, new_arcname)
        new_files.append(elem)
        if moved and is_shared_lib(new_arcname):
            moved_so.append(elem)
    wheel.files = new_files
    wheel.moved_shared_libs = moved_so


def major_minor(ver):
    entry, _, _ = ver.partition(',')
    major, _, extra = entry.partition('.')
    minor, _, extra = extra.partition('.')
    return major, minor


@lazyobject
def re_name_from_ref():
    return re.compile("^([A-Za-z0-9_-]+).*?")


def name_from_ref(ref):
    """Gets an artifact name from a ref spec string."""
    return re_name_from_ref.match(ref).group(1).lower()



PLATFORM_SUBDIRS_TO_TAGS = {
    "noarch": "any",
    "linux-32": "linux_i386",
    "linux-64": "linux_x86_64",
    "osx-64": "macosx_10_9_x86_64",
    "win-32": "win32",
    "win-64": "win_amd64",
}


def download_package_rec(pkg_record):
    """Downloads a package record, returning the local filename."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    local_fn = os.path.join(CACHE_DIR, pkg_record.fn)
    if os.path.isfile(local_fn):
        return local_fn
    print(f"Downloading {pkg_record.url}")
    resp = requests.get(pkg_record.url)
    with open(local_fn, 'wb') as f:
        f.write(resp.content)
    print("Download complete")
    return local_fn


def download_artifact_ref(artifact_ref, channels=None, subdir=None):
    """Searches for an artifact on a variety of channels. If subdir is not
    given, only "noarch" is used. Noarch is searched after the given subdit.
    """
    channels = DEFAULT_CHANNELS if channels is None else channels
    for channel in channels:
        # check subdir
        if subdir is not None:
            subdir_data = SubdirData(channel + "/" + subdir)
            pkg_records = subdir_data.query(artifact_ref)
            if pkg_records:
                noarch = False
                break
        # check noarch
        subdir_data = SubdirData(channel + "/noarch")
        pkg_records = subdir_data.query(artifact_ref)
        if pkg_records:
            noarch = True
            break
    else:
        raise RuntimeError(f"could not find {artifact_ref} on {channels} for {subdir}")

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
        print("package records:", pkg_records)
        pkg_record = pkg_records[-1]
    else:
        return None
        raise RuntimeError(f"could not find {artifact_ref} on {channels}")
    return download_package_rec(pkg_record)


def download_artifact(artifact_ref_or_rec, channels=None, subdir=None):
    """Downloads an artifact from a ref spec or a PackageRecord."""
    if isinstance(artifact_ref_or_rec, str):
        return download_artifact_ref(artifact_ref_or_rec, channels=channels, subdir=subdir)
    else:
        return download_package_rec(artifact_ref_or_rec)


def all_deps(package_rec, names_recs, seen=None):
    """Computes the set of all dependency names for a package."""
    package_deps = set(map(name_from_ref, package_rec.depends))
    seen = set() if seen is None else seen
    if package_rec.name in seen:
        return package_deps
    seen.add(package_rec.name)
    for dep_name in list(package_deps):
        package_deps |= all_deps(names_recs[dep_name], names_recs, seen=seen)
    return package_deps


def ref_name(name, ver_build=None):
    if not ver_build:
        rtn = name
    elif ver_build[0].isdigit():
        rtn = name + "=" + ver_build.replace(" ", "=")
    else:
        rtn = name + ver_build.replace(" ", "=")
    return rtn


def _find_file_in_artifact(relative_source, info=None, channels=None, deps_cache=None,
                           strip_symbols=True):
    tgtfile = None
    for name, ver_build in info.run_requirements.items():
        dep_ref = ref_name(name, ver_build=ver_build)
        if dep_ref in deps_cache:
            dep = deps_cache[dep_ref]
        else:
            depfile = download_artifact(dep_ref, channels=channels, subdir=info.subdir)
            if depfile is None:
                print(f"skipping {dep_ref}")
                continue
            dep = ArtifactInfo.from_tarball(depfile, replace_symlinks=False, strip_symbols=strip_symbols)
            deps_cache[dep_ref] = dep
        tgtdep = os.path.join(dep.artifactdir, relative_source)
        print(f"Searching {dep.artifactdir} for link target of {relative_source} -> {tgtdep}")
        if os.path.isfile(tgtdep) or os.path.islink(tgtdep):
            tgtfile = tgtdep
        else:
            tgtfile = find_link_target(tgtdep, info=dep, channels=channels,
                                       deps_cache=deps_cache,
                                       relative_source=relative_source,
                                       strip_symbols=strip_symbols)
        if tgtfile and os.path.islink(tgtfile):
            # recurse even farther down, if what we got is also a link
            tgtfile = find_link_target(tgtfile, info=dep, channels=channels,
                                       deps_cache=deps_cache,
                                       relative_source=relative_source,
                                       strip_symbols=strip_symbols)
        if tgtfile is not None:
            break
    else:
        tgtfile = None
    return tgtfile


def find_link_target(source, info=None, channels=None, deps_cache=None,
                     relative_source=None, strip_symbols=True):
    dc = {} if deps_cache is None else deps_cache
    if os.path.islink(source):
        target = os.readlink(source)
        start = os.path.dirname(source)
        tgtfile = os.path.join(start, target)
    else:
        # this dep doesn't have the target, so search recursively
        if relative_source is None:
            relative_source = os.path.relpath(source, info.artifactdir)
        tgtfile = _find_file_in_artifact(relative_source, info=info, channels=channels, deps_cache=dc,
                                         strip_symbols=strip_symbols)
    if tgtfile is None:
        print(f"{relative_source} is None")
        return None
    if not os.path.exists(tgtfile):
        # not in this artifact, need to do dependency search
        tgtrel = os.path.relpath(tgtfile, info.artifactdir)
        tgtfile = _find_file_in_artifact(tgtrel, info=info, channels=channels,
                                         deps_cache=dc, strip_symbols=strip_symbols)
        if deps_cache is None:
            # clean up, if we are the last call
            for key, dep in dc.items():
                dep.clean()
    elif os.path.islink(tgtfile):
        # target is another symlink! need to go further
        rtn = find_link_target(tgtfile, info=info, channels=channels, deps_cache=dc,
                               strip_symbols=strip_symbols)
    else:
        rtn = tgtfile
    return tgtfile


class ArtifactInfo:
    """Representation of artifact info/ directory."""

    def __init__(self, artifactdir):
        self._artifactdir = None
        self._python_tag = None
        self._abi_tag = None
        self._platform_tag = None
        self._run_requirements = None
        self._noarch = None
        self._entry_points = None
        self.index_json = None
        self.link_json = None
        self.recipe_json = None
        self.about_json = None
        self.meta_yaml = None
        self.files = None
        self.artifactdir = artifactdir

    def clean(self):
        rmtree(self._artifactdir, force=True)

    @property
    def artifactdir(self):
        return self._artifactdir

    @artifactdir.setter
    def artifactdir(self, value):
        if self._artifactdir is not None:
            self.clean()
        self._artifactdir = value
        # load index.json
        idxfile = os.path.join(value, 'info', 'index.json')
        if os.path.isfile(idxfile):
            with open(idxfile, 'r') as f:
                self.index_json = json.load(f)
        else:
            self.index_json = None
        # load link.json
        lnkfile = os.path.join(value, 'info', 'link.json')
        if os.path.isfile(lnkfile):
            with open(lnkfile, 'r') as f:
                self.link_json = json.load(f)
        else:
            self.link_json = None
        # load recipe.json
        recfile = os.path.join(value, 'info', 'recipe.json')
        if os.path.isfile(recfile):
            with open(recfile, 'r') as f:
                self.recipe_json = json.load(f)
        else:
            self.recipe_json = None
        # load about.json
        abtfile = os.path.join(value, 'info', 'about.json')
        if os.path.isfile(abtfile):
            with open(abtfile, 'r') as f:
                self.about_json = json.load(f)
        else:
            self.about_json = None
        # load meta.yaml
        metafile = os.path.join(value, 'info', 'recipe', 'meta.yaml.rendered')
        if not os.path.exists(metafile):
            metafile = os.path.join(value, 'info', 'recipe', 'meta.yaml')
        if os.path.isfile(metafile):
            yaml = YAML(typ='safe')
            with open(metafile) as f:
                try:
                    self.meta_yaml = yaml.load(f)
                except Exception:
                    print("failed to load meta.yaml")
                    self.meta_yaml = None
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
        self._entry_points = None

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
        if "depends" in self.index_json:
            reqs = self.index_json["depends"]
        else:
            reqs = self.meta_yaml.get('requirements', {}).get('run', ())
        rr = dict([x.partition(' ')[::2] for x in reqs])
        self._run_requirements = rr
        return self._run_requirements

    @property
    def noarch(self):
        if self._noarch is not None:
            return self._noarch
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
            if self.noarch == "python":
                if pyver.startswith('=='):
                    pytag = 'py' + ''.join(major_minor(pyver[2:]))
                elif pyver[:1].isdigit():
                    pytag = 'py' + ''.join(major_minor(pyver))
                elif pyver.startswith('>=') and ',<' in pyver:
                    # pinned to a single python version
                    pytag = 'py' + ''.join(major_minor(pyver[2:]))
                elif pyver.startswith('>='):
                    pytag = 'py' + major_minor(pyver[2:])[0]
                else:
                    # couldn't choose, pick no-arch
                    pytag = 'py2.py3'
            elif pyver:
                if pyver.startswith('=='):
                    pytag = 'cp' + ''.join(major_minor(pyver[2:]))
                elif pyver[:1].isdigit():
                    pytag = 'cp' + ''.join(major_minor(pyver))
                elif pyver.startswith('>=') and ',<' in pyver:
                    # pinned to a single python version
                    pytag = 'cp' + ''.join(major_minor(pyver[2:]))
                elif pyver.startswith('>='):
                    pytag = 'cp' + major_minor(pyver[2:])[0]
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
        if self.noarch:
            atag = "none"
        elif self.python_tag == 'py2.py3':
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

    @property
    def entry_points(self):
        if self._entry_points is not None:
            return self._entry_points
        if self.link_json is None:
            ep = []
        else:
            ep = self.link_json.get("noarch", {}).get("entry_points", [])
        self._entry_points = ep
        return self._entry_points

    @property
    def subdir(self):
        return self.index_json["subdir"]

    @classmethod
    def from_tarball(cls, path, replace_symlinks=True, strip_symbols=True, skip_python=False):
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
        info = cls(tmpdir)
        if skip_python and "python" in info.run_requirements:
            return info
        if strip_symbols:
            info.strip_symbols()
        if replace_symlinks:
            info.replace_symlinks(strip_symbols=strip_symbols)
        return info

    def strip_symbols(self):
        """Strips symbols out of binary files"""
        if not ON_LINUX:
            print_color("{RED}Skipping symbol stripping, not on linux!{NO_COLOR}")
        for f in self.files:
            absname = os.path.join(self.artifactdir, f)
            if not is_elf(absname):
                continue
            print_color("striping symbols from {CYAN}" + absname + "{NO_COLOR}")
            with ${...}.swap(RAISE_SUBPROC_ERROR=True):
                ![strip --strip-all --preserve-dates --enable-deterministic-archives @(absname)]

    def replace_symlinks(self, strip_symbols=True):
        # this is needed because of https://github.com/pypa/pip/issues/5919
        # this has to walk the package deps in some cases.
        for f in self.files:
            absname = os.path.join(self.artifactdir, f)
            if not os.path.islink(absname):
                # file is not a symlink, we can skip
                continue
            deps_cache = {}
            target = find_link_target(absname, info=self, deps_cache=deps_cache, strip_symbols=strip_symbols)
            if target is None:
                raise RuntimeError(f"Could not find link target of {absname}")
            print(f"Replacing {absname} with {target}")
            if os.path.isdir(absname):
                os.remove(absname)
                shutil.copytree(target, absname)
            else:
                try:
                    shutil.copy2(target, absname, follow_symlinks=False)
                except shutil.SameFileError:
                    os.remove(absname)
                    shutil.copy2(target, absname, follow_symlinks=False)
            # clean up after the copy
            for key, dep in deps_cache.items():
                dep.clean()


def artifact_to_wheel(path, include_requirements=True, strip_symbols=True, skip_python=False):
    """Converts an artifact to a wheel. The clean option will remove
    the temporary artifact directory before returning.
    """
    # unzip the artifact
    if path is None:
        return
    info = path if isinstance(path, ArtifactInfo) \
           else ArtifactInfo.from_tarball(path, strip_symbols=strip_symbols)
    # get names from meta.yaml
    for checker, getter in PACKAGE_SPEC_GETTERS:
        if checker(info=info):
            name, version, build = getter(info=info)
            break
    else:
        raise RuntimeError(f'could not compute name, version, and build for {path!r}')
    # create wheel
    wheel = Wheel(name, version, build_tag=build, python_tag=info.python_tag,
                  abi_tag=info.abi_tag, platform_tag=info.platform_tag)
    wheel.artifact_info = info
    wheel.basedir = info.artifactdir
    wheel.derived_from = "artifact"
    _group_files(wheel, info)
    if info.noarch == "python":
        wheel.noarch_python = True
        _remap_noarch_python(wheel, info)
    elif "python" in info.run_requirements:
        _remap_site_packages(wheel, info)
        if skip_python:
          info.run_requirements.pop('python')
    wheel.rewrite_python_shebang()
    wheel.rewrite_rpaths()
    wheel.rewrite_scripts_linking()
    wheel.entry_points = info.entry_points
    wheel.write(include_requirements=include_requirements, skip_python=skip_python)
    return wheel


def package_to_wheel(ref_or_rec, channels=None, subdir=None,
                          include_requirements=True, strip_symbols=True,
                          skip_python=False, _top=True):
    """Converts a package ref spec or a PackageRecord into a wheel."""
    path = download_artifact(ref_or_rec, channels=channels, subdir=subdir)
    if path is None:
        # happens for cloudpickle>=0.2.1
        return None
    info = ArtifactInfo.from_tarball(path, strip_symbols=strip_symbols, skip_python=skip_python)
    if skip_python and not _top and "python" in info.run_requirements:
        return None
    wheel = artifact_to_wheel(
        info,
        include_requirements=include_requirements,
        strip_symbols=strip_symbols,
        skip_python=skip_python
    )
    wheel._top = _top
    return wheel


def artifact_ref_dependency_tree_to_wheels(artifact_ref, channels=None, subdir=None,
                                           seen=None, include_requirements=True,
                                           skip_python=False,
                                           strip_symbols=True,
                                           ):
    """Converts all artifact dependencies to wheels for a ref spec string"""
    seen = {} if seen is None else seen
    top_name = name_from_ref(artifact_ref)
    top_found = False

    channels = DEFAULT_CHANNELS if channels is None else channels
    subdirs = (subdir, "noarch") if subdir else ("noarch",)
    solver = Solver("<none>", channels, subdirs=subdirs, specs_to_add=(artifact_ref,))
    package_recs = solver.solve_final_state()

    if skip_python:
        names_recs = {pr.name: pr for pr in package_recs}
        top_package_rec = names_recs[top_name]
        python_deps = set()
        non_python_deps = set()
        direct_deps = set(map(name_from_ref, top_package_rec.depends))
        for direct_name in direct_deps:
            direct_all_deps = all_deps(names_recs[direct_name], names_recs)
            if "python" in direct_all_deps:
                python_deps |= direct_all_deps
                python_deps.add(direct_name)
            else:
                non_python_deps |= direct_all_deps
                non_python_deps.add(direct_name)
        python_deps -= non_python_deps
    else:
        python_deps = set()

    is_top = False
    for package_rec in package_recs:
        if not top_found and package_rec.name == top_name:
            is_top = top_found = True
        else:
            is_top = False

        match_spec_str = str(package_rec.to_match_spec())
        if match_spec_str in seen:
            print_color("Have already seen {YELLOW}" + match_spec_str + "{NO_COLOR}")
            continue

        if skip_python and not is_top and package_rec.name in python_deps:
            print_color("Skipping Python package dependency {YELLOW}" + match_spec_str + "{NO_COLOR}")
            seen[match_spec_str] = None
            continue

        print_color("Building {YELLOW}" + match_spec_str + "{NO_COLOR} as dependency of {GREEN}" + artifact_ref + "{NO_COLOR}")
        wheel = package_to_wheel(
            package_rec,
            channels=channels,
            subdir=subdir,
            skip_python=skip_python,
            include_requirements=include_requirements,
            strip_symbols=strip_symbols,
            _top=is_top
        )
        seen[match_spec_str] = wheel

    return seen

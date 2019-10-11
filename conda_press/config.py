import os
import platform
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Set

CACHE_DIR = os.path.join(tempfile.gettempdir(), "artifact-cache")
DEFAULT_CHANNELS = ("conda-forge", "anaconda", "main", "r")
SYSTEM = platform.system()
if SYSTEM == "Linux":
    SO_EXT = ".so"
elif SYSTEM == "Darwin":
    SO_EXT = ".dylib"
elif SYSTEM == "Windows":
    SO_EXT = ".dll"
else:
    raise ValueError(f"System {SYSTEM} is not supported.")


@dataclass(init=True, repr=True, eq=True, order=False)
class Config:
    subdir: (str, tuple)
    _subdir: tuple = field(init=False, repr=False)
    output: (str, Path) = field(default=None)
    _channels: List[str] = field(init=False, repr=False)
    channels: List[str] = field(default=None)
    exclude_deps: Set[str] = field(default_factory=set)
    add_deps: Set[str] = field(default_factory=set)
    skip_python: bool = False
    strip_symbols: bool = True
    fatten: bool = False
    merge: bool = False
    only_pypi: bool = False
    include_requirements: bool = True

    @property
    def channels(self) -> List[str]:
        return self._channels + list(DEFAULT_CHANNELS)

    @channels.setter
    def channels(self, list_channels: List[str]):
        self._channels = list_channels

    @property
    def subdir(self) -> tuple:
        return self._subdir + ("noarch",)

    @subdir.setter
    def subdir(self, new_subdir: (tuple, str)):
        if isinstance(new_subdir, str):
            new_subdir = (new_subdir,)
        self._subdir = new_subdir

    def clean_deps(self, list_deps):
        return set(list_deps).union(self.add_deps).difference(self.exclude_deps)

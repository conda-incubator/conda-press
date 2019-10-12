import os
import platform
import tempfile
from dataclasses import dataclass, field
from typing import Union, List, Set, Tuple

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
    subdir: Union[str, Tuple[str, ...]]
    channels: List[str]
    output: str = field(default=None)
    _subdir: Tuple[str, ...] = field(init=False, repr=False)
    _channels: List[str] = field(init=False, repr=False, default_factory=list)
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
    def subdir(self) -> Tuple[str, ...]:
        return self._subdir + ("noarch",)

    @subdir.setter
    def subdir(self, new_subdir: Union[Tuple[str, ...], str]):
        if isinstance(new_subdir, str):
            self._subdir = (new_subdir,)
        else:
            self._subdir = new_subdir

    def clean_deps(self, list_deps: Union[Set[str], List[str]]) -> Set[str]:
        """This method is responsible to remove the excluded dependencies and
        add the new dependencies in a list of dependencies received.

        Parameters
        ----------
        list_deps : array_like
            Receives a set or a list of dependencies

        Returns
        -------
        set
            Returns a set with the dependencies.
        """
        return set(list_deps).union(self.add_deps).difference(self.exclude_deps)

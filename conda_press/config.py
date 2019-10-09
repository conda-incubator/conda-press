import os
import platform
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import List

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
    subdir: (str, Path) = ""
    output: (str, Path) = ""
    _channels: List[str] = field(init=False, repr=False)
    channels: List[str] = field(default_factory=list)
    exclude_deps: List[str] = field(default_factory=list)
    add_deps: List[str] = field(default_factory=list)
    skip_python: bool = False
    strip_symbols: bool = True
    fatten: bool = False
    merge: bool = False

    @property
    def channels(self) -> List[str]:
        return self._channels + list(DEFAULT_CHANNELS)

    @channels.setter
    def channels(self, list_channels: List[str]):
        self._channels = list_channels

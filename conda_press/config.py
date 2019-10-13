import os
import platform
import tempfile
from dataclasses import dataclass, field, asdict
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


def get_config_by_yaml(yaml_path, config=None):
    """Free function responsible to create or fill a `Config` object
    with the content of a yaml file.

    Parameters
    ----------
    yaml_path : str
        Path to the YAML file
    config : Config, optional
        If it is received a Config object it will be filled otherwise
        this function will create a new Config object.

    Returns
    -------
    Config
        Config object with the yaml configuration

    """
    from ruamel.yaml import YAML

    if config is None:
        config = Config()

    with open(yaml_path, "r") as config_file:
        yaml = YAML(typ="safe").load(config_file)

    def convert_to_list(yaml_var):
        if isinstance(yaml_var, str):
            return [yaml_var]
        return yaml_var

    def yaml_attr(attr):
        if yaml.get(attr) is not None:
            return yaml.get(attr)
        return asdict(config)[attr]

    if isinstance(yaml_attr("subdir"), list):
        config.subdir = tuple(yaml.subdir)
    else:
        config.subdir = yaml_attr("subdir")

    config.output = yaml_attr("output")
    config.channels = convert_to_list(yaml_attr("channels"))
    config.fatten = yaml_attr("fatten")
    config.skip_python = yaml_attr("skip_python")
    config.strip_symbols = yaml_attr("strip_symbols")
    config.merge = yaml_attr("merge")

    def convert_to_set(yaml_var):
        if isinstance(yaml_var, str):
            return {yaml_var}
        if isinstance(yaml_var, list):
            return set(yaml_var)
        return yaml_var

    config.add_deps = convert_to_set(yaml_attr("add_deps"))
    config.add_deps = convert_to_set(yaml_attr("add_deps"))
    config.only_pypi = yaml_attr("only_pypi")
    config.include_requirements = yaml_attr("include_requirements")
    return config

import os
import platform
import tempfile
from dataclasses import asdict, dataclass, field
from typing import List, Set, Union

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
    subdir: Union[str, List[str]] = field(default_factory=list)
    channels: List[str] = field(default_factory=list)
    output: str = field(default=None)
    exclude_deps: Set[str] = field(default_factory=set)
    add_deps: Set[str] = field(default_factory=set)
    skip_python: bool = False
    strip_symbols: bool = True
    fatten: bool = False
    merge: bool = False
    only_pypi: bool = False
    include_requirements: bool = True

    def get_all_channels(self):
        return self.channels + list(DEFAULT_CHANNELS)

    def get_all_subdir(self):
        if isinstance(self.subdir, str):
            return [self.subdir, "noarch"]
        return self.subdir + ["noarch"]

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

    if "conda_press" in yaml:
        yaml = yaml["conda_press"]

    def convert_to_list(yaml_var):
        if isinstance(yaml_var, str):
            return [yaml_var]
        return yaml_var

    def yaml_attr(attr):
        if yaml.get(attr) is not None:
            return yaml.get(attr)
        return asdict(config)[attr]

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
    config.exclude_deps = convert_to_set(yaml_attr("exclude_deps"))
    config.only_pypi = yaml_attr("only_pypi")
    config.include_requirements = yaml_attr("include_requirements")
    return config

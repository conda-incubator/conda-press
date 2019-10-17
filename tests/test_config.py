import pytest
from ruamel import yaml

from conda_press.config import Config, get_config_by_yaml


@pytest.fixture
def config_obj(tmpdir):
    return Config(
        subdir="SUBDIR",
        output="OUTPUT",
        channels=["FOO-CHANNEL", "CHANNEL2"],
        fatten=True,
        skip_python=True,
        strip_symbols=False,
        merge=True,
        exclude_deps={"EXCLUDE1", "EXCLUDE2"},
        add_deps={"ADD1", "ADD2"},
        only_pypi=True,
        include_requirements=False,
    )


def test_fields(config_obj):
    assert config_obj.get_all_channels() == [
        "FOO-CHANNEL",
        "CHANNEL2",
        "conda-forge",
        "anaconda",
        "main",
        "r",
    ]
    assert config_obj.channels == ["FOO-CHANNEL", "CHANNEL2"]
    assert config_obj.get_all_subdir() == ["SUBDIR", "noarch"]
    assert config_obj.subdir == "SUBDIR"
    assert config_obj.output == "OUTPUT"
    assert config_obj.fatten
    assert config_obj.skip_python
    assert not config_obj.strip_symbols
    assert config_obj.merge
    assert config_obj.exclude_deps == {"EXCLUDE1", "EXCLUDE2"}
    assert config_obj.add_deps == {"ADD1", "ADD2"}
    assert config_obj.only_pypi
    assert not config_obj.include_requirements


def test_clean_deps(config_obj):
    config_obj.add_deps = {"DEP1", "DEP2", "DEP3", "DEP4"}
    config_obj.exclude_deps = {"DEP2", "DEP4"}
    all_deps = ["DEP0", "DEP1", "DEP2", "DEP5"]
    assert config_obj.clean_deps(all_deps) == {"DEP0", "DEP1", "DEP3", "DEP5"}


DICT_CONFIG_CONTENT = {
    "subdir": "SUBDIR",
    "output": "OUTPUT",
    "channels": ["FOO-CHANNEL", "CHANNEL2"],
    "fatten": True,
    "skip_python": True,
    "strip_symbols": False,
    "merge": True,
    "exclude_deps": ["EXCLUDE1", "EXCLUDE2"],
    "add_deps": ["ADD1", "ADD2"],
    "only_pypi": True,
    "include_requirements": False,
}


@pytest.mark.parametrize(
    "config_content", [DICT_CONFIG_CONTENT, {"conda_press": DICT_CONFIG_CONTENT}]
)
def test_populate_config_by_yaml(config_content, tmpdir):
    yaml_path = tmpdir.join("TEST.yaml")
    yaml_path.write(yaml.dump(config_content))
    config_read = get_config_by_yaml(str(yaml_path))
    assert config_read.channels == ["FOO-CHANNEL", "CHANNEL2"]
    assert config_read.get_all_channels() == [
        "FOO-CHANNEL",
        "CHANNEL2",
        "conda-forge",
        "anaconda",
        "main",
        "r",
    ]
    assert config_read.subdir == "SUBDIR"
    assert config_read.get_all_subdir() == ["SUBDIR", "noarch"]
    assert config_read.output == "OUTPUT"
    assert config_read.fatten
    assert config_read.skip_python
    assert not config_read.strip_symbols
    assert config_read.merge
    assert config_read.exclude_deps == {"EXCLUDE1", "EXCLUDE2"}
    assert config_read.add_deps == {"ADD1", "ADD2"}
    assert config_read.only_pypi
    assert not config_read.include_requirements

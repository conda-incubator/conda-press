from conda_press.config import Config


def test_fields(tmpdir):
    config_press = Config(
        subdir=str(tmpdir),
        output=str(tmpdir),
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
    assert (
        config_press.channels.sort()
        == ["FOO-CHANNEL", "conda-forge", "anaconda", "main", "r"].sort()
    )
    assert config_press.subdir == (str(tmpdir), "noarch")
    assert config_press.output == str(tmpdir)
    assert config_press.fatten
    assert config_press.skip_python
    assert not config_press.strip_symbols
    assert config_press.merge
    assert config_press.exclude_deps == {"EXCLUDE1", "EXCLUDE2"}
    assert config_press.add_deps == {"ADD1", "ADD2"}
    assert config_press.only_pypi
    assert not config_press.include_requirements
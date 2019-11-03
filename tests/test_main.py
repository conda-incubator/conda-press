import os

from conda_press import main


def test_main(script_runner, data_folder):
    # Sanity test for main to see if empty options are being handled
    conda_pkg = os.path.join(data_folder, "test-deps-0.0.1-py_0.tar.bz2")
    response = script_runner.run(main.__file__, conda_pkg)
    assert response.success, response.stderr


def test_main_empty_config_yaml(tmpdir, script_runner, data_folder):
    conda_pkg = os.path.join(data_folder, "test-deps-0.0.1-py_0.tar.bz2")
    cp_yaml = tmpdir.join("conda-press.yaml")
    cp_yaml.write("")
    response = script_runner.run(
        main.__file__, conda_pkg, "--config", str(cp_yaml)
    )
    assert response.success, response.stderr

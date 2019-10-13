"""CLI entry point for conda-press"""
from argparse import ArgumentParser

from conda_press.config import Config, get_config_by_yaml
from conda_press.wheel import Wheel, merge, fatten_from_seen
from conda_press.condatools import (
    artifact_to_wheel,
    artifact_ref_dependency_tree_to_wheels,
)


def main(args=None):
    p = ArgumentParser("conda-press")
    p.add_argument("files", nargs="+")
    p.add_argument("--subdir", dest="subdir", default=None)
    p.add_argument("--skip-python", dest="skip_python", default=False,
                   action="store_true", help="Skips Python packages and "
                   "their dependencies.")
    p.add_argument("--strip-symbols", dest="strip_symbols", default=True,
                   action="store_true", help="strips symbols from libraries (default)")
    p.add_argument("--no-strip-symbols", "--dont-strip-symbols", dest="strip_symbols",
                   action="store_false", help="don't strip symbols from libraries")
    p.add_argument("--channels", dest="channels", nargs="+", default=())
    p.add_argument("--fatten", dest="fatten", default=False, action="store_true",
                   help="merges the wheel with all of its dependencies.")
    p.add_argument("--merge", dest="merge", default=False, action="store_true",
                   help="merges a list of wheels into a single wheel")
    p.add_argument("-o", "--output", dest="output", default=None,
                   help="Output file name for merge/fatten. If not given, "
                        "this will be the last wheel listed.")
    p.add_argument("--exclude-deps", dest="exclude_deps", default=None, nargs="+",
                   help="Exclude dependencies from conda package.")
    p.add_argument("--add-deps", dest="add_deps", default=None, nargs="+",
                   help="Add dependencies to the wheel.")
    p.add_argument(
        "--only-pypi",
        dest="only_pypi",
        default=False,
        action="store_true",
        help="Remove dependencies which are not on PyPi when converting conda "
            "package to Python wheel.",
    )
    p.add_argument(
        "--config",
        dest="config_file",
        default=None,
        nargs=1,
        help="Receives an yaml configuration file which will set the options for conda-press.\n"
             "This option has high priority over the others to configure conda-press.",
    )
    ns = p.parse_args(args=args)

    config = Config(
        output=ns.output,
        subdir=ns.subdir,
        channels=ns.channels,
        exclude_deps=set(ns.exclude_deps),
        add_deps=set(ns.add_deps),
        merge=ns.merge,
        fatten=ns.fatten,
        strip_symbols=ns.strip_symbols,
        skip_python=ns.skip_python,
        only_pypi=ns.only_pypi,
    )

    if ns.config_file:
        get_config_by_yaml(ns.config_file, config)

    if ns.merge:
        wheels = {f: Wheel.from_file(f) for f in ns.files}
        output = ns.files[-1] if ns.output is None else ns.output
        merge(wheels, output=output)
        return

    for fname in ns.files:
        if "=" in fname:
            print(f'Converting {fname} tree to wheels')
            seen = artifact_ref_dependency_tree_to_wheels(fname, config=config)
            if ns.fatten:
                fatten_from_seen(seen, output=config.output, skipped_deps=config.exclude_deps)
        else:
            print(f'Converting {fname} to wheel')
            artifact_to_wheel(fname, config=config)


if __name__ == "__main__":
    main()

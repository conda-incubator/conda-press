"""CLI entry point for conda-press"""
from argparse import ArgumentParser

from conda_press.condatools import artifact_to_wheel, artifact_ref_dependency_tree_to_wheels, DEFAULT_CHANNELS


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
    ns = p.parse_args(args=args)
    channels = tuple(ns.channels) + DEFAULT_CHANNELS

    for fname in ns.files:
        if "=" in fname:
            print(f'Converting {fname} tree to wheels')
            artifact_ref_dependency_tree_to_wheels(fname,
                subdir=ns.subdir,
                skip_python=ns.skip_python,
                strip_symbols=ns.strip_symbols,
                channels=channels)
        else:
            print(f'Converting {fname} to wheel')
            artifact_to_wheel(fname, strip_symbols=ns.strip_symbols)


if __name__ == "__main__":
    main()

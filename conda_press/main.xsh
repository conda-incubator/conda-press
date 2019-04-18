"""CLI entry point for conda-press"""
from argparse import ArgumentParser

from conda_press.condatools import artifact_to_wheel, artifact_ref_dependency_tree_to_wheels

def main(args=None):
    p = ArgumentParser("conda-press")
    p.add_argument("files", nargs="+")
    p.add_argument("--subdir", dest="subdir", default=None)
    ns = p.parse_args(args=args)

    for fname in ns.files:
        if "=" in fname:
            print(f'Converting {fname} tree to wheels')
            artifact_ref_dependency_tree_to_wheels(fname, subdir=ns.subdir)
        else:
            print(f'Converting {fname} to wheel')
            artifact_to_wheel(fname)


if __name__ == "__main__":
    main()

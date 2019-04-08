"""CLI entry point for conda-press"""
from argparse import ArgumentParser

from conda_press.condatools import artifact_to_wheel

def main(args=None):
    p = ArgumentParser("conda-press")
    p.add_argument("files", nargs="+")
    ns = p.parse_args(args=args)

    for fname in ns.files:
        print(f'Converting {fname} to wheel')
        artifact_to_wheel(fname)


if __name__ == "__main__":
    main()

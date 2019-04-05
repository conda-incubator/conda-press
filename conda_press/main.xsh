"""CLI entry point for conda-press"""
from argparse import ArgumentParser

def main(args=None):
    p = ArgumentParser("conda-press")
    p.add_argument("files", nargs="+")
    ns = p.parse_args(args=args)

    print(ns.files)


if __name__ == "__main__":
    main()

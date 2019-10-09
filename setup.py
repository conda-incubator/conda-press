#!/usr/bin/env python3
import os
import sys

from setuptools import setup


def main():
    """The main entry point."""
    with open(os.path.join(os.path.dirname(__file__), 'README.md'), 'r') as f:
        readme = f.read()
    if sys.platform == "win32":
        scripts = ['scripts/conda-press.bat']
    else:
        scripts = ['scripts/conda-press']
    skw = dict(
        name='conda-press',
        description='Press conda packages into wheels',
        long_description=readme,
        long_description_content_type='text/markdown',
        license='BSD',
        version='0.0.4',
        author='Anthony Scopatz',
        maintainer='Anthony Scopatz',
        author_email='scopatz@gmail.com',
        url='https://github.com/regro/conda-press',
        platforms='Cross Platform',
        classifiers=['Programming Language :: Python :: 3'],
        packages=['conda_press'],
        package_dir={'conda_press': 'conda_press'},
        package_data={'conda_press': ['*.xsh']},
        scripts=scripts,
        install_requires=['xonsh', 'lazyasd', 'ruamel.yaml', 'tqdm', 'requests'],
        python_requires=">=3.5",
        zip_safe=False,
        )
    setup(**skw)


if __name__ == '__main__':
    main()

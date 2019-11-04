$PROJECT = $GITHUB_REPO = 'conda-press'
$GITHUB_ORG = 'regro'
$PYPI_SIGN = False

$ACTIVITIES = ['authors', 'version_bump', 'changelog',
               'sphinx', 'tag', 'push_tag',
               'ghrelease', 'ghpages', 'pypi',
               'conda_forge',
              ]

$AUTHORS_FILENAME = 'AUTHORS.md'
$VERSION_BUMP_PATTERNS = [
    ('conda_press/__init__.py', r'__version__\s*=.*', '__version__ = "$VERSION"'),
    ('setup.py', r'version\s*=.*', "version='$VERSION',"),
    ('docs/conf.py', r'release\s*=.*', "release = '$VERSION'"),
    ('docs/Makefile', r'RELEASE\s*=.*', "RELEASE = v$VERSION"),
    ]
$CHANGELOG_FILENAME = 'CHANGELOG.md'
$CHANGELOG_TEMPLATE = 'TEMPLATE.md'
$CHANGELOG_PATTERN = "<!-- current developments -->"
$CHANGELOG_HEADER = """
<!-- current developments -->

## v$VERSION
"""

$GHPAGES_REPO = 'git@github.com:regro/conda-press-docs.git'

$DOCKER_CONDA_DEPS = [
    'sphinx', 'recommonmark', 'ruamel.yaml', 'numpydoc', 'xonsh', 'conda', 'tqdm',
    'lazyasd', 'virtualenv', 'requests', 'cloud_sptheme',
]
$DOCKER_INSTALL_COMMAND = 'git clean -fdx && pip install --no-deps .'
$DOCKER_GIT_NAME = 'conda-press'
$DOCKER_GIT_EMAIL = 'conda-press@example.com'
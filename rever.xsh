$PROJECT = $GITHUB_REPO = 'conda-press'
$GITHUB_ORG = 'regro'
$PYPI_SIGN = False

$ACTIVITIES = ['authors', 'version_bump', 'changelog',
               'tag', 'push_tag',
               'ghrelease', 'pypi',
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

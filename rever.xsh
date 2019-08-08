$PROJECT = $GITHUB_REPO = 'conda-press'
$GITHUB_ORG = 'regro'

$ACTIVITIES = ['authors', 'version_bump', 'changelog',
               'tag', 'push_tag',
               'ghrelease', 'pypi',
              ]

$VERSION_BUMP_PATTERNS = [
    ('conda_press/__init__.py', '__version__\s*=.*', '__version__ = "$VERSION"'),
    ('setup.py', 'version\s*=.*', "version='$VERSION',")
    ]
$CHANGELOG_FILENAME = 'CHANGELOG.md'
$CHANGELOG_TEMPLATE = 'TEMPLATE.md'
$AUTHORS_FILENAME = 'AUTHORS.md'

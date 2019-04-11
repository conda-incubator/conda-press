import os

import pytest


def test_no_symlinks(pip_install_artifact):
    # pip cannot unpack real symlinks, so insure it isn't
    wheel, test_env, sp = pip_install_artifact("re2=2016.11.01")
    should_be_symlink = os.path.join(sp, 'lib', 'libre2.so')
    assert os.path.isfile(should_be_symlink)
    assert not os.path.islink(should_be_symlink)
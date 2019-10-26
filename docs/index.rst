Conda-Press
============================
Rever is a xonsh-powered, cross-platform software release tool.  The
goal of rever is to provide sofware projects a standard mechanism for dealing with
code releases. Rever aims to make the process of releasing a new version of a code base
as easy as running a single command. Rever...

* has a number of stock tools and utilities that you can mix and match to meet your projects needs,
* is easily extensible, allowing your project to execute custom release activities, and
* allows you to undo release activities, in the event of a mistake!


==================
Initializing Rever
==================
There are a couple steps you should take to get the most out of rever.

1. Install rever. Rever is on conda-forge so install via
   ``conda install -c conda-forge conda-press``, via pypi with ``pip install conda-press``,
   or from source.

2. Setup a ``r.xsh`` file in the root directory of your source repository.
   Here is a simplified example from ``rever`` itself,

    .. code-block:: xonsh

          $PROJECT = 'rever'
          $ACTIVITIES = [
                        'version_bump',  # Changes the version number in various source files (setup.py, __init__.py, etc)
                        'changelog',  # Uses files in the news folder to create a changelog for release
                        'tag',  # Creates a tag for the new version number
                        'push_tag',  # Pushes the tag up to the $TAG_REMOTE
                        'pypi',  # Sends the package to pypi
                        'conda_forge',  # Creates a PR into your package's feedstock
                        'ghrelease'  # Creates a Github release entry for the new tag
                         ]
          $VERSION_BUMP_PATTERNS = [  # These note where/how to find the version numbers
                                   ('rever/__init__.py', '__version__\s*=.*', "__version__ = '$VERSION'"),
                                   ('setup.py', 'version\s*=.*,', "version='$VERSION',")
                                   ]
          $CHANGELOG_FILENAME = 'CHANGELOG.rst'  # Filename for the changelog
          $CHANGELOG_TEMPLATE = 'TEMPLATE.rst'  # Filename for the news template
          $PUSH_TAG_REMOTE = 'git@github.com:regro/rever.git'  # Repo to push tags to

          $GITHUB_ORG = 'regro'  # Github org for Github releases and conda-forge
          $GITHUB_REPO = 'rever'  # Github repo for Github releases  and conda-forge

3. After setting up the ``rever.xsh`` file run ``rever setup`` in the root
   directory of your source repository. This will setup files and other things
   needed for rever to operate.
4. It is always a good idea to check that you have permissions and the proper
   libraries installed, so it is best to run ``rever check`` before every release.
5. When you are ready to release run ``rever <new_version_number>`` and rever
   will take care of the rest.

=========
Contents
=========
**Installation:**

.. toctree::
    :titlesonly:
    :maxdepth: 1

    dependencies

**Guides:**

.. toctree::
    :titlesonly:
    :maxdepth: 1

    tutorial
    usepatterns
    news
    authorship

**Configuration & Setup:**

.. toctree::
    :titlesonly:
    :maxdepth: 1

    activities
    envvars


**Development Spiral:**

.. toctree::
    :titlesonly:
    :maxdepth: 1

    api/index
    devguide/
    changelog


.. include:: dependencies.rst


============
Contributing
============
We highly encourage contributions to conda-press! If you would like to contribute,
it is as easy as forking the repository on GitHub, making your changes, and
issuing a pull request. If you have any questions about this process don't
hesitate to ask on the `Gitter <https://gitter.im/regro/conda-press>`_ channel.

See the `Developer's Guide <devguide.html>`_ for more information about contributing.

=============
Helpful Links
=============

* `Documentation <http://regro.github.io/conda-press-docs>`_
* `Gitter <https://gitter.im/regro/conda-press>`_
* `GitHub Repository <https://github.com/regro/conda-press>`_
* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`

.. raw:: html

    <a href="https://github.com/regro/conda-press" class='github-fork-ribbon' title='Fork me on GitHub'>Fork me on GitHub</a>

    <style>
    /*!
     * Adapted from
     * "Fork me on GitHub" CSS ribbon v0.2.0 | MIT License
     * https://github.com/simonwhitaker/github-fork-ribbon-css
     */

    .github-fork-ribbon, .github-fork-ribbon:hover, .github-fork-ribbon:hover:active {
      background:none;
      left: inherit;
      width: 12.1em;
      height: 12.1em;
      position: absolute;
      overflow: hidden;
      top: 0;
      right: 0;
      z-index: 9999;
      pointer-events: none;
      text-decoration: none;
      text-indent: -999999px;
    }

    .github-fork-ribbon:before, .github-fork-ribbon:after {
      /* The right and left classes determine the side we attach our banner to */
      position: absolute;
      display: block;
      width: 15.38em;
      height: 1.54em;
      top: 3.23em;
      right: -3.23em;
      box-sizing: content-box;
      transform: rotate(45deg);
    }

    .github-fork-ribbon:before {
      content: "";
      padding: .38em 0;
      background-image: linear-gradient(to bottom, rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.1));
      box-shadow: 0 0.07em 0.4em 0 rgba(0, 0, 0, 0.3);'
      pointer-events: auto;
    }

    .github-fork-ribbon:after {
      content: attr(title);
      color: #000;
      font: 700 1em "Helvetica Neue", Helvetica, Arial, sans-serif;
      line-height: 1.54em;
      text-decoration: none;
      text-align: center;
      text-indent: 0;
      padding: .15em 0;
      margin: .15em 0;
      border-width: .08em 0;
      border-style: dotted;
      border-color: #777;
    }

    </style>

Conda-Press
============================
Press conda packages into wheels.

The wheels created by conda-press are usable in a general Python
setting, i.e. outside of a conda managed environment.

Quick start
-----------

Run the ``conda press`` command and point it at either an artifact
file or spec. For example:

.. code-block:: sh

    # from artifact spec, produces single wheel, including all non-Python requirements
    $ conda press --subdir linux-64 --skip-python --fatten scikit-image=0.15.0=py37hb3f55d8_2

    # from artifact file, produces a single wheel
    $ conda press numpy-1.14.6-py36he5ce36f_1201.tar.bz2

    # from artifact spec, produces wheels for package and all requirements
    $ conda press --subdir linux-64 xz=5.2.4=h14c3975_1001

    # merge many wheels into a single wheel
    $ conda press --merge *.whl -output scikit_image-0.15.0-2_py37hb3f55d8-cp37-cp37m-linux_x86_64.whl

What we are solving
-------------------
conda-press allows us to build out a pip-usable package index which is
ABI compatible with conda packages. This can help address the following
issues / workflows:

**Issue 1:**

It can be very difficult to build wheels for packages that have C extensions.
Also, the provenance of wheels with C extentions can be hard to know (who built it,
how it was built, etc.). Conda-press enables community building of wheels,
based on conda-forge provided packages. This should make it very easy to build a
valid wheel.

**Issue 2:**

Many packages with compiled extensions do not have wheels available on one or more
popular platforms (Windows, Mac, Linux). This is because building wheels can
be very difficult.  Conda has a lot of packages that are not available as wheels otherwise.
Conda-press allows these packages to easily become generally usable wheels.

**Issue 3:**

Some people want a package index built on newer ABIs than `manylinux<N>`.

**Issue 4:**

Conda-Press addresses the issue of making shared library dependencies loadable at runtime
by having a unix-like directory structure inside of the `site-packages/` directory. This
allows wheels to have a common `$RPATH` that they can all point to.


How to install
--------------

From conda:

.. code-block:: sh

    conda install -c conda-forge conda-press

From the source code:

.. code-block:: sh

    $ pip install --no-deps .

More technical details about what we are doing
----------------------------------------------
What conda-press does is take an artifact or spec, and turn it into wheel(s).
When using pip to install such a wheel, it shoves the root level of the artifact
into site-packages. It then provides wrapper / proxy scripts that point to
site-packages/bin so that you may run executables and scripts.

Contents
--------
**Installation:**

.. toctree::
    :titlesonly:
    :maxdepth: 1

    dependencies


**Conferences:**

.. toctree::
    :titlesonly:
    :maxdepth: 1

    confs/pydata-nyc2019.md

**Development Spiral:**

.. toctree::
    :titlesonly:
    :maxdepth: 1

    api/index
    devguide/
    changelog


.. include:: dependencies.rst


Contributing
-------------
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

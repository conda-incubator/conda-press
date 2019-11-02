.. _devguide:

=================
Developer's Guide
=================
Welcome to the conda-press developer's guide!  This is a place for developers to
place information that does not belong in the user's guide or the library
reference but is useful or necessary for the next people that come along to
develop conda-press.

.. note:: All code changes must go through the pull request review procedure.


Changelog
=========
Pull requests will often have CHANGELOG entries associated with. However,
to avoid excessive merge conflicts, please follow the following procedure:

1. Go into the ``news/`` directory,
2. Copy the ``TEMPLATE.rst`` file to another file in the ``news/`` directory.
   We suggest using the branchname::

        $ cp TEMPLATE.rst branch.rst

3. Add your entries as a bullet pointed lists in your ``branch.rst`` file in
   the appropriate category. It is OK to leave the ``None`` entries for later
   use.
4. Commit your ``branch.rst``.

Feel free to update this file whenever you want! Please don't use someone
else's file name. All of the files in this ``news/`` directory will be merged
automatically at release time.  The ``None`` entries will be automatically
filtered out too!


Style Guide
===========
Conda-press is a Xonsh & Python project, and so we use PEP8 (with some additions) to
ensure consistency throughout the code base.

----------------------------------
Rules to Write By
----------------------------------
It is important to refer to things and concepts by their most specific name.
When writing conda-press code or documentation please use technical terms
appropriately. The following rules help provide needed clarity.

**********
Interfaces
**********
* User-facing APIs should be as generic and robust as possible.
* Tests belong in the top-level ``tests`` directory.
* Documentation belongs in the top-level ``docs`` directory.

************
Expectations
************
* Code must have associated tests and adequate documentation.
* Have *extreme* empathy for your users.
* Be selfish. Since you will be writing tests you will be your first user.

-------------------
Python Style Guide
-------------------
Conda-press uses `PEP8`_ for all Python code. The following rules apply where `PEP8`_
is open to interpretation.

* Use absolute imports (``import conda-press.tools``) rather than explicit
  relative imports (``import .tools``). Implicit relative imports
  (``import tools``) are never allowed.
* We use sphinx with the numpydoc extension to autogenerate API documentation. Follow
  the `numpydoc`_ standard for docstrings.
* Simple functions should have simple docstrings.
* Lines should be at most 80 characters long. The 72 and 79 character
  recommendations from PEP8 are not required here.
* All Python code should be compliant with Python 3.6+.
* Tests should be written with pytest using a procedural style. Do not use
  unittest directly or write tests in an object-oriented style.
* Test generators make more dots and the dots must flow!

How to Test
================

----------------------------------
Dependencies
----------------------------------

Prep your environment for running the tests by installing ``pytest``

----------------------------------
Running the Tests - Basic
----------------------------------

Run all the tests using pytest::

    $ pytest

Use "-q" to keep pytest from outputting a bunch of info for every test.

----------------------------------
Running the Tests - Advanced
----------------------------------

To perform all unit tests::

    $ pytest

If you want to run specific tests you can specify the test names to
execute. For example to run test_aliases::

    $ pytest test_aliases.py

Note that you can pass multiple test names in the above examples::

    $ pytest test_aliases.py test_environ.py

Happy Testing!


How to Document
====================
Documentation takes many forms. This will guide you through the steps of
successful documentation.

----------
Docstrings
----------
No matter what language you are writing in, you should always have
documentation strings along with you code. This is so important that it is
part of the style guide.  When writing in Python, your docstrings should be
in reStructured Text using the `numpydoc`_ format.

------------------------
Auto-Documentation Hooks
------------------------
The docstrings that you have written will automatically be connected to the
website, once the appropriate hooks have been setup.  At this stage, all
documentation lives within conda-press's top-level ``docs`` directory.
We uses the sphinx tool to manage and generate the documentation, which
you can learn about from `the sphinx website <http://sphinx-doc.org/>`_.
If you want to generate the documentation, first conda-press itself must be installed
and then you may run the following command from the ``docs`` dir:

.. code-block:: console

    ~/conda-press/docs $ make html

For each new
module, you will have to supply the appropriate hooks. This should be done the
first time that the module appears in a pull request.  From here, call the
new module ``mymod``.  The following explains how to add hooks.

------------------------
Python Hooks
------------------------
Python documentation lives in the ``docs/api`` directory.
First, create a file in this directory that represents the new module called
``mymod.rst``.
The ``docs/api`` directory matches the structure of the ``conda_press/`` directory.
So if your module is in a sub-package, you'll need to go into the sub-package's
directory before creating ``mymod.rst``.
The contents of this file should be as follows:

**mymod.rst:**

.. code-block:: rst

    .. _conda_press_mymod:

    =======================================
    My Awesome Module -- :mod:`conda_press.mymod`
    =======================================

    .. currentmodule:: conda_press.mymod

    .. automodule:: conda_press.mymod
        :members:

This will discover all of the docstrings in ``mymod`` and create the
appropriate webpage. Now, you need to hook this page up to the rest of the
website.

Go into the ``index.rst`` file in ``docs/api/`` or other subdirectory and add
``mymod`` to the appropriate ``toctree`` (which stands for table-of-contents
tree). Note that every sub-package has its own ``index.rst`` file.


Building the Website
===========================

Building the website/documentation requires the following dependencies:

#. `Sphinx <http://sphinx-doc.org/>`_
#. `Cloud Sphinx Theme <https://pythonhosted.org/cloud_sptheme/cloud_theme.html>`_
#. recommonmark

-----------------------------------
Procedure for modifying the website
-----------------------------------
The conda-press website source files are located in the ``docs`` directory.
A developer first makes necessary changes, then rebuilds the website locally
by executing the command::

    $ make html

This will generate html files for the website in the ``_build/html/`` folder.
The developer may view the local changes by opening these files with their
favorite browser, e.g.::

    $ google-chrome _build/html/index.html

Once the developer is satisfied with the changes, the changes should be
committed and pull-requested per usual. Once the pull request is accepted, the
developer can push their local changes directly to the website by::

    $ make push-root

Branches and Releases
=============================
Mainline conda-press development occurs on the ``master`` branch. Other branches
may be used for feature development (topical branches) or to represent
past and upcoming releases.


Document History
===================
Portions of this page have been forked from the PyNE and Xonsh documentation,
Copyright 2015-2016, the xonsh developers. All rights reserved.
Copyright 2011-2015, the PyNE Development Team. All rights reserved.

.. _PEP8: https://www.python.org/dev/peps/pep-0008/
.. _numpydoc: https://github.com/numpy/numpy/blob/master/doc/HOWTO_DOCUMENT.rst.txt

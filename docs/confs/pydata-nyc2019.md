# Conda-press, or Reinventing the Wheel

Conda-press (https://github.com/regro/conda-press) is a new tool that
lets you transform conda packages (artifacts) into Python wheels. This talk will:

* discuss why in the world you would want to do such a terrible thing,
* demonstrate that you can do such a terrible thing (live!),
* dive-in to how such as terrible thing is done, and
* define some safety precausions when doing such a terrible thing on your own.

## Discuss

Building software is hard. Luckily, conda-forge is a huge community (1.5k+)
dedicated to building software, focused on the PyData stack. Unfortunately,
some users still want to be able to `pip install` packages. Double unfortunately,
creating binary wheels across many different platforms is often extremely difficult
for any package with a C-extension.

The central idea behind conda-press is that if there is already a conda-forge
package, all of the hard work has already been done! To provide wheels, we
should just be able to massage those artifacts into a more circular shape.

## Demonstrate

Because we conda-press is just shuffling bits around, managing metadata,
and not compiling anything new, it is quite fast! This talk will demo
creating and installing wheels for a few different packages. For example,
packages like numpy, scipy, or uvloop are all good candidates. This talk
may also demonstrate generating wheels for more esoteric packages that are
not related to Python, such as cmake, R, or even Python itself!

## Dive-in

This talk will discuss the underlying layout of the wheels that are
created and how these wheels are built to work well with other wheels
created by conda-press.

This talk will also explain the underlying architecture of conda-press, and how
typical workflows are implemented. Conda-press relies on a number of external,
platform-specifc command line utlities. Conda-press is largely written in
the xonsh langauge to enable this.

## Defense

This talk will also offer guidance against common pitfalls when creating
wheels with conda-press. This includes the distinction between fat and skinny
wheels, namespace differences between PyPI and conda-forge, and issues with
prefix substituions.

# conda-press

Press conda packages into wheels.

The wheels created by conda-press are usable in a general Python
setting, i.e. outside of a conda managed environment.

## Quick start

Run the `conda press` command and point it at either an artifact
file or spec. For example:

```
# from artifact spec, produces single wheel, including all non-Python requirements
$ conda press --subdir linux-64 --skip-python --fatten scikit-image=0.15.0=py37hb3f55d8_2

# from artifact file, produces a single wheel
$ conda press numpy-1.14.6-py36he5ce36f_1201.tar.bz2

# from artifact spec, produces wheels for package and all requirements
$ conda press --subdir linux-64 xz=5.2.4=h14c3975_1001

# merge many wheels into a single wheel
$ conda press --merge *.whl -output scikit_image-0.15.0-2_py37hb3f55d8-cp37-cp37m-linux_x86_64.whl
```

## What we are solving

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

**Issue 3:** Some people want a package index built on newer ABIs than `manylinux<N>`


## How to install

From conda:

```
conda install -c conda-forge conda-press
```

From the source code:

```
$ pip install --no-deps .
```

## More technical details about what we are doing

What conda-press does is take an artifact or spec, and turn it into wheel(s).
When using pip to install such a wheel, it shoves the root level of the artifact
into site-packages. It then provides wrapper / proxy scripts that point to
site-packages/bin so that you may run executables and scripts.

## How to get involved

Please feel free to open up a PR or open an issue!

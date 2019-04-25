# conda-press

Press conda packages into wheels.

## Quick start

Run the `conda press` command and point it at either an artifact
file or spec. For example:

```
# from artifact spec, produces a single wheel
$ conda press numpy-1.14.6-py36he5ce36f_1201.tar.bz2

# from artifact spec, produces wheel for package and all requirments
$ conda press --subdir linux-64 xz=5.2.4=h14c3975_1001
```

## What we are solving

conda-press allows us to build out a pip-usable package index which is
ABI compatible with conda packages. This can help address the following
issues / workflows:

**Issue 1:**

1. Yes, people should use the conda packages directly.
2. However, we know that people pip install packages in their conda
   environment anyways!
3. This can cause a lot of dynamic linking unpleasentness because suddenly
   the user's environments are linking to different run times.
4. If they happen to use the wheels created by conda-press while using conda,
   the user can obtain a consistent environment (even though they should have
   used the equivalent conda package).
5. By pip installing against this channel, a user will effectively swap out
   their whole environment for the conda-version.

**Issue 2:** Some people want a package indes built on newer ABIs than `manylinux<N>`

**Issue 3:** Conda has a lot of packages that are not available as wheels otherwise.
Conda-press allows these packages to easily become wheels.


## How to install

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

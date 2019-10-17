======================
conda-press Change Log
======================






<!-- current developments -->

## v0.0.5
**Added:**

* Added option `--config` which accepts a path to a yaml file with the configuration to run `conda-press`.
* The `YAML` file passed using the option `--config` also accepts the 
configuration to be inside of the key `conda_press`.

**Changed:**

* Add dataclass `Config` following the `Introduce Parameter Object` design pattern. 
    `Config` is responsible to hold the `conda-press` configuration. 
    Refactored internal classes/functions to use the new approach.

**Authors:**

* Anthony Scopatz
* Marcelo Duarte Trevisani



## v0.0.4
**Added:**

* `wheels.fatten_from_seen()` now has a `skipped_deps` keyword argument
* Add new option `--only-pypi` which will remove any dependency which is not available on PyPi.

**Changed:**

* Fattened wheels now respect `--exclude-deps`

**Fixed:**

* Fix file types which might be uncompressed when using `from_tarball` method.
* Removed `WHEEL`, `METADATA`, and `RECORD` files from fat wheels.

**Authors:**

* Anthony Scopatz
* Marcelo Duarte Trevisani



## v0.0.3
**Added:**

* Add plugin ``pytest-azurepipelines`` to show test reports on Azure Pipelines
* Add option `--add-deps` to be able to add new dependencies to the wheel.
* Add option `--exclude-deps`. With this option the user will be able to exclude dependencies from the artifacts.

**Fixed:**

* Removed unused imports

**Authors:**

* Anthony Scopatz
* Marcelo Duarte Trevisani



## v0.0.2
**Added:**

* Initial support for RPATH fix-up on macOS

**Fixed:**

* Requirements listed in the wheel metadata are now removed approriately
  if Python was skipped or if the wheel is a merger of other wheels.
* Don't list python as a runtime requirement when building with '--skip-python'
* Apply RPATH fixups to '.so' libraries on macOS, because that is CPython extension default
* Fixed issue with noarch Python version reading.

**Authors:**

* Anthony Scopatz
* Isaiah Norton



## v0.0.1
**Added:**

* Initial version of conda-press!

**Authors:**

* Anthony Scopatz
* P. L. Lim
* Julien Schueller




# Boost

Each archive contains the associated Boost version with all the header files
and only the libraries required for building the testing executable(s). Only
the multi-threaded static release builds of the following libraries are
included in order to keep the archives small:

  - atomic
  - chrono
  - date_time
  - filesystem
  - log
  - log_setup
  - regex
  - system
  - thread
  - unit_test_framework

## Script Generation

A script has been created called `generate.sh`. This script will download and
extract the built libraries from SourceForge and automatically create the
archives that are required for the driver into the current working directory
with the associated version number of Boost requested.


```
Usage: generate.sh [OPTION...]

    --debug                         include debug libraries
    --version <version>             version number to retrieve and archive
                                    (default: 1.64.0)
    --help                          display this message
```

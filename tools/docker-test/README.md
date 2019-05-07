# Docker image for OpenXPKI test suite

This is an easy way to run the OpenXPKI test suite on any Git branch.

Image specifications:

* Ubuntu 14.04
* Standard system Perl v5.18.2
* MySQL Server 5.5

Please note that there is a wrapper that builds and executes this Docker image automatically:

    tools/docker-test.pl

## (Re-)Build image

The Docker image has to be built once (after changes to its configuration):

    # assuming you are in the project's root directory:
    # (register image as "oxi-test" for easier access)
    docker build -t oxi-test tools/docker-test

**Attention**: as the Docker image comes preinstalled with a lot of CPAN modules
it will not reliably detect missing dependency specifications in Makefile.PL!

### Update preinstalled Perl modules

The list of preinstalled Perl modules for the Docker image is managed in `cpanfile`. To update it run this from the project's root directory:

    ./tools/scripts/makefile2cpanfile.pl > tools/docker-test/cpanfile

After that, rebuild the Docker image as shown above.

## Running tests

Mandatory and optional parameters for the Docker container must be given as environment variables. (They are processed by `startup.pl`):

    OXI_TEST_ALL       - Bool: 1 = run all tests (this is the default)
    OXI_TEST_COVERAGE  - Bool: 1 = run coverage tests
    OXI_TEST_ONLY      - Str: comma separated list of relative paths to test dirs/files
    OXI_TEST_GITREPO   - Str: Git repository
    OXI_TEST_GITBRANCH - Str: Git branch, default branch if not specified

If errors occur while executing tests a Bash shell will be opened. This allows you to figure out what went wrong.

### Local repository

To run tests on the local HEAD commit (not your working directory!) you have to mount your project root into the Docker directory `/repo` via `-v`:

    docker run -ti --rm \
      -v ~/prj/openxpki:/repo \
      oxi-test

You might choose another commit:

    docker run -ti --rm \
      -v ~/prj/openxpki:/repo \
      -e OXI_TEST_GITBRANCH=feature \
      oxi-test

To only execute a particular test:

    docker run -ti --rm \
      -v ~/prj/openxpki:/repo \
      -e OXI_TEST_ONLY=qatest/backend/api2/50_profiles.t \
      oxi-test

To only execute tests in two directories:

    docker run -ti --rm \
      -v ~/prj/openxpki:/repo \
      -e OXI_TEST_ONLY=core/server/t/91_api2,qatest/backend/api2 \
      oxi-test


### Git repository, default branch

    docker run -ti --rm \
      -e OXI_TEST_GITREPO=https://github.com/openxpki/openxpki.git \
      oxi-test

### Other Git branch

    docker run -ti --rm \
      -e OXI_TEST_GITREPO=https://github.com/openxpki/openxpki.git \
      -e OXI_TEST_GITBRANCH=master \
      oxi-test

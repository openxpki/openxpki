Docker Setup to Build OpenXPKI for Debian
#########################################

This directory provides a docker setup to build and sign packages for debian.

The default is to build the top commit of the current branch. You can set
OPENXPKI_BUILD_TAG to a commit or tag to build instead of HEAD but the
target must be in the current branch.

Step 1 - Container
------------------

Call `make build` or `make build-nocache` to create the docker container.

Step 2 - CPAN Deps
------------------

Create the directory `deps` and put any requried extra build dependency
packages there, this is required to build e.g. the perl packages for
LibSCEP (`make Crypt__LibSCEP`).

Now call `make cpan` to build the packages for the CPAN modules.
The packages will end up in the directory `packages` (will be created if
not already present).

Step 3 - OpenXPKI Packages
--------------------------

The full OpenXPKI release consists of three packages, `core`, `i18n`
and `cgi-session-driver`, the target `openxpki` builds then all.

This does **not** require the CPAN packages to be build or present, the
packages will also end up in the `packages` directory.

Step 4 - Create Repo
--------------------

Run `make repo` builds a debian repository structure and writes it to
the directory `repository`. The files from the `reprepro` folder will
be used as defaults if `reprepro/conf` does not exist.

All packages from the `package` directory will be included, you can feed
extra packages (e.g. libscep) from the `extra` folder.

If you want to sign the packages, place the required keys into the
directory `secret`, you will be prompted for the passwords.

Step 5 - Run Test
-----------------

Run `make test` to execute a minimal testset using the packages from a
previous build in the `packages` directory.


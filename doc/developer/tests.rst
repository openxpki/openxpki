=====
Tests
=====

The OpenXPKI project contains a large and still growing number of tests to ensure
code quality and ease refactoring.

Historically tests are categorized into two groups:

* *unit tests* in ``core/server/t/``: tests for single classes and limited functionality that don't need a running server or a complete configuration.
* *QA tests* in ``qatest/``: tests that need a running server or a more complete configuration.

Running tests
#############

There are several methods to run all tests:

Using Docker
------------

This method has minimal requirements for your host system.

*Prerequisites: Docker*

::

    # assuming you are in the projects' root directory:
    ./tools/docker-test.pl --all

The script builds the Docker image locally which takes a while on first run.

Please note that this will only run tests on a MariaDB database. If you want to
test Oracle connectivity, please use the Vagrant method below.

Using Vagrant
-------------

This method creates a complete interactive test environment inside a Virtualbox
VM (i.e. "Vagrant Box").

*Prerequisites: Virtualbox, Vagrant, Oracle XE 11.2 setup*

**Once**

1. Download the Oracle XE 11.2 setup for Linux from
   `<https://www.oracle.com/technetwork/database/database-technologies/express-edition/downloads/xe-prior-releases-5172097.html>`_
   and place it in ``vagrant/develop/assets/oracle/docker/setup/packages/``
   (You need an Oracle login to do that).

2. Build the Vagrant box (=VM) once, which takes a long while, and start it.
   ::

       # assuming you are in the projects' root directory:
       cd vagrant/develop
       vagrant up
       # have several cups of tea...

**After code changes**

1. Start the Vagrant box and log in
   ::

       # assuming you are in the projects' root directory:
       cd vagrant/develop
       vagrant up && vagrant ssh

2. Refresh the code

   To make sure all dependencies inside the VM are in sync with the files on
   your host (e.g. after code changes), refresh them inside Vagrant::

       sudo su
       oxi-refresh
       # maybe start with a clean DB: oxi-initdb

3. Run the tests
   ::

       docker start mariadb
       docker start oracle
       cd /code-repo

       cd core/server
       PERL5LIB=./ prove -r t
       cd ../..

       cd qatest
       PERL5LIB=./ prove -r backend/nice backend/api backend/api2 backend/webui client
       cd ..

Using a local dev environment
-----------------------------

*Prerequisites: Database, Linux packages etc.*

**Once**

Set up a running OpenXPKI instance as described in :ref:`quickstart`.
Please note that the tests currently use the database that is configured in ``/etc/openxpki/config.d``.

**After code changes**

1. Update required Perl according to current Makefile
   ::

      # assuming you are in the projects' root directory:
      cpanm Carton
      ./tools/scripts/makefile2cpanfile.pl > cpanfile
      carton install

2. Run the tests
   ::

      # assuming you are in the projects' root directory:
      cd core/server
      prove -I ../../local/lib/perl5 -r t
      cd ../..

      cd qatest
      prove -I ../local/lib/perl5 -I ../core/server -r backend/nice backend/api backend/api2 backend/webui client
      cd ..

Automatically via Travis-CI
---------------------------

Whenever a new commit of the code is pushed onto Github, a Travis-CI test run
is triggered that runs all of the active tests.

You can find the results at `<https://travis-ci.org/openxpki/openxpki>`_.

For more details see ``.travis.yml`` in the projects' root directory.

Writing tests
#############

Tests are important and we are glad if you want to contribute a test, e.g. for a
bug you have found or a new/untested feature!

OpenXPKI itself is quite complex. That is why there is a bunch of Perl classes
that help minimizing the boilerplate code you have to write in each test. They
also do some of the tricky setup in the background so you should be able to
concentrate on the test logic.

Please have a look at the documentation of ``OpenXPKI::Test`` to start and
understand how the test class(es) work.

Please note that there are still old tests around which do not use the new test
class. They will be migrated over time.

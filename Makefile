# Makefile
#
# This makefile is an entry point for continuous integration testing systems.
# It's oriented towards Travis-CI, but is certainly adaptable to other build
# and test systems.
#
# For normal package builds, see the documentation.
#
# NOTE: The test targets make some general assumptions on the build/test
# environment. Among these assumptions are:
#
# - perlbrew is used for a local perl installation
# - cpanm is used for CPAN prerequisites

# Ubuntu uses dash, which sucks when using '.' to source an RC file.
SHELL=/bin/bash

TESTLOGDIR=logs
TESTLOG=$(TESTLOGDIR)/test-$(shell date "+%Y-%m-%d-%H%M").log

default:
	@echo
	@echo "Sorry, but this Makefile is for continuous integration testing."
	@echo "For normal package build, see the documentation."

PERLBREW_RC := $(HOME)/perl5/perlbrew/etc/bashrc
PERLBREW_STABLE := 5.14.2
CPANM_INST := cpanm --installdeps --notest --verbose --no-interactive .

# Travis-CI provides perlbrew already, but this target may be used on other
# systems to get perlbrew installed.
perlbrew:
	curl -kL http://install.perlbrew.pl | bash
	. $(PERLBREW_RC) && perlbrew install $(PERLBREW_STABLE)
	. $(PERLBREW_RC) && perlbrew use $(PERLBREW_STABLE)
	. $(PERLBREW_RC) && perl --version
	. $(PERLBREW_RC) && perlbrew install-cpanm

# Install the packages needed for building CPAN prereqs, etc.
# Note: Travis-CI does this already in the before_install target.
inst-pkgs:
	sudo apt-get update -qq
	sudo apt-get install -qq libxml expat-dev openssl-dev

# Travis-CI will call the command 'cpanm --installdeps --notest .' to update
# the build prereqs for the project. This 'cpanm' target may be used on other
# systems to install the dependencies. Note: it sources the perlbrew bashrc
# just in case perlbrew was installed using the above target and is not 
# in the current user environment.
#
# The cpanm.err file allows us to run all tasks and report a single error if
# any failed
#
# Note: Config::Std is a prereq for running 'perl Makefile.PL'
cpanm:
	. $(PERLBREW_RC) && cpanm --installdeps --notest --verbose --no-interactive Class::Std Config::Std
	. $(PERLBREW_RC) && cd core/server && $(CPANM_INST) 

.PHONY: clean-core
clean-core:
	(cd core/server && \
		rm -rf Makefile OpenXPKI.bs OpenXPKI.c OpenXPKI.o blib pm_to_blib \
	)

# Travis-CI uses 'make test' as a generic entry point for Perl projects when
# it can't find Build.PL or Makefile.PL. This seems like a good spot for us
# to be called. So, 'yes', this is where Travis-CI actually starts the tests.
test: clean-core
	mkdir -p $(TESTLOGDIR)
	rm -f test.err
	. $(PERLBREW_RC) && \
		(cd core/server && perl Makefile.PL && make test) || touch test.err 2>&1 | \
		tee $(TESTLOG)
	! test -f test.err

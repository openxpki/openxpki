# trunk/tests/Makefile
#
# Makefile for running the tests that use the installed OpenXPKI
#
# IMPORTANT: These tests are run against a running OpenXPKI installation.
# Override the configuration files to adjust to your environment. The defaults
# are intended to work with the reference installation, but this may not be
# completely implemented for all tests yet.
#
#

MODULES := backend selenium

# each module will add its own targets to these
TESTS :=
TESTS_BACKEND :=
TESTS_SELENIUM :=

# include the description for each module
include $(patsubst %,%/module.mk,$(MODULES))

.PHONY: all tests dtests be-tests be-dtests sel-tests sel-dtests

PROVE_ARGS := -Ilib

all:
	@echo " "
	@echo "The following pseudo-targets are supported: "
	@echo " "
	@echo "	tests   Run all tests *"
	@echo "	dtests  Run all destructive tests *"
	@echo " "
	@echo "	be-tests   Run all backend tests"
	@echo "	be-dtests  Run all destructive backend tests"
	@echo " "
	@echo "	sel-tests   Run all selenium tests *"
	@echo "	sel-dtests  Run all destructive selenium tests *"
	@echo " "
	@echo " * requires running Selenium Server"

list:
	@echo "Tests:"
	@echo $(TESTS) | sort | xargs -n 1 echo "	" 


tests: $(TESTS)
	prove $(PROVE_ARGS) $(TESTS)

# destructive tests
dtests: $(TESTS)
	DESTRUCTIVE_TESTS=1 prove $(PROVE_ARGS) $(TESTS)

be-tests: $(TESTS_BACKEND)
	prove $(PROVE_ARGS) $(TESTS_BACKEND)

# destructive tests
be-dtests: $(TESTS_BACKEND)
	DESTRUCTIVE_TESTS=1 prove $(PROVE_ARGS) $(TESTS_BACKEND)

sel-tests: $(TESTS_SELENIUM)
	prove $(PROVE_ARGS) $(TESTS_SELENIUM)

# destructive tests
sel-dtests: $(TESTS_SELENIUM)
	DESTRUCTIVE_TESTS=1 prove $(PROVE_ARGS) $(TESTS_SELENIUM)


# Individual tests used during development of the tests themselves
-include Makefile.post.local


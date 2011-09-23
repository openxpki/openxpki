# trunk/perl-modules/core/trunk/t/Tests.mk
#
# Makefile for running the basic core tests that do not
# require an OpenXPKI installation (i.e.: "git clone ... && cd ... && make -f tests.mk")
#
#

# each module will add to these
TESTS :=

# include the description for each module
include */module.mk

.PHONY: all tests list

PROVE_ARGS := -I.. -Ilib

help:
	@echo " "
	@echo "The following pseudo-targets are supported: "
	@echo " "
	@echo " tests   Run all tests (default)"
	@echo " list	Lists the tests found by the make files"
	@echo " "

tests: $(TESTS)
	prove $(PROVE_ARGS) $(TESTS)

list:
	@echo "$(TESTS)" | perl -pe 's/^ +//; s/  / /g; s/ /\n/g'


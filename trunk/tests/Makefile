# trunk/tests/Makefile
#
# Makefile for running the tests that use the installed OpenXPKI
#
#

MODULES := smartcard

# each module will add to this 
TESTS :=

# include the description for each module
include $(patsubst %,%/module.mk,$(MODULES))

.PHONY: tests dtests cardadm


tests: $(TESTS)
	prove $(TESTS)

# destructive tests
dtests: $(TESTS)
	DESTRUCTIVE_TESTS=1 prove $(TESTS)

cardadm: 
	DESTRUCTIVE_TESTS=1 perl smartcard/01_cardadm.t

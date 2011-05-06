# backend/module.mk
#
# This module file is responsible for including the individual backend test
# modules.
#
# The individual sub-modules should populate TESTS_BACKEND

# Add each full sub-module directory here
MODULES_BACKEND := backend/smartcard

# include the description for each sub-module
include $(patsubst %,%/module.mk,$(MODULES_BACKEND))

# add the sub-module tests found to the full list of tests
TESTS += $(TESTS_BACKEND)

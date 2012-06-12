# backend/module.mk
#
# This module file is responsible for including the individual backend test
# modules.
#
# The individual sub-modules should populate TESTS_BACKEND

# Add each full sub-module directory here
MODULES_BACKEND := backend/workflow backend/smartcard

# For local modules, create module.mk.local and add additional
# MODULES_BACKEND entries as shown above
-include module.mk.local

# include the description for each sub-module
include $(patsubst %,%/module.mk,$(MODULES_BACKEND))

# add the sub-module tests found to the full list of tests
TESTS += $(TESTS_BACKEND)



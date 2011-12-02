# selenium/module.mk
#
# This module file is responsible for including the individual Selenium test
# modules.
#
# The individual sub-modules should populate TESTS_SELENIUM

# Add each full sub-module directory here
MODULES_SELENIUM := 

# For local modules, create module.mk.local and add additional
# MODULES_BACKEND entries as shown above
-include module.mk.local

# include the description for each sub-module
include $(patsubst %,%/module.mk,$(MODULES_SELENIUM))

# add the sub-module tests found to the full list of tests
TESTS += $(TESTS_SELENIUM)

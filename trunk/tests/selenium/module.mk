# selenium/module.mk
#
# This module file is responsible for including the individual Selenium test
# modules.
#
# The individual sub-modules should populate TESTS_SELENIUM

# Add each full sub-module directory here
MODULES_SELENIUM := selenium/smartcard

# include the description for each sub-module
include $(patsubst %,%/module.mk,$(MODULES_SELENIUM))

# add the sub-module tests found to the full list of tests
TESTS += $(TESTS_SELENIUM)

# 12_config/module.mk
#
# This module file is responsible for including the individual 12_config test
# modules.
#

# add the sub-module tests found to the full list of tests
TESTS += $(wildcard 12_config/*.t)

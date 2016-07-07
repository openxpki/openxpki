## Written 2016 by Scott Hardin for the OpenXPKI project
## Copyright (C) 2016 by The OpenXPKI Project
#
# This does some basic checking on the vergen command and then
# sets VERGEN to be called by PERL. This is needed to make 
# handling the system perl vs. myperl package builds.

# NOTE: a Makefile including this snippet MUST set the variable TOPDIR
# correctly, such as:
# TOPDIR := ../..

ifndef TOPDIR
$(error Makefile must set TOPDIR must be set to the top level directory of the repository (using relative notation))
endif

VERGEN := $(TOPDIR)/tools/vergen
PERL   := $(shell which perl)

# test if vergen is found and executable
ifneq (EXISTS, $(shell test -x $(VERGEN) && echo "EXISTS"))
$(error Command 'vergen' not found at $(VERGEN). Hint: does TOPDIR really point to the top of this repository?)
endif

# After testing that VERGEN works, we prepend it with the PERL command
VERGEN := $(PERL) $(VERGEN)


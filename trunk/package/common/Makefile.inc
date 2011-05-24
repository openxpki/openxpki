## Written 2011 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2011 by The OpenXPKI Project

# Common definitions for all package Makefiles
# This include will allow you to automatically process files with
# the extension .template via tpage (Template Toolkit required).
# The implicit rule defined here will generate a file with the basename of
# the template file.

# NOTE: a Makefile including this snippet MUST set the variable TOPDIR
# correctly, such as:
# TOPDIR := ../../..

ifndef TOPDIR
$(error Makefile must set TOPDIR must be set to the top level directory of the repository (using relative notation))
endif

VERGEN := $(TOPDIR)/tools/vergen
PERL   := $(shell which perl)

# test if vergen is found and executable
ifneq (EXISTS, $(shell test -x $(VERGEN) && echo "EXISTS"))
$(error Command 'vergen' not found at $(VERGEN). Hint: does TOPDIR really point to the top of this repository?)
endif 

# all vergen symbols in tpage(1) compatible format
TT_VERSION_SYMBOLS := $(shell \
	$(VERGEN) --dump --dumpformat "--define KEYWORD=\"VALUE\" " 2>/dev/null ; \
	for i in `$(VERGEN) --list-formats` ; do value=`$(VERGEN) --format $$i 2>/dev/null` ; [ -n "$$value" ] && echo "--define $$i=\"$$value\"" ; done \
)

.SUFFIXES: .template

# This implicit rule allows package builds to use version specific
# variables in package manifest templates.
# To use this you need to do the following:
# Assuming you want to generate the file FILE containing version information
# (which would then be used as an input file for the package build script)
# you create a file FILE.template which uses Template::Toolkit syntax inside.
# The following Template::Toolkit variables are available and extended
# according the the currently checked out source:
#
# The following variables are only available if run from a git repository:
# GIT_COMMIT_HASH
#   - contains the full git commit hash of the checkout
# GIT_ABBREVIATED_COMMIT_HASH
#   - abbreviated git commit hash of the checkout
# GIT_TAG
#   - if a git tag is set for this commit the variable contains the git tag,
#     if multiple tags are set for this commit it will contain only the first
#     tag
# GIT_TAGS
#   - contains all tags for this commit (comma separated)
# GIT_BRANCH
#   - current git branch
# GIT_FILTERED_BRANCH
#   - empty if on default branch (see .VERSION_DEFINITION), otherwise branch
#     name with unsafe characters replaced by underscore
# GIT_DESCRIPTION
#   - contains the git description for this commit
#
# The following variables follow the Subversion revision
# SVN_REVISION
#   - contains the Subversion revision of the checkout
# SVN_LAST_CHANGED_REVISION
#   - Subversion last changed revision
# 
# MAJOR
#   - Major product version (administratively set)
# MINOR
#   - Minor product version (administratively set)
# RELEASE
#   - Product release (currently identical to SVN_REVISION)
# PKGREL
#   - package release number
# SUFFIX
#   - Build specific suffix (administratively set)
#
# The following variables are custom variables (composed of components
# mentioned above)
# git_commit
#   - custom version number, format example: 0.9.1548-2b97f78
# daily_snapshot
#   - custom version number, format example: 2011-02-01-0.9.1548
# version
#   - custom version number, format example: 0.9.1548
#
# In calling Makefiles you can set TT_EXTRA_SYMBOLS to set additional
# template variables.
# 
%:: %.template
	cat $< | tpage $(TT_VERSION_SYMBOLS) $(TT_EXTRA_SYMBOLS) >$@


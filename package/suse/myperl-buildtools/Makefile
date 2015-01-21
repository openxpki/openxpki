## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2011 by The OpenXPKI Project

TOPDIR=../../..

PERL_VERSION=5.20.1
MYPERL_RELEASE=1

PACKAGE=myperl-buildtools
SRCNAME=myperl-buildtools

# Makefile.inc contains common settings for all packages (checked in)
#include ../Makefile.inc

PERL := $(shell which perl)

ifndef GIT_AUTHOR_NAME
	GIT_AUTHOR_NAME := $(shell git config --get user.name)
endif
ifndef GIT_AUTHOR_EMAIL
	GIT_AUTHOR_EMAIL := $(shell git config --get user.email)
endif
PACKAGER := $(strip $(GIT_AUTHOR_NAME) <$(GIT_AUTHOR_EMAIL)>)

TT_VERSION_SYMBOLS = --define version="$(PERL_VERSION)" --define PKGREL=$(MYPERL_RELEASE) --define PACKAGER="$(PACKAGER)"
.SUFFIXES: .template

# For documentation in this implicit rule, see ../../common/Makefile.inc
%:: %.template
	cat $< | tpage $(TT_VERSION_SYMBOLS) $(TT_EXTRA_SYMBOLS) >$@.new
	mv $@.new $@

# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local

all: clean package

#all: clean perl-dist package collect

dist-clean:
#	( cd $(SRCBASE) && \
#		rm -f *.tar.gz \
#	)


perl-dist: dist-clean
#	cd $(SRCBASE) && perl Makefile.PL
#	cd $(SRCBASE) && make dist
#	mkdir -p $(RPMBASE)/SOURCES
#	ls -l $(SRCBASE)/*.tar.gz
#	mv $(SRCBASE)/*.tar.gz $(RPMBASE)/SOURCES

$(PACKAGE).spec: $(PACKAGE).spec.template

package: $(PACKAGE).spec
	PERL_LOCAL_LIB_ROOT= PERL_MB_OPT= PERL_MM_OPT= rpmbuild -ba $(PACKAGE).spec

collect:
	mv $(RPMBASE)/SRPMS/$(PACKAGE)-*.rpm .
	mv $(RPMBASE)/RPMS/*/$(PACKAGE)-*.rpm .

clean:
	rm -f $(PACKAGE)-*.rpm $(PACKAGE).spec

#####
# TODO: Move the following targets to a common makefile
#####

#TT_VERSION_SYMBOLS = \
#					 --define PERL_VERSION="$(PERL_VERSION)" \
#					 --define MYPERL_RELEASE="$(MYPERL_RELEASE)"
#
#.SUFFIXES: .template
#
#%:: %.template
#	cat $< | tpage $(TT_VERSION_SYMBOLS) $(TT_EXTRA_SYMBOLS) >$@



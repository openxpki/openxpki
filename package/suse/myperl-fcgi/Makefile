## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2011 by The OpenXPKI Project

TOPDIR=../../..

PERL_VERSION=5.20.0
MYPERL_RELEASE=3

PACKAGE=myperl-fcgi
#SRCBASE=$(TOPDIR)/clients/perl/OpenXPKI-Client-Enrollment
SRCNAME=myperl-fcgi

# Makefile.inc contains common settings for all packages (checked in)
include ../Makefile.inc
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



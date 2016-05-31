## Written 2014 by Scott Hardin for the OpenXPKI project
## Copyright (C) 2014 by The OpenXPKI Project

TOPDIR=../../..

PERL_VERSION=5.20.0
MYPERL_RELEASE=1
OXI_VERSION = $(shell ../../../tools/vergen --format version)

PACKAGE=myperl-openxpki-core-deps
#SRCBASE=$(TOPDIR)/clients/perl/OpenXPKI-Client-Enrollment
SRCNAME=$(PACKAGE)

OXI_TARBALL = $(shell rpm --eval '%{_topdir}')/SOURCES/$(PACKAGE)-$(OXI_VERSION).tar.gz
OXI_TARBALL_DIR = $(shell rpm --eval '%{_topdir}')/BUILD/tmp/$(PACKAGE)-$(OXI_VERSION)

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

tarball: $(OXI_TARBALL)

package: $(PACKAGE).spec $(OXI_TARBALL)
	PERL_LOCAL_LIB_ROOT= PERL_MB_OPT= PERL_MM_OPT= rpmbuild -ba $(PACKAGE).spec

collect:
	mv $(RPMBASE)/SRPMS/$(PACKAGE)-*.rpm .
	mv $(RPMBASE)/RPMS/*/$(PACKAGE)-*.rpm .

clean:
	rm -f $(PACKAGE)-*.rpm $(PACKAGE).spec $(OXI_TARBALL)

$(OXI_TARBALL):
	rm -rf $(OXI_TARBALL_DIR)
	mkdir -p $(OXI_TARBALL_DIR)
	(cd ../../.. && tar cf - \
		ISSUES LICENSE README* clients config core doc package qatest tools) \
		| tar xf - -C $(OXI_TARBALL_DIR)
	echo $(OXI_VERSION) > $(OXI_TARBALL_DIR)/VERSION
	tar czf $@ -C $(OXI_TARBALL_DIR)/.. .
	
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



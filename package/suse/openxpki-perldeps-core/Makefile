## Written 2013 by Scott Hardin for the OpenXPKI project
## Copyright (C) 2013 by The OpenXPKI Project
#
# Usage Notes:
#
# To enable mirror/cache of Perl and CPAN, set MIRROR_DIR to the directory
# that has the following structure:
#
# 	perl/perl-5.16.3.tar.bz2
# 	cpan/<cpan mirror tree>
#
#	MIRROR_DIR = /mirrors
#
# If you need additional CPAN modules in addition to the prereqs from
# core/server/Makefile.PL, just set the variable CPAN_ADDON in your
# Makefile.local

TOPDIR=../../..

ifndef SRCNAME
SRCNAME				= core
endif
PACKAGE				= openxpki-perldeps-$(SRCNAME)
PERLNAME			= $(PACKAGE)
ifndef SRCBASE
SRCBASE				:= $(TOPDIR)/core/server
endif

RPMBUILD_DIR		= $(HOME)/rpmbuild
RPM_SOURCE_TARBALL	= $(RPMBUILD_DIR)/SOURCES/$(PACKAGE).tar.gz

# Makefile.inc contains common settings for all packages (checked in)
include ../Makefile.inc
# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local
-include Makefile.local

VERGEN := $(TOPDIR)/tools/vergen

VERSION = $(shell $(VERGEN) --format version)
PKGREL = $(shell $(VERGEN) --format PKGREL)

PERL_ROOT=/usr/share/$(PERLNAME)
PERL_VERSION=5.18.2
PERL_5_BASEURL=http://ftp.gwdg.de/pub/languages/perl/CPAN/src/5.0
PERL_SOURCE_TARBALL=perl-$(PERL_VERSION).tar.bz2
PERL_SOURCE_URL=$(PERL_5_BASEURL)/$(PERL_SOURCE_TARBALL)
PERL_SOURCE_PREFIX=/tmp/$(PERLNAME)-$(VERSION)
# Note: use 'PERL_SOURCE_PREFIX' as the dirname because it is 
# created in one of the target commands.
PERL_SOURCE_TARBALL_LONG=$(PERL_SOURCE_PREFIX)/$(PERL_SOURCE_TARBALL)
PERL_SOURCE_DIR=$(PERL_SOURCE_PREFIX)/perl-$(PERL_VERSION)
PERL_OWNER_USER=$(shell id -un)
PERL_OWNER_GROUP=$(shell id -gn)
NEW_PERL_BIN=$(PERL_ROOT)/$(PERL_VERSION)/bin
NEWPERL=$(NEW_PERL_BIN)/perl
NEWCPANM=$(NEW_PERL_BIN)/cpanm
PREFIX=/usr
RPM_ARCH = x86_64

ifdef MIRROR_DIR
 	CPANM_OPTS = --save-dists $(MIRROR_DIR)/cpan --mirror $(MIRROR_DIR)/cpan --mirror http://www.cpan.org/ 
endif

# Setting $(PERL_SKIP_TEST) will cause 'make test' to be
# skipped. This should only be used when running the
# build repeatedly to refine other components of the process.
ifdef PERL_SKIP_TEST
  PERL_MAKE_TARGETS = all install
else
  PERL_MAKE_TARGETS = all test install
endif

########## TARGET NAMES

RPM_SPECFILE = $(PACKAGE).spec
RPM_FILE = $(RPMBUILD_DIR)/RPMS/$(RPM_ARCH)/$(PACKAGE)-$(VERSION)-$(PKGREL).$(RPM_ARCH).rpm

########## TARGETS


.PHONY: all
all: default-check default-nocheck

.PHONY: info
info:
	@echo "Perl binary:  $(NEWPERL)"
	@echo "cpan file:    $(NEWCPANM)"
	@echo "Tarball file: $(PERL_SOURCE_TARBALL_LONG)"
	@echo "PACKAGE:      $(PACKAGE)"

.PHONY: pkginfo
pkginfo: $(RPM_FILE)
	rpm -qip $(RPM_FILE)

ifdef PREFIX
CONFIGURE_ARGS=--prefix $(PREFIX)
endif

# propagate additional template variables for spec template processing
TT_EXTRA_SYMBOLS = --define CONFIGURE_ARGS="$(CONFIGURE_ARGS)" --define PREFIX="$(PREFIX)"

# Sanity checks for this tree
# 1. check for required command line tools
# 2. ensure that some perl vars have *not* been set
.PHONY: check
check:
	@for cmd in $(VERGEN) tpage ; do \
		if ! $$cmd </dev/null >/dev/null 2>&1 ; then \
			echo "ERROR: executable '$$cmd' does not work properly." ;\
			exit 1 ;\
		fi ;\
	 done
	@if test -n "$$PERL_LOCAL_LIB_ROOT"; then \
		echo "ERROR: var PERL_LOCAL_LIB must not be set" 1>&2; exit 1; \
	fi
	@if test -n "$$PERL_MB_OPT"; then \
		echo "ERROR: var PERL_MB_OPT must not be set" 1>&2; exit 1; \
	fi
	@if test -n "$$PERL_MM_OPT"; then \
		echo "ERROR: var PERL_MM_OPT must not be set" 1>&2; exit 1; \
	fi
	@if test -n "$$PERL5LIB"; then \
		echo "ERROR: var PERL5LIB must not be set" 1>&2; exit 1; \
	fi


# checks to be done before running an rpmbuild command
default-check: check
	@test ! -d $(NEW_PERL_BIN) || (echo "$(NEW_PERL_BIN) already exists"; exit 1)

# Through the makefile dependencies, this rule does the following:
#   - donloads the perl tarball
#   - builds it in the /tmp root
#   - installs cpanm
#   - installs remaining cpan deps
#   - creates tarball of the /tmp root directory
default-nocheck: $(NEWPERL) $(NEWCPANM) $(PERL_ROOT)/.build-cpan $(RPM_SOURCE0_TARBALL) $(RPM_FILE)

default-nocheck-deprecated:
	$(MAKE) package
	$(MAKE) changelog
	$(MAKE) /tmp/openxpki-debian.tar.gz
	$(MAKE) source
	$(MAKE) package


dist-clean:
	( cd $(SRCBASE) && \
		rm -f *.tar.gz \
	)


dist: dist-clean
	( cd $(SRCBASE)/ && \
		./configure --distonly && \
		make dist && \
		mv *.tar.gz $(RPMBASE)/SOURCES \
	)
	tar czf $(RPMBASE)/SOURCES/openxpki-deployment-susefiles.tar.gz etc/

$(RPM_SPECFILE): $(RPM_SPECFILE).template

package: $(RPM_FILE)

$(RPM_FILE): $(RPM_SPECFILE) $(RPM_SOURCE_TARBALL)
	rpmbuild -ba $(PACKAGE).spec

collect:
	mv $(RPMBASE)/SRPMS/$(PACKAGE)-*.rpm .
	mv $(RPMBASE)/RPMS/*/$(PACKAGE)-*.rpm .

clean:
	rm -f $(PACKAGE)-*.rpm \
		$(PACKAGE).spec \
		$(RPM_SOURCE_TARBALL)
	

realclean: clean
	echo -n "Delete '$(PERL_ROOT)'? " && read && sudo rm -rf "$(PERL_ROOT)"

$(PERL_SOURCE_PREFIX):
	mkdir -p $@

# Note: the copy from '/vagrant' is optional and allows for a local copy
$(PERL_SOURCE_TARBALL_LONG): $(PERL_SOURCE_PREFIX)
	cp /mirrors/perl/$(PERL_SOURCE_TARBALL) $@ || echo "Need to fetch tarball"
	test -f $@ || wget -O $@ $(PERL_SOURCE_URL)

.PHONY: build-perl
build-perl: $(NEWPERL)

$(NEWPERL): $(PERL_SOURCE_TARBALL_LONG)
	sudo mkdir -p $(PERL_SOURCE_PREFIX)
	sudo chown $(PERL_OWNER_USER):$(PERL_OWNER_GROUP) $(PERL_SOURCE_PREFIX)
	sudo mkdir -p $(PERL_ROOT)
	sudo chown $(PERL_OWNER_USER):$(PERL_OWNER_GROUP) $(PERL_ROOT)
	(cd $(PERL_SOURCE_PREFIX) && tar -xjf $(PERL_SOURCE_TARBALL_LONG))
	(cd $(PERL_SOURCE_DIR) && \
		sh Configure -des \
		-Dprefix=$(PERL_ROOT)/$(PERL_VERSION) \
		-Dscriptdir=$(PERL_ROOT)/$(PERL_VERSION)/bin)
	(cd $(PERL_SOURCE_DIR) && make $(PERL_MAKE_TARGETS))
	(cd $(PERL_ROOT) && ln -s $(PERL_VERSION) CURRENT)

.PHONY: build-cpan-cpanm
build-cpan-cpanm: $(NEWCPANM)

$(NEWCPANM): $(NEWPERL)
	curl -L http://cpanmin.us | $(NEWPERL) - --self-upgrade

# Install CPAN modoules in two steps -- the first takes care of dependencies
# needed to run Makefile.PL
.PHONY: build-cpan
build-cpan: $(PERL_ROOT)/.build-cpan
$(PERL_ROOT)/.build-cpan: $(NEWCPANM)
	PATH=$(NEW_PERL_BIN):$(PATH) $(NEWCPANM) $(CPANM_OPTS) --quiet --notest Config::Std
	(cd $(SRCBASE) && PATH=$(NEW_PERL_BIN):$(PATH) $(NEWCPANM) $(CPANM_OPTS) --quiet --installdeps --notest .)
ifdef CPAN_ADDON
	PATH=$(NEW_PERL_BIN):$(PATH) \
		 $(NEWCPANM) $(CPANM_OPTS) \
		 --quiet --notest $(CPAN_ADDON)
endif
	touch $@

.PHONY: build-tarball
build-tarball: $(RPM_SOURCE_TARBALL)

$(RPM_SOURCE_TARBALL): $(PERL_ROOT)/.build-cpan
	tar -czf $@ $(PERL_ROOT)

/tmp/openxpki-debian.tar.gz:
	tar -czf $@ .

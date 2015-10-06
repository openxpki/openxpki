# perl-build.mk - helper targets for building our own local perl and cpan
#
# The targets and variables here should be compatible with both debian and
# suse build routines. Also, independent packages may be created for separate
# applications. For example, the OpenXPKI service and clients require the
# full perl/cpan installation. The enrollment UI, on the other hand, only
# needs a few dependencies from cpan.
#
# USAGE:
#
# 	OXI_PERL_NAME := openxpki-perldeps-core
#
# 	include ../common/perl-build.mk
#
# 	# distro-specific targets
# 	...
#
#

TOPDIR := ../../..
VERGEN := $(TOPDIR)/tools/vergen

ifndef OXI_PERL_NAME
	OXI_PERL_NAME := openxpki-perldep
endif
ifndef OXI_VERSION
	OXI_VERSION := $(shell $(VERGEN) --format version)
endif
ifndef PKGREL
	OXI_PKGREL  := $(shell $(VERGEN) --format PKGREL)
endif

ifndef PKGDIR
	$(error Variable PKGDIR not set)
endif

# Setting $(PERL_SKIP_TEST) will cause 'make test' to be
# skipped. This should only be used when running the
# build repeatedly to refine other components of the process.
ifdef PERL_SKIP_TEST
  PERL_MAKE_TARGETS = install
else
  PERL_MAKE_TARGETS = test install
endif

# Setting $(CPAN_MIRROR_DIR) will cause cpanm to cache the
# tarballs fetched from CPAN.
ifdef CPAN_MIRROR_DIR
	CPANM_OPT = --cascade-search --save-dists=$(CPAN_MIRROR_DIR) \
				--mirror $(CPAN_MIRROR_DIR) --mirror=http://search.cpan.org/CPAN \
				--quiet --notest
else
	CPANM_OPT = --quiet --notest
endif

OXI_SOURCE := $(TOPDIR)/core/server
OXI_PERL_OWNER := $(shell id -un)
OXI_PERL_GROUP := $(shell id -gn)
OXI_PERL_VERSION := 5.18.2
OXI_PERL_PREFIX := /opt/openxpki
OXI_PERL_BINDIR := $(OXI_PERL_PREFIX)/bin
OXI_PERL := $(OXI_PERL_BINDIR)/perl
NEWPERL := $(OXI_PERL_BINDIR)/perl
NEWCPANM := $(OXI_PERL_BINDIR)/cpanm

#RPMBUILD_DIR := $(HOME)/rpmbuild
#SOURCE_PREFIX := $(RPMBUILD_DIR)/SOURCES
PERL_SOURCE_PREFIX = /tmp/$(OXI_PERL_NAME)-$(OXI_VERSION)-source

BUILD_PREFIX := /tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION)
BUILD_PERL := $(BUILD_PREFIX)/perl-$(OXI_PERL_VERSION)
PERL_SOURCE_TARBALL := perl-$(OXI_PERL_VERSION).tar.bz2
PERL_5_BASEURL := http://ftp.gwdg.de/pub/languages/perl/CPAN/src/5.0
PERL_SOURCE_URL := $(PERL_5_BASEURL)/$(PERL_SOURCE_TARBALL)

# Note: use 'PERL_SOURCE_PREFIX' as the dirname because it is 
# created in one of the target commands.
PERL_SOURCE_TARBALL_LONG=$(PERL_SOURCE_PREFIX)/$(PERL_SOURCE_TARBALL)



.PHONY: all
all: check build-cpan default

.PHONY: info
info:
	@echo " PERL_SOURCE_PREFIX = $(PERL_SOURCE_PREFIX)"
	@echo "PERL_SOURCE_TARBALL = $(PERL_SOURCE_TARBALL)"
	@echo "    OXI_PERL_PREFIX = $(OXI_PERL_PREFIX)"
	@echo "   OXI_PERL_VERSION = $(OXI_PERL_VERSION)"
	@echo "          NEWCPANM = $(NEWCPANM)"
	@echo "            NEWPERL = $(NEWPERL)"

.PHONY: nocheck
nocheck:

# Sanity checks for this tree
# 1. check for required command line tools
.PHONY: check
check:
	@for cmd in $(VERGEN) tpage ; do \
		if ! $$cmd </dev/null >/dev/null 2>&1 ; then \
			echo "ERROR: executable '$$cmd' does not work properly." ;\
			exit 1 ;\
		fi ;\
	 done

#$(PERL_SOURCE_PREFIX):
#	mkdir -p $@

.PHONY: fetch-perl
fetch-perl: $(PERL_SOURCE_TARBALL_LONG)

# Fetch tarball from perl.org
.SECONDARY: $(PERL_SOURCE_TARBALL_LONG)
$(PERL_SOURCE_TARBALL_LONG):
	mkdir -p $(PERL_SOURCE_PREFIX)
	cp /vagrant/$(PERL_SOURCE_TARBALL) $@ || echo "Need to fetch tarball"
	test -f $@ || wget -O $@ $(PERL_SOURCE_URL)

.PHONY: build-perl
build-perl: $(NEWPERL)

# Install new oxi perl
$(NEWPERL): $(PERL_SOURCE_TARBALL_LONG)
	sudo mkdir -p $(BUILD_PREFIX)
	sudo chown $(OXI_PERL_OWNER):$(OXI_PERL_GROUP) $(BUILD_PREFIX)
	sudo mkdir -p $(OXI_PERL_PREFIX)
	sudo chown $(OXI_PERL_OWNER):$(OXI_PERL_GROUP) $(OXI_PERL_PREFIX)
	cd $(BUILD_PREFIX) && tar -xjf $(PERL_SOURCE_TARBALL_LONG)
	cd $(BUILD_PERL) && \
		sh Configure -des \
		-Dprefix=$(OXI_PERL_PREFIX)
	cd $(BUILD_PERL) && PERL5LIB= make $(PERL_MAKE_TARGETS)
#	(cd $(OXI_PERL_PREFIX) && ln -s $(OXI_PERL_VERSION) CURRENT)

.PHONY: build-cpan-cpanm
build-cpan-cpanm: $(NEWCPANM)

# Install 'cpanm' using new oxi perl
$(NEWCPANM): $(OXI_PERL)
	curl -L http://cpanmin.us | PERL5LIB= $(OXI_PERL) - --self-upgrade

# Install CPAN modoules in three steps:
# 1. take care of dependencies needed to run Makefile.PL
# 2. manually install any dependencies not resolved automatically in step 3
# 3. install remaining deps for oxi
.PHONY: build-cpan
build-cpan: $(OXI_PERL_PREFIX)/.build-cpan
$(OXI_PERL_PREFIX)/.build-cpan: $(NEWCPANM)
	PATH=$(OXI_PERL_BINDIR):$(PATH) $(NEWCPANM) $(CPANM_OPT) Config::Std
	(cd $(OXI_SOURCE) && PATH=$(OXI_PERL_BINDIR):$(PATH) $(NEWCPANM) $(CPANM_OPT) --installdeps .)
	touch $@

.PHONY: perldeps-tarball
perldeps-tarball: /tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION).tar.gz

# This is the tarball that the debian packaging considers the "source" 
/tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION).tar.gz: $(OXI_PERL_PREFIX)/.build-cpan
	tar -czf $@ $(OXI_PERL_PREFIX)

# This is the tarball containing the debian package control files
/tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION)-debian.tar.gz:
	tar -czf $@ .

.PHONY: source
source: /tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION)-debian.tar.gz
	mkdir -p /tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION)
	cd /tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION); \
		tar cf - $(OXI_PERL_PREFIX) | tar xf -
	mkdir -p /tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION)/debian && \
		cd /tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION)/debian && \
		tar -xzf /tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION)-debian.tar.gz

.PHONY: package
package:
	cd /tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION); \
		fakeroot dpkg-buildpackage || echo "ignoring error -- usually signing ..."
	test -d $(PKGDIR) || mkdir $(PKGDIR)
	mv /tmp/$(PACKAGE)_* $(PKGDIR)/

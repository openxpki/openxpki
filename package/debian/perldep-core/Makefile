# trunk/package/debian/core
#
# This builds our own Perl binary and CPAN modules in /usr/share/openxpki
# for use by the OpenXPKI components. The Makefile is written to be
# run on a 'clean' system -- one where the /usr/share/openxpki-perldep-<oxiversion>
# doesn't exist.
#
# To prevent clobbering an existing install or accidentally
# packaging things not installed by this script, the 'default' target
# checks that the above directory does NOT exist. To skip this check,
# use the target 'nocheck' instead.

TOPDIR=../../..
VERGEN = $(TOPDIR)/tools/vergen

SRCBASE=$(TOPDIR)/perl
PACKAGE=openxpki-perldep-core
OXI_PERL_NAME := openxpki-perldep-core
PERL_NAME=OpenXPKI-perldep
PKGDIR=../deb/perldep-core

OXI_PERL_NAME = openxpki-perldep-core
OXI_PERL_VERSION = $(shell $(VERGEN) --format version)
#OXI_GIT_COMMIT = $(shell $(VERGEN) --format git_commit)

#EXAMPLE=$(TOPDIR)/perl/config

#include ../../common/perl-build.mk

# Makefile.inc contains common settings for all packages (checked in)
include $(TOPDIR)/package/common/Makefile.inc
# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local

OXI_TARBALL = $(OXI_PERL_NAME)-$(OXI_PERL_VERSION).tar.gz
UPSTREAM_TARBALL = $(OXI_PERL_NAME)_$(OXI_PERL_VERSION).orig.tar.gz
DEBIAN_TARBALL = $(OXI_PERL_NAME)_$(OXI_PERL_VERSION).debian.tar.gz
#DEBIAN_PACKAGE = $(OXI_PERL_NAME)_$(OXI_GIT_COMMIT)_$(shell dpkg --print-architecture).deb

#include ../Makefile.inc

#PERL_ROOT=/usr/share/openxpki
#PERL_VERSION=5.14.2
#PERL_5_BASEURL=http://ftp.gwdg.de/pub/languages/perl/CPAN/src/5.0
#PERL_SOURCE_TARBALL=perl-$(PERL_VERSION).tar.bz2
#PERL_SOURCE_TARBALL_LONG=$(PERL_SOURCE_PREFIX)/$(PERL_SOURCE_TARBALL)
#PERL_SOURCE_URL=$(PERL_5_BASEURL)/$(PERL_SOURCE_TARBALL)
#PERL_SOURCE_PREFIX=/tmp/$(PERLNAME)-$(PERL_VERSION)
#PERL_SOURCE_DIR=$(PERL_SOURCE_PREFIX)/perl-$(PERL_VERSION)
#PERL_OWNER_USER=$(shell id -un)
#PERL_OWNER_GROUP=$(shell id -gn)
#NEW_PERL_BIN=$(PERL_ROOT)/$(PERL_VERSION)/bin
#NEWPERL=$(NEW_PERL_BIN)/perl
#NEWCPANM=$(NEW_PERL_BIN)/cpanm

#.PHONY: info
#info:
#	@echo "Perl binary:  $(NEWPERL)"
#	@echo "cpanm file:   $(NEWCPANM)"
#	@echo "Tarball file: $(PERL_SOURCE_TARBALL_LONG)"

# Override 'default' from ../Makefile.inc
.PHONY: info default default-check default-nocheck
default: info default-nocheck

default-check:
	@test ! -d $(OXI_PERL) || (echo "$(OXI_PERL) already exists"; exit 1)

default-nocheck:
	$(MAKE) control
	$(MAKE) changelog
	$(MAKE) /tmp/$(UPSTREAM_TARBALL)
	$(MAKE) /tmp/$(DEBIAN_TARBALL)
	$(MAKE) source
	PERL_SKIP_TEST=$(PERL_SKIP_TEST) CPAN_MIRROR_DIR=$(CPAN_MIRROR_DIR) $(MAKE) package

control: control.template

compat:
	echo "9" > $@

source/format:
	mkdir -p $(shell dirname $@)
	echo "3.0 (quilt)" > $@

$(TOPDIR)/core/perldep/$(OXI_TARBALL):
	cd $(TOPDIR)/core/perldep && make dist

/tmp/$(UPSTREAM_TARBALL): $(TOPDIR)/core/perldep/$(OXI_TARBALL)
	cp $(TOPDIR)/core/perldep/$(OXI_TARBALL) $@

/tmp/$(DEBIAN_TARBALL): changelog compat control source/format
	tar czf $@ $^ copyright rules

source: /tmp/$(UPSTREAM_TARBALL) /tmp/$(DEBIAN_TARBALL)
	cd /tmp && tar xzf /tmp/$(UPSTREAM_TARBALL)
	mkdir -p /tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION)/debian
	cd /tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION)/debian && tar xzf /tmp/$(DEBIAN_TARBALL)

package:
	cd /tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION) && \
		debuild -e PERL_SKIP_TEST -e CPAN_MIRROR_DIR -us -uc || \
		echo ignoring error - usually signing ...
	test -d $(PKGDIR) || mkdir -p $(PKGDIR)
	mv /tmp/$(PACKAGE)_* $(PKGDIR)/

clean:
	rm -rf /tmp/$(UPSTREAM_TARBALL) /tmp/$(DEBIAN_TARBALL) \
		/tmp/$(OXI_PERL_NAME)-$(OXI_PERL_VERSION) \
		control compat source/format changelog \
		$(TOPDIR)/core/perldep/$(OXI_TARBALL)

.PHONY: info

info:
	@echo "CURDIR = $(CURDIR)"
	@echo "MAKEFILE_LIST = $(MAKEFILE_LIST)"
	@echo "PERL_SKIP_TEST = $(PERL_SKIP_TEST)"

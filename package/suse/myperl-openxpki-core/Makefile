## Written 2014 by Scott Hardin for the OpenXPKI project
## Copyright (C) 2014 by The OpenXPKI Project

TOPDIR=../../..

PERL_VERSION=5.20.0
MYPERL_RELEASE=1
OXI_VERSION = $(shell ../../../tools/vergen --format version)

PACKAGE=myperl-openxpki-core
SRCNAME=$(PACKAGE)

OXI_TARBALL = $(shell rpm --eval '%{_topdir}')/SOURCES/$(PACKAGE)-$(OXI_VERSION).tar.gz
OXI_TARBALL_DIR = $(shell rpm --eval '%{_topdir}')/BUILD/tmp/$(PACKAGE)-$(OXI_VERSION)

# Makefile.inc contains common settings for all packages (checked in)
include ../Makefile.inc
# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local

all: clean package

$(PACKAGE).spec: $(PACKAGE).spec.template

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
		ISSUES LICENSE README.pod clients config core doc package qatest tools) \
		| tar xf - -C $(OXI_TARBALL_DIR)
	echo $(OXI_VERSION) > $(OXI_TARBALL_DIR)/VERSION
	tar czf $@ -C $(OXI_TARBALL_DIR)/.. .


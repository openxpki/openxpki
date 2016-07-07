## Written 2014 by Scott Hardin for the OpenXPKI project
## Copyright (C) 2014 by The OpenXPKI Project

############################################################
# VARIABLES
############################################################

TOPDIR			:= ../../..

PACKAGE			:= myperl-openxpki-i18n
SRCBASE			:= $(TOPDIR)/core/i18n
SRCNAME			:= $(PACKAGE)

ifndef PERL_VERSION
PERL_VERSION		:= 5.20.0
endif

ifndef MYPERL_RELEASE
MYPERL_RELEASE		:= 1
endif


# Makefile.inc contains common settings for all packages (checked in)
include ../Makefile.inc
# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local

OXI_VERSION 		:= $(shell $(VERGEN) --format version)

SRC_TARBALL 		:= $(RPMBASE)/SOURCES/$(PACKAGE)-$(OXI_VERSION).tar.gz
SRC_TARBALL_DIR 	:= $(RPMBASE)/BUILD/tmp/$(PACKAGE)-$(OXI_VERSION)

############################################################
# TARGETS
############################################################

all: clean package

$(PACKAGE).spec: $(PACKAGE).spec.template

package: $(PACKAGE).spec $(SRC_TARBALL)
	PERL_LOCAL_LIB_ROOT= PERL_MB_OPT= PERL_MM_OPT= rpmbuild -ba $(PACKAGE).spec

collect:
	mv $(RPMBASE)/SRPMS/$(PACKAGE)-*.rpm .
	mv $(RPMBASE)/RPMS/*/$(PACKAGE)-*.rpm .

clean:
	rm -f $(PACKAGE)-*.rpm $(PACKAGE).spec $(OXI_TARBALL)

$(SRC_TARBALL):
	cd $(SRCBASE)/ \
		&& make scan PACKAGE=$(PACKAGE) \
		&& make dist PACKAGE=$(PACKAGE) \
		&& mv $(PACKAGE)-$(OXI_VERSION).tar.gz \
		$(RPMBASE)/SOURCES/$(notdir $(SRC_TARBALL))

#$(OXI_TARBALL):
#	rm -rf $(OXI_TARBALL_DIR)
#	mkdir -p $(OXI_TARBALL_DIR)
#	(cd ../../.. && tar cf - \
#		ISSUES LICENSE README.pod clients config core doc package qatest tools) \
#		| tar xf - -C $(OXI_TARBALL_DIR)
#	echo $(OXI_VERSION) > $(OXI_TARBALL_DIR)/VERSION
#	tar czf $@ -C $(OXI_TARBALL_DIR)/.. .

debug:
	@echo "OXI_VERSION = $(OXI_VERSION)"
	@echo "RPMBASE = $(RPMBASE)"
	@echo "SRC_TARBALL = $(SRC_TARBALL)"

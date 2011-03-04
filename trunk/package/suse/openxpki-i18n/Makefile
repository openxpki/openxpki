## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2011 by The OpenXPKI Project

TOPDIR=../../../..

PACKAGE=openxpki-i18n
SRCBASE=$(TOPDIR)/trunk/i18n
SRCNAME=i18n

# Makefile.inc contains common settings for all packages (checked in)
include ../Makefile.inc
# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local

default: clean dist package collect

dist-clean:
	( cd $(SRCBASE) && \
		rm -f *.tar.gz \
	)


dist: dist-clean
	( cd $(SRCBASE)/ && \
		make scan && \
		make dist && \
		mv *.tar.gz $(RPMBASE)/SOURCES \
	)

$(PACKAGE).spec: $(PACKAGE).spec.template

package: $(PACKAGE).spec
	rpmbuild -ba $(PACKAGE).spec

collect:
	mv $(RPMBASE)/SRPMS/$(PACKAGE)-*.rpm .
	mv $(RPMBASE)/RPMS/*/$(PACKAGE)-*.rpm .

clean:
	rm -f $(PACKAGE)-*.rpm $(PACKAGE).spec



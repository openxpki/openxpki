## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2011 by The OpenXPKI Project

TOPDIR=../../../..

PACKAGE=openxpki-deployment
SRCBASE=$(TOPDIR)/trunk/deployment
SRCNAME=deployment

# Makefile.inc contains common settings for all packages (checked in)
include ../Makefile.inc
# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local

PREFIX=/usr

ifdef PREFIX
CONFIGURE_ARGS=--prefix $(PREFIX)
endif

# propagate additional template variables for spec template processing
TT_EXTRA_SYMBOLS = --define CONFIGURE_ARGS="$(CONFIGURE_ARGS)" --define PREFIX="$(PREFIX)"

default: clean dist package collect

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

$(PACKAGE).spec: $(PACKAGE).spec.template

package: $(PACKAGE).spec
	rpmbuild -ba $(PACKAGE).spec

collect:
	mv $(RPMBASE)/SRPMS/$(PACKAGE)-*.rpm .
	mv $(RPMBASE)/RPMS/*/$(PACKAGE)-*.rpm .

clean:
	rm -f $(PACKAGE)-*.rpm $(PACKAGE).spec



## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project

TOPDIR=../../../..

PACKAGE=perl-openxpki-client-html-sc
SRCBASE=$(TOPDIR)/trunk/clients/perl/OpenXPKI-Client-HTML-SC
SRCNAME=OpenXPKI-Client-HTML-SC

# Makefile.inc contains common settings for all packages (checked in)
include ../Makefile.inc
# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local

all: clean perl-dist package collect

dist-clean:
	( cd $(SRCBASE) && \
		rm -f *.tar.gz \
	)


perl-dist: dist-clean
	( cd $(SRCBASE) && \
		perl Makefile.PL && \
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



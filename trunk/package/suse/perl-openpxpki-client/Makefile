## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
## $Revision: 350 $

RPMBASE=/usr/src/packages
OPENXPKI_SVN=../../../..

PACKAGE=perl-openxpki-client
SRCBASE=$(OPENXPKI_SVN)/trunk/clients/perl/OpenXPKI-Client
SRCNAME=OpenXPKI-Client

VERGEN=$(OPENXPKI_SVN)/tools/vergen
VERSION=$(shell $(VERGEN) --format version --directory $(SRCBASE))


#include ../Makefile.package

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

$(PACKAGE).spec: $(PACKAGE).spec.in
	sed -e 's/_VERSION_/$(VERSION)/g' <$< >$@

package: $(PACKAGE).spec
	rpm -ba $(PACKAGE).spec

collect:
	mv $(RPMBASE)/SRPMS/$(PACKAGE)-*.rpm .
	mv $(RPMBASE)/RPMS/*/$(PACKAGE)-*.rpm .

clean:
	rm -f $(PACKAGE)-*.rpm $(PACKAGE).spec



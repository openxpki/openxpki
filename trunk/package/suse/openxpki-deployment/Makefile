## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
## $Revision: 350 $

RPMBASE=/usr/src/packages
OPENXPKI_SVN=../../../..

PACKAGE=openxpki-deployment
SRCBASE=$(OPENXPKI_SVN)/trunk/deployment
SRCNAME=deployment

VERGEN=$(OPENXPKI_SVN)/tools/vergen
VERSION=$(shell $(VERGEN) --format version --directory $(SRCBASE))

default: clean dist package collect

dist-clean:
	( cd $(SRCBASE) && \
		rm -f *.tar.gz \
	)


dist: dist-clean
	( cd $(SRCBASE)/ && \
		make -f Makefile.in dist && \
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



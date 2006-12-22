## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
## $Revision: 350 $

PACKAGES=\
	perl-openxpki-core \
	perl-openxpki-client \
	openxpki-deployment \
	perl-openxpki-client-html-mason \
	openxpki-i18n \


.PHONY : $(PACKAGES)

all: clean $(PACKAGES) collect

$(PACKAGES):
	cd $@ && PATH=$(PATH):/usr/sbin make $(SUBTARGET)

collect:
	@mv */*.rpm .     || echo No suse package file found.

clean:
	rm -f *.rpm
	make $(PACKAGES) SUBTARGET=clean

distclean: clean

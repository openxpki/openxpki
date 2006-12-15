## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
## $Revision: 350 $

PACKAGES=	\
	core			\



	#perl-client-api		\
	#perl-cli-client		\
	#deployment		\
	#mason-html-client	\
	#i18n

.PHONY : $(PACKAGES)

all: clean $(PACKAGES)

$(PACKAGES):
	cd $@ && PATH=$(PATH):/usr/sbin make $(SUBTARGET)

resultlocal:
	mv */*.tar.gz .  || echo No source file present.
	mv */*.rpm .     || echo No debian package file present.
	mv */*.changes . || echo No changes file present.

check:


clean:
	rm -f *.rpm
	make $(PACKAGES) SUBTARGET=clean

distclean: clean

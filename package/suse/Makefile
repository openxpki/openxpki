## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2011 by The OpenXPKI Project
##
## Prereq: cpanspec.sourceforge.net

TOPDIR=../../..

PACKAGES=\
	perl-openxpki-core \
	perl-openxpki-client \
	openxpki-deployment \
	perl-openxpki-client-html-mason \
	perl-openxpki-client-scep \
	openxpki-i18n \

ifdef PREFIX
PERL_MAKEPL_ARGS="PREFIX=$(PREFIX)"
endif

# Disable implicit rules to make debugging easier. We're using our own rules, anyway.

.SUFFIXES:

.PHONY : $(PACKAGES) cpan fetchcpan

# Makefile.inc contains common settings for all packages (checked in)
include Makefile.inc

# optional: Makefile.local may be used locally to override 
# settings (should not be checked in)
-include Makefile.local

all: clean $(PACKAGES) collect

cpan:
	make --directory=cpan TARGET=cpan

cleancpan:
	make --directory=cpan TARGET=clean

$(PACKAGES):
	cd $@ && PATH=$(PATH):/usr/sbin make $(SUBTARGET) $(PERL_MAKEPL_ARGS)

collect:
	@mv */*.rpm .     || echo No suse package file found.

clean:
	rm -f *.rpm
	make $(PACKAGES) SUBTARGET=clean

distclean: clean

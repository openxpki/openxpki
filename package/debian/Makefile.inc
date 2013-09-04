## Written 2011 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2011 by The OpenXPKI Project

# Common definitions for all debian package Makefiles
# NOTE: You may create a file called Makefile.local in this directory
# to override any of these settings!
#
# NOTE 2: Also ensure that the following env vars are set:
#
#   TOPDIR  -> Relative path to top directory of OpenXPKI (working directory)
#   SRCBASE -> base directory to be built
#   PERLNAME -> Not sure yet what this is other than a temporary filename
#   PACKAGE -> Name of package to create
#
# Here's an example:
#
#   TOPDIR=../..
#   SRCBASE=$(TOPDIR)/core/server
#   PACKAGE=libopenxpki-perl
#   PERLNAME=OpenXPKI
#   PKGDIR=../deb/core
#
#   # Makefile.inc contains common settings for all packages (checked in)
#   include ../Makefile.inc
#   # Makefile.local may be used locally to override settings (not checked in)
#   -include ../Makefile.local


# common includes for package builds
include $(TOPDIR)/package/common/Makefile.inc

ifdef PREFIX
PERL_MAKEPL_ARGS="PREFIX=$(PREFIX)"
endif

# Sanity checks...
ifndef TOPDIR
	$(error Variable TOPDIR not set)
endif
ifndef SRCBASE
	$(error Variable SRCBASE not set)
endif
ifndef PACKAGE
	$(error Variable PACKAGE not set)
endif
ifndef PERLNAME
	$(error Variable PERLNAME not set)
endif
ifndef PKGDIR
	$(error Variable PKGDIR not set)
endif

default:
	make clean
	make control
	make changelog
	make openxpki-archive
	make debian-archive
	make source
ifdef EXAMPLE
	make examples
endif
	make package
#make source-clean

openxpki-archive:
	cd $(SRCBASE); \
	perl Makefile.PL; \
	make dist; \
	mv $(PERLNAME)-*.tar.gz /tmp

debian-archive:
	tar -czf /tmp/openxpki-debian.tar.gz .

source:
	cd /tmp; \
	tar -xzf $(PERLNAME)-*.tar.gz; \
	cd $(PERLNAME)-*/; \
	mkdir debian; \
	cd debian; \
	tar -xzf /tmp/openxpki-debian.tar.gz;

control: control.template

package:
	cd /tmp/$(PERLNAME)-*/; \
	fakeroot dpkg-buildpackage || echo ignoring error - usually signing ...
	test -d $(PKGDIR) || mkdir $(PKGDIR)
	mv /tmp/$(PACKAGE)_* $(PKGDIR)/

changelog::
	if [ ! -e changelog.org ]; then mv changelog changelog.org; fi
	echo -n $(PACKAGE) > changelog
	DATE=`date +'%Y%m%d'` && echo \ \($$DATE\) unstable\; urgency=low >> changelog
	echo >> changelog
	echo "  * Daily build." >> changelog
	echo >> changelog
	echo " -- OpenXPKI Foundation <debian@openxpki.org> " `date --rfc-2822` >> changelog

source-clean:
	rm -rf /tmp/$(PERLNAME)-*
	rm -f /tmp/openxpki-debian.tar.gz

clean:	source-clean
	if [ -e changelog.org ]; then mv changelog.org changelog; fi
	if [ -d ../examples ]; then rm -rf ../examples; fi
	rm -f *.dsc *.dsc.asc *.tar.gz $(PKGDIR)/$(PACKAGE)_* *.changes

distclean: clean

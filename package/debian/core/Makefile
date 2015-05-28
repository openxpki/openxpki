# trunk/package/debian/core
#

TOPDIR=../../..
SRCBASE=$(TOPDIR)/core/server
PACKAGE=libopenxpki-perl
PERLNAME=OpenXPKI
PKGDIR=../deb/core
EXAMPLE=$(TOPDIR)/config

# Makefile.inc contains common settings for all packages (checked in)
include ../Makefile.inc
# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local

examples:
	cd $(EXAMPLE); \
	tar -czf /tmp/openxpki-examples.tar.gz .; \
	cd /tmp/$(PERLNAME)-*; \
	mkdir -p examples; \
	tar -xzf /tmp/openxpki-examples.tar.gz  -C examples; \
	cd examples; \
	tar -zcf openxpki-etc.tgz openxpki; \
	tar -zcf profiles.tgz profiles; \
	cd feature; \
	tar -zcf ../openxpki-feature.tgz *; \
	cd ..
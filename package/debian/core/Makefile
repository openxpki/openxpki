# trunk/package/debian/core
#

TOPDIR=../../..
SRCBASE=$(TOPDIR)/core/server
PACKAGE=libopenxpki-perl
PERLNAME=OpenXPKI
PKGDIR=../deb/core
EXAMPLE=$(TOPDIR)/core/config 

# Makefile.inc contains common settings for all packages (checked in)
include ../Makefile.inc
# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local

examples:
	cd $(EXAMPLE); \
	tar -czf /tmp/openxpki-examples.tar.gz .; \
	cd /tmp/$(PERLNAME)-*; \
	mkdir examples; \
	tar -xzf /tmp/openxpki-examples.tar.gz  -C examples; \
	cd examples; \
	tar -zcf basic.tgz basic; \
	tar -zcf profiles.tgz profiles; \
	tar -zcf soap.tgz soap; \
	tar -zcf scep.tgz scep; \
	tar -zcf notification.tgz notification;  

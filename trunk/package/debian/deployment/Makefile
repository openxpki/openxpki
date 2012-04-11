# trunk/package/debian/deployment

TOPDIR=../../../..
SRCBASE=$(TOPDIR)/trunk/deployment
PACKAGE=openxpki-deployment
PERLNAME=OpenXPKI
PKGDIR=../deb/client

# Makefile.inc contains common settings for all packages (checked in)
include ../Makefile.inc
# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local

# The default openxpki-archive target is for perl modules
openxpki-archive:
	cd ${SRCBASE}; \
	./configure --distonly; \
	make dist; \
	mv $(PACKAGE)-*.tar.gz /tmp

# TODO: can we use the default here instead?
source:
	cd /tmp; \
	tar -xzf $(PACKAGE)-*.tar.gz; \
	cd $(PACKAGE)-*/; \
	mkdir debian; \
	cd debian; \
	tar -xzf /tmp/openxpki-debian.tar.gz;

# TODO: can we use the default here instead?
package:
	cd /tmp/$(PACKAGE)-*/; \
	fakeroot dpkg-buildpackage || echo ignoring error - usually signing ...
	test -d ../deb/client || mkdir ../deb/client
	mv /tmp/$(PACKAGE)_* ../deb/client/

source-clean:
	rm -rf /tmp/$(PACKAGE)-*
	rm -f /tmp/$(PACKAGE)-*.tar.gz
	rm -f /tmp/$(PACKAGE).tar.gz
	rm -f /tmp/openxpki-debian.tar.gz

clean:	source-clean
	if [ -e changelog.org ]; then mv changelog.org changelog; fi
	rm -f *.dsc *.dsc.asc *.tar.gz ../deb/client/$(PACKAGE)_* *.changes

distclean: clean

# trunk/package/debian/i18n

TOPDIR=../../..
SRCBASE=$(TOPDIR)/core/i18n
PERLNAME=OpenXPKI
PACKAGE=openxpki-i18n
PKGDIR=../deb/core

# Makefile.inc contains common settings for all packages (checked in)
include ../Makefile.inc
# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local

openxpki-archive:
	cd $(SRCBASE); \
	make scan; \
	make dist; \
	mv $(PACKAGE)-*.tar.gz /tmp

source:
	cd /tmp; \
	tar -xzf $(PACKAGE)-*.tar.gz; \
	cd $(PACKAGE)-*/; \
	mkdir debian; \
	cd debian; \
	tar -xzf /tmp/openxpki-debian.tar.gz;

package:
	cd /tmp/$(PACKAGE)-*/; \
	fakeroot dpkg-buildpackage || echo ignoring error - usually signing ...
	test -d $(PKGDIR) || mkdir $(PKGDIR)
	mv /tmp/$(PACKAGE)_* $(PKGDIR)/

source-clean:
	rm -rf /tmp/$(PACKAGE)-*
	rm -f /tmp/$(PACKAGE)-*.tar.gz
	rm -f /tmp/openxpki-debian.tar.gz

clean:	source-clean
	if [ -e changelog.org ]; then mv changelog.org changelog; fi
	rm -f *.dsc *.dsc.asc *.tar.gz $(PKGDIR)/$(PACKAGE)_* *.changes


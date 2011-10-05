# trunk/package/debian/core
#

TOPDIR=../../../..

SRCBASE=$(TOPDIR)/trunk/perl-modules/core/trunk
OPENXPKI_SVN=../../../..
PACKAGE=libopenxpki-perl
PERLNAME=OpenXPKI

# Makefile.inc contains common settings for all packages (checked in)
include ../Makefile.inc
# Makefile.local may be used locally to override settings (not checked in)
-include ../Makefile.local

default:
	make clean
	make control
	make changelog
	make openxpki-archive
	make debian-archive
	make source
	make package
	make source-clean

openxpki-archive:
	cd $(SRCBASE); \
	perl Makefile.PL; \
	make dist; \
	mv $(PERLNAME)-*.tar.gz /tmp

debian-archive:
	## cd ${OPENXPKI_SVN}/trunk/package/
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
	test -d ../deb/core || mkdir ../deb/core	
	mv /tmp/$(PACKAGE)_* ../deb/core

changelog::
	if [ ! -e changelog.org ]; then mv changelog changelog.org; fi
	echo -n $(PACKAGE) > changelog
	DATE=`date +'%Y%m%d'` && echo \ \($$DATE\) unstable\; urgency=low >> changelog
	echo >> changelog
	echo "  * Daily build." >> changelog
	echo >> changelog
	echo " -- Scott T Hardin <scotty@hnsc.de> " `date --rfc-2822` >> changelog

source-clean:
	rm -rf /tmp/$(PERLNAME)-*
	rm -f /tmp/openxpki-debian.tar.gz

clean:	source-clean
	if [ -e changelog.org ]; then mv changelog.org changelog; fi
	rm -f *.dsc *.dsc.asc *.tar.gz ../deb/core/* *.changes

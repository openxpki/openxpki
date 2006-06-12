# trunk/package/debian/core

OPENXPKI_SVN=../../../..

default:
	make clean
	make openxpki-archive
	make debian-archive
	make source
	make package
	make source-clean

openxpki-archive:
	cd ${OPENXPKI_SVN}/trunk/perl-modules/core/trunk; \
	perl Makefile.PL; \
	make dist; \
	mv OpenXPKI-*.tar.gz /tmp

debian-archive:
	## cd ${OPENXPKI_SVN}/trunk/package/
	tar -czf /tmp/openxpki-debian.tar.gz .

source:
	cd /tmp; \
	tar -xzf OpenXPKI-*.tar.gz; \
	cd OpenXPKI-*/; \
	mkdir debian; \
	cd debian; \
	tar -xzf /tmp/openxpki-debian.tar.gz;

package:
	cd /tmp/OpenXPKI-*/; \
	fakeroot dpkg-buildpackage || echo ignoring error - usually signing ...
	mv /tmp/libopenxpki-perl_* .

source-clean:
	rm -rf /tmp/OpenXPKI-*
	rm -f /tmp/openxpki-debian.tar.gz

clean:	source-clean
	rm -f *.dsc *.dsc.asc *.tar.gz *.deb *.changes

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
	cd ${OPENXPKI_SVN}/trunk/clients/perl/OpenXPKI-Client; \
	perl Makefile.PL; \
	make dist; \
	mv OpenXPKI-Client-*.tar.gz /tmp

debian-archive:
	## cd ${OPENXPKI_SVN}/trunk/package/
	tar -czf /tmp/openxpki-debian.tar.gz .

source:
	cd /tmp; \
	tar -xzf OpenXPKI-Client-*.tar.gz; \
	cd OpenXPKI-Client-*/; \
	mkdir debian; \
	cd debian; \
	tar -xzf /tmp/openxpki-debian.tar.gz;

package:
	cd /tmp/OpenXPKI-Client-*/; \
	fakeroot dpkg-buildpackage || echo ignoring error - usually signing ...
	mv /tmp/libopenxpki-client-perl_* .

source-clean:
	rm -rf /tmp/OpenXPKI-Client-*
	rm -f /tmp/openxpki-debian.tar.gz

clean:	source-clean
	rm -f *.dsc *.dsc.asc *.tar.gz *.deb *.changes

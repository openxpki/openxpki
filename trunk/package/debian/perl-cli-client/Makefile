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
	cd ${OPENXPKI_SVN}/trunk/clients/perl/OpenXPKI-Client-CLI; \
	perl Makefile.PL; \
	make dist; \
	mv OpenXPKI-Client-CLI-*.tar.gz /tmp

debian-archive:
	## cd ${OPENXPKI_SVN}/trunk/package/
	tar -czf /tmp/openxpki-debian.tar.gz .

source:
	cd /tmp; \
	tar -xzf OpenXPKI-Client-CLI-*.tar.gz; \
	cd OpenXPKI-Client-CLI-*/; \
	mkdir debian; \
	cd debian; \
	tar -xzf /tmp/openxpki-debian.tar.gz;

package:
	cd /tmp/OpenXPKI-Client-CLI-*/; \
	fakeroot dpkg-buildpackage || echo ignoring error - usually signing ...
	mv /tmp/libopenxpki-client-cli-perl_* .

source-clean:
	rm -rf /tmp/OpenXPKI-Client-CLI-*
	rm -f /tmp/openxpki-debian.tar.gz

clean:	source-clean
	rm -f *.dsc *.dsc.asc *.tar.gz *.deb *.changes

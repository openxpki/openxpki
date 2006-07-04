# trunk/package/debian/mason-html-client

OPENXPKI_SVN=../../../..

default:
	make clean
	make openxpki-archive
	make debian-archive
	make source
	make package
	make source-clean

openxpki-archive:
	cd ${OPENXPKI_SVN}/trunk/clients/perl/OpenXPKI-Client-HTML-Mason; \
	perl Makefile.PL; \
	make dist; \
	mv OpenXPKI-Client-HTML-Mason-*.tar.gz /tmp

debian-archive:
	## cd ${OPENXPKI_SVN}/trunk/package/
	tar -czf /tmp/openxpki-debian.tar.gz .

source:
	cd /tmp; \
	tar -xzf OpenXPKI-Client-HTML-Mason-*.tar.gz; \
	cd OpenXPKI-Client-HTML-Mason-*/; \
	mkdir debian; \
	cd debian; \
	tar -xzf /tmp/openxpki-debian.tar.gz;

package:
	cd /tmp/OpenXPKI-Client-HTML-Mason-*/; \
	fakeroot dpkg-buildpackage || echo ignoring error - usually signing ...
	mv /tmp/libopenxpki-client-html-mason-perl_* .

source-clean:
	rm -rf /tmp/OpenXPKI-Client-HTML-Mason-*
	rm -f /tmp/openxpki-debian.tar.gz

clean:	source-clean
	rm -f *.dsc *.dsc.asc *.tar.gz *.deb *.changes

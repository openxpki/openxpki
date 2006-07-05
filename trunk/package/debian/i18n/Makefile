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
	cd ${OPENXPKI_SVN}/trunk/i18n/; \
	make dist; \
	mv openxpki-i18n-*.tar.gz /tmp

debian-archive:
	## cd ${OPENXPKI_SVN}/trunk/package/
	tar -czf /tmp/openxpki-debian.tar.gz .

source:
	cd /tmp; \
	tar -xzf openxpki-i18n-*.tar.gz; \
	cd openxpki-i18n-*/; \
	mkdir debian; \
	cd debian; \
	tar -xzf /tmp/openxpki-debian.tar.gz;

package:
	cd /tmp/openxpki-i18n-*/; \
	fakeroot dpkg-buildpackage || echo ignoring error - usually signing ...
	mv /tmp/openxpki-i18n_* .

source-clean:
	#rm -rf /tmp/openxpki-i18n-*
	#rm -f /tmp/openxpki-i18n-*.tar.gz
	#rm -f /tmp/openxpki-debian.tar.gz

clean:	source-clean
	rm -f *.dsc *.dsc.asc *.tar.gz *.deb *.changes

distclean: clean

# trunk/package/debian/core

OPENXPKI_SVN=../../../..
PACKAGE=openxpki-deployment

default:
	make clean
	make changelog
	make openxpki-archive
	make debian-archive
	make source
	make package
	make source-clean

openxpki-archive:
	cd ${OPENXPKI_SVN}/trunk/deployment; \
	./configure --distonly; \
	make dist; \
	mv $(PACKAGE)-*.tar.gz /tmp

debian-archive:
	## cd ${OPENXPKI_SVN}/trunk/package/
	tar -czf /tmp/openxpki-debian.tar.gz .

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
	test -d ../deb/client || mkdir ../deb/client
	mv /tmp/$(PACKAGE)_* ../deb/client/

changelog::
	if [ ! -e changelog.org ]; then mv changelog changelog.org; fi
	echo -n $(PACKAGE) > changelog
	DATE=`date +'%Y%m%d'` && echo \ \($$DATE\) unstable\; urgency=low >> changelog
	echo >> changelog
	echo "  * Daily build." >> changelog
	echo >> changelog
	echo " -- Scott T Hardin <scotty@hnsc.de> " `date --rfc-2822` >> changelog

source-clean:
	rm -rf /tmp/$(PACKAGE)-*
	rm -f /tmp/$(PACKAGE)-*.tar.gz
	rm -f /tmp/$(PACKAGE).tar.gz
	rm -f /tmp/openxpki-debian.tar.gz

clean:	source-clean
	if [ -e changelog.org ]; then mv changelog.org changelog; fi
	rm -f *.dsc *.dsc.asc *.tar.gz ../deb/client/$(PACKAGE)_* *.changes

distclean: clean

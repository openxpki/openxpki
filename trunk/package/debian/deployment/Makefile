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
	cd ${OPENXPKI_SVN}/trunk/; \
	tar -czf /tmp/openxpki-deployment.tar.gz deployment;

debian-archive:
	## cd ${OPENXPKI_SVN}/trunk/package/
	tar -czf /tmp/openxpki-debian.tar.gz .

source:
	cd /tmp; \
	tar -xzf openxpki-deployment.tar.gz; \
	cd deployment/; \
	mkdir debian; \
	cd debian; \
	tar -xzf /tmp/openxpki-debian.tar.gz;

package:
	cd /tmp/deployment/; \
	fakeroot dpkg-buildpackage || echo ignoring error - usually signing ...
	mv /tmp/openxpki-deployment_* .

source-clean:
	rm -rf /tmp/deployment
	rm -f /tmp/openxpki-deployment.tar.gz
	rm -f /tmp/openxpki-debian.tar.gz

clean:	source-clean
	rm -f *.dsc *.dsc.asc *.tar.gz *.deb

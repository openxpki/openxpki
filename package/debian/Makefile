# we need this packages to build external cpan modules (debian 10 / buster)

# do not change the order
# some packages have build dependencies
PACKAGES=			\
	core			\
	i18n 			\
	cgi-session-driver

DEBIAN_VERSION = $(shell cat /etc/debian_version)

EXTERNAL=				\
	Class__Observable \
	Config__Merge \
	Crypt__Argon2 \
	Crypt__LibSCEP \
	Crypt__OpenSSL__AES \
	Crypt__PKCS10 \
	Crypt__X509 \
	DBIx__Handler \
	DBIx__TransactionManager \
	Feature__Compat__Try \
	Git__PurePerl \
	JSON__MaybeXS \
	Log__Log4perl__Layout__JSON \
	Proc__SafeExec \
	YAML__Tiny

EXTERNAL2= \
	Connector \
	Workflow

CORE = \
    CGI \
    Module__Build__Tiny \
    Module__Load

.PHONY : $(PACKAGES) $(EXTERNAL) $(EXTERNAL2) CGI

openxpki: $(PACKAGES)

cpan: cpan_dependency cpan_dependency2

cpan_dependency: $(EXTERNAL)

cpan_dependency2: $(EXTERNAL2)

release: cpan_dependency cpan_dependency2 Crypt__LibSCEP openxpki

trusty: CGI Module__Build__Tiny Module__Load

default:	clean
	$(MAKE) $(EXTERNAL)
	$(MAKE) $(PACKAGES)
	$(MAKE) resultlocal
	$(MAKE) check

# Fetch outdated version of Workflow because the newest isn't
# compatible with OpenXPKI
$(EXTERNAL):
	test -d deb || mkdir deb
	test -d deb/cpan || mkdir deb/cpan/
	cd deb/cpan/ && DEBEMAIL=debian@openxpki.org DEBFULLNAME="OpenXPKI Foundation" DEB_BUILD_OPTIONS=nocheck dh-make-perl --build $($@_BUILDOPTS) --cpan $(subst __,::,$@)

$(EXTERNAL2):
	test -d deb || mkdir deb
	test -d deb/cpan || mkdir deb/cpan/
	cd deb/cpan/ && PERL5LIB=`pwd`"/../../lib/:$PERL5LIB" DEBEMAIL=debian@openxpki.org DEBFULLNAME="OpenXPKI Foundation" DEB_BUILD_OPTIONS=nocheck dh-make-perl --build --cpan $(subst __,::,$@)

$(CORE):
	test -d deb || mkdir deb
	test -d deb/cpan || mkdir deb/cpan/
	cd deb/cpan/ && DEBEMAIL=debian@openxpki.org DEBFULLNAME="OpenXPKI Foundation" DEB_BUILD_OPTIONS=nocheck dh-make-perl --core-ok --build --cpan $(subst __,::,$@)

$(PACKAGES): info
	test -d deb || mkdir deb
	cd $@ && PATH=$(PATH):/usr/sbin $(MAKE) $(SUBTARGET)

resultlocal:
	mv */*.dsc .     || echo No dsc file present.
	mv */*.dsc.asc . || echo No asc file present.
	mv */*.tar.gz .  || echo No source file present.
	mv */*.deb .     || echo No debian package file present.
	mv */*.changes . || echo No changes file present.

check:
	# use -i to see more details
	lintian *.deb

clean:
	mkdir -p deb/cpan/ && cd deb/cpan/ && rm -f *.dsc *.dsc.asc *.tar.gz *.deb *.changes
	$(MAKE) $(PACKAGES) SUBTARGET=clean
	cd deb/cpan/ && for DIR in $(subst __,-,$(EXTERNAL)); do \
		rm -rf $$DIR-*; \
	done

distclean: clean

scan:
	dpkg-scanpackages deb | gzip > deb/Packages.gz

.PHONY: info

info:
	@echo "CURDIR = $(CURDIR)"
	@echo "MAKEFILE_LIST = $(MAKEFILE_LIST)"
	@echo "PERL_SKIP_TEST = $(PERL_SKIP_TEST)"

# we need this packages to build external cpan modules (debian 10 / buster)

# do not change the order
# some packages have build dependencies
PACKAGES=			\
	core			\
	i18n 			\
	cgi-session-driver

DEBIAN_VERSION = $(shell cat /etc/debian_version)

# As we use --recursive in dh-make-perl make sure that all deps that
# are available from the debian repositories are contained in the
# build-deps.list as they will otherwise built again!
EXTERNAL=				\
	Class__Observable \
	Connector \
	Crypt__OpenSSL__AES \
	Crypt__PKCS10 \
	DBIx__Handler \
	DBIx__TransactionManager \
	Log__Log4perl__Layout__JSON \
	Proc__SafeExec \
	Workflow \
	YAML__PP

# Bookworm ships with v0.55 so as long as we dont update
# (or debian keeps pace) we dont need to build this ourselves
EXTRA= \
	Crypt__X509

CORE = \
	CGI

.PHONY : $(PACKAGES) $(EXTERNAL) CGI

openxpki: $(PACKAGES)

cpan: cpan_dependency

cpan_dependency: $(EXTERNAL)

release: cpan_dependency openxpki

default:	clean
	$(MAKE) $(EXTERNAL)
	$(MAKE) $(PACKAGES)
	$(MAKE) resultlocal
	$(MAKE) check

# run dh-make-perl with --install --recursive to auto-build/add missing dependancies
# for Buster this is required for at least Feature::Compat::Try pulling in
# Syntax::Keyword::Try and other deps that are too old in buster repos
$(EXTERNAL) $(EXTRA):
	test -d deb || mkdir deb
	test -d deb/cpan || mkdir deb/cpan/
	cd deb/cpan/ && DEBEMAIL=debian@openxpki.org DEBFULLNAME="OpenXPKI Foundation" DEB_BUILD_OPTIONS=nocheck dh-make-perl --build $($@_BUILDOPTS) --recursive --install --cpan $(subst __,::,$@)

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

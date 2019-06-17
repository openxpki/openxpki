
# we need this packages to build external cpan modules (debian squeeze)
#
# -- stuff added for squeeze
# dh-make-perl (this will bring a bunch of dependencies automatically)
# libmodule-build-perl
#
# -- stuff already in etch
# libversion-perl libmodule-build-perl iblog-log4perl-perl libdatetime-perl
# libapache-request-perl libtest-exception-perl libxml-sax-perl
# libxml-sax-writer-perl libtree-dagnode-perl liburi-perl
# libclass-factory-perl libxml-simple-perl libdatetime-format-strptime-perl
# libhttp-server-simple-perl libdata-page-perl

# do not change the order
# some packages have build dependencies
PACKAGES=			\
	core			\
	i18n 			\
	cgi-session-driver

DEBIAN_CODENAME = $(shell lsb_release -sc)

# Data::Password Data::Serializer DateTime::Format::DateParse IPC::ShareLite 
# Locale::TextDomain Proc::ProcessTable Sys::SigAction Workflow 
# XML::Filter::XInclude XML::SAX::PurePerl XML::Validator::Schema
# Exception::Class 1.22 Added Exception::Class::Base->caught() 

ifeq "$(DEBIAN_CODENAME)" "buster"
EXTERNAL=				\
	Crypt__OpenSSL__AES		\
	Crypt__Cipher__AES \
	Data__SpreadPagination		\
	Class__Observable 		\
	Config__Versioned \
	Proc__SafeExec \
	XML__Filter__XInclude \
	Crypt__PKCS10 \
	Crypt__X509__CRL \
	DBIx__Handler \
    DBIx__TransactionManager \
    Log__Log4perl__Layout__JSON
else
EXTERNAL=				\
	Crypt__OpenSSL__AES		\
	Crypt__Cipher__AES \
	Data__SpreadPagination		\
	Class__Observable 		\
	Git__PurePerl \
	Config__Merge \
	Config__Versioned \
	Proc__SafeExec \
	XML__Filter__XInclude \
	Crypt__PKCS10 \
	Crypt__X509 \
	Crypt__X509__CRL \
	DBIx__Handler \
    DBIx__TransactionManager \
    Log__Log4perl__Layout__JSON \
    JSON__MaybeXS \
    YAML__Tiny
endif
    
EXTERNAL2= \
	Connector \
	Workflow 

CORE = \
    CGI \
    Module__Build__Tiny \
    Module__Load


Data__SpreadPagination_BUILDOPTS = --version 0.1.2

.PHONY : $(PACKAGES) $(EXTERNAL) $(EXTERNAL2) CGI DateTime__Format__DateParse

openxpki: $(PACKAGES) 

cpan_dependency: $(EXTERNAL) 

cpan_dependency2: $(EXTERNAL2) 

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

DateTime__Format__DateParse:
	test -d deb || mkdir deb
	test -d deb/cpan || mkdir deb/cpan/	
	cd deb/cpan/ &&  dh-make-perl --build --notest --depends 'libdatetime-timezone-perl, libdatetime-perl, libtimedate-perl' --cpan $(subst __,::,$@)


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
	cd deb/cpan/ && rm -f *.dsc *.dsc.asc *.tar.gz *.deb *.changes
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

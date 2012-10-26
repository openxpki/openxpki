
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
	mason-html-client	
	

# Data::Password Data::Serializer DateTime::Format::DateParse IPC::ShareLite 
# Locale::TextDomain Proc::ProcessTable Sys::SigAction Workflow 
# XML::Filter::XInclude XML::SAX::PurePerl XML::Validator::Schema
# Exception::Class 1.22 Added Exception::Class::Base->caught() 

EXTERNAL=				\
	Crypt__OpenSSL__AES		\
	Data__SpreadPagination		\
	Class__Observable 		\
	Test__utf8 \
	Git__PurePerl \
	Config__Merge \
	Config__Versioned \
	Proc__SafeExec \
	XML__Filter__XInclude 

EXTERNAL2= \
	Workflow \
	Connector

.PHONY : $(PACKAGES) $(EXTERNAL) $(EXTERNAL2) DateTime__Format__DateParse

cpan_dependency: $(EXTERNAL) 

cpan_dependency2: $(EXTERNAL2) 

default:	clean
	make $(EXTERNAL)
	make $(PACKAGES)
	make resultlocal
	make check

# Fetch outdated version of Workflow because the newest isn't
# compatible with OpenXPKI
$(EXTERNAL) $(EXTERNAL2):
	test -d deb || mkdir deb
	test -d deb/cpan || mkdir deb/cpan/
	cd deb/cpan/ && DEBEMAIL=debian@openxpki.org DEBFULLNAME="OpenXPKI Foundation" DEB_BUILD_OPTIONS=nocheck dh-make-perl --build --cpan $(subst __,::,$@)


# Development Builds from git repos
Connector:
	test -d deb/cpan/Connector || git clone git://github.com/oliwel/connector.git  deb/cpan/Connector
	cd deb/cpan/ && DEBEMAIL=debian@openxpki.org DEBFULLNAME="OpenXPKI Foundation" DEB_BUILD_OPTIONS=nocheck dh-make-perl --desc Connector --version dev-`date +%Y%m%d`  --build Connector/

Workflow:
	test -d deb/cpan/perl-workflow || git clone -b tag/1.99 git://github.com/oliwel/perl-workflow deb/cpan/perl-workflow
	cd deb/cpan/ && DEBEMAIL=debian@openxpki.org DEBFULLNAME="OpenXPKI Foundation" DEB_BUILD_OPTIONS=nocheck dh-make-perl  --version dev-1.99 --build perl-workflow/

DateTime__Format__DateParse:
	test -d deb || mkdir deb
	test -d deb/cpan || mkdir deb/cpan/	
	cd deb/cpan/ &&  dh-make-perl --build --notest --depends 'libdatetime-timezone-perl, libdatetime-perl, libtimedate-perl' --cpan $(subst __,::,$@)


$(PACKAGES):
	test -d deb || mkdir deb	
	cd $@ && PATH=$(PATH):/usr/sbin make $(SUBTARGET)

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
	make $(PACKAGES) SUBTARGET=clean
	cd deb/cpan/ && for DIR in $(subst __,-,$(EXTERNAL)); do \
		rm -rf $$DIR-*; \
	done

distclean: clean

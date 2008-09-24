
# we need this packages to build external cpan modules (debian etch)
# libversion-perl libmodule-build-perl iblog-log4perl-perl libdatetime-perl
# libapache-request-perl libtest-exception-perl libxml-sax-perl
# libxml-sax-writer-perl libtree-dagnode-perl liburi-perl
# libclass-factory-perl libxml-simple-perl libdatetime-format-strptime-perl
# libhttp-server-simple-perl libdata-page-perl

# do not change the order
# some packages have build dependencies
PACKAGES=			\
	core			\
	perl-client-api		\
	deployment		\
	mason-html-client	\
	scep-client		\
	i18n


# Data::Password Data::Serializer DateTime::Format::DateParse IPC::ShareLite 
# Locale::TextDomain Proc::ProcessTable Sys::SigAction Workflow 
# XML::Filter::XInclude XML::SAX::PurePerl XML::Validator::Schema
# Exception::Class 1.22 Added Exception::Class::Base->caught() 

EXTERNAL=				\
	Devel__StackTrace		\
	Exception__Class		\
	HTML__Mason			\
	Class__Std			\
	Config__Std			\
	Data__Password 			\
	Proc__ProcessTable 		\
	Sys__SigAction 			\
	Workflow 			\
	XML__Filter__XInclude 		\
	XML__Validator__Schema 		\
	Data__Serializer 		\
	DateTime__Format__DateParse 	\
	Class__Observable 		\
	DBD__Mock 			\
	Hook__LexWrap			\
	HTTP__Server__Simple__Mason 	\
	Test__HTTP__Server__Simple	\
	Data__SpreadPagination 		\
	Class__Accessor__Chained	\
	Class__Accessor                 \
	Crypt__OpenSSL__AES

.PHONY : $(PACKAGES) $(EXTERNAL)

cpan_dependency: $(EXTERNAL)

default:	clean
	make $(EXTERNAL)
	make $(PACKAGES)
	make resultlocal
	make check

$(EXTERNAL):
	test -d deb || mkdir deb
	test -d deb/cpan || mkdir deb/cpan/	
	cd deb/cpan/ &&  dh-make-perl --build --notest --cpan $(subst __,::,$@)
	#cd deb/cpan/ &&  dh-make-perl --build --cpan $(subst __,::,$@)

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

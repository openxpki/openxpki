## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2011 by The OpenXPKI Project
##
## Prereq: cpanspec.sourceforge.net

TOPDIR=../..

PACKAGES=\
	openxpki-perldeps-core \
	perl-openxpki-core \
	perl-openxpki-client-html-mason \
	openxpki-i18n 

OPT_PACKAGES=\
	openxpki-perldeps-enrollment

# CPAN dependencies that we'd like packaged for the target 
# distribution

EXTERNAL= \
	Class__Factory \
		Scalar__Util \
	Class__Observable \
	CPAN__Meta__YAML \
	Crypt__OpenSSL__AES \
	DBD__Mock \
	Data__Password \
				Params__Validate \
				List__MoreUtils \
			DateTime__Locale \
						Try__Tiny \
						Exporter \
					Test__Fatal \
				Class__Load \
				parent \
			DateTime__TimeZone \
			Class__Singleton \
				Sub__Uplevel \
			Test__Exception \
		DateTime \
	DateTime__Format__Strptime \
		File__Spec \
		Devel__StackTrace \
	Exception__Class \
		Want \
		IO__Handle \
		Term__ReadKey \
		version \
	IO__Prompt \
	Mail__RFC822__Address \
	Pod__Escapes \
	Pod__Simple \
	Proc__ProcessTable \
	Sys__SigAction \
    	File__Slurp \
	    Class__Accessor \
			Sys__Syslog \
		Log__Dispatch \
	Workflow \
	XML__Filter__BufferText \
	XML__SAX__Writer \
	XML__Filter__XInclude \
	Tree__DAG_Node \
	XML__Validator__Schema \
		Digest__SHA \
	Data__Serializer \
	Template \
			Class__Accessor__Chained__Fast \
		Data__Page \
		Math__Round \
	Data__SpreadPagination \
	    Log__Any \
			Error \
		Cache__Cache \
			Test__Tester \
			Test__NoWarnings \
		Test__Deep \
		Class__Container \
	HTML__Mason \
		HTTP__Server__Simple \
		Hook__LexWrap \
	HTTP__Server__Simple__Mason \
	Test__HTTP__Server__Simple \
    	URI \
	    Test__Warn \
    			Compress__Raw__Bzip2 \
				Compress__Raw__Zlib \
	    	IO__Uncompress__Inflate \
			IO__Uncompress__Gunzip \
			IO__Compress__Gzip \
			IO__Uncompress__RawInflate \
			IO__Compress__Deflate \
	    LWP__UserAgent \
	    LWP \
	WWW__Mechanize
	



ifdef PREFIX
PERL_MAKEPL_ARGS="PREFIX=$(PREFIX)"
endif

# Disable implicit rules to make debugging easier. We're using our own rules, anyway.

.SUFFIXES:

.PHONY : $(PACKAGES) $(OPT_PACKAGES) cpan fetchcpan

# Makefile.inc contains common settings for all packages (checked in)
include Makefile.inc

# optional: Makefile.local may be used locally to override 
# settings (should not be checked in)
-include Makefile.local

.PHONY : $(PACKAGES) $(EXTERNAL) all builddep public cust

all:
	@echo "Deprecated - use one of the following"
	@echo " "
	@echo " make builddep     - build the build dependencies"
	@echo " make cpandep      - create CPAN dependency packages"
	@echo " make public       - build the public code packages"
	@echo " make cust         - build the custom code package"

# builddep basically gets any CPAN stuff needed for the build process. First,
# it tries to use zypper to install those provided by SuSE. Then, it fetches
# the cpan2dist stuff to automate the process of installing the remaining 
# packages. (we'll use cpan2dist later when packaging the openxpki prereqs
# from cpan.

builddep:
	@echo "build dependencies"
	@test -f /usr/bin/zypper || (echo "Error: /usr/bin/zypper not found" && exit 1)
	@test -f builddep-`./susesux`.lst || (echo "Error: builddep-`./susesux`.lst not found" && exit 1)
	@xargs zypper install -y < builddep-`./susesux`.lst
	@perl -MCPANPLUS::Dist::SUSE -e 1 || (echo -e "\nError: CPANPLUS::Dist::SUSE not installed\n\n\trun 'cpan CPANPLUS::Dist::SUSE' to install\n" && exit 1)
#	@cpan2dist --format CPANPLUS::Dist::SUSE --install Config::Std

cpandep: $(EXTERNAL)

public: clean $(PACKAGES) collect

cust:
	@echo "Sorry - not implemented yet"

$(EXTERNAL):
	@test -d rpm || mkdir rpm
	@test -d rpm/cpan || mkdir rpm/cpan
	@cd rpm/cpan && cpan2dist --format CPANPLUS::Dist::SUSE --force --install $(subst __,::,$@)

cpan:
	make --directory=cpan TARGET=cpan

cleancpan:
	make --directory=cpan TARGET=clean

$(PACKAGES):
	cd $@ && PATH=$(PATH):/usr/sbin make $(SUBTARGET) $(PERL_MAKEPL_ARGS)

$(OPT_PACKAGES):
	cd $@ && PATH=$(PATH):/usr/sbin make $(SUBTARGET) $(PERL_MAKEPL_ARGS)

collect:
	@mv */*.rpm .     || echo No suse package file found.

clean:
	rm -f *.rpm
	make $(PACKAGES) $(OPT_PACKAGES) SUBTARGET=clean

distclean: clean

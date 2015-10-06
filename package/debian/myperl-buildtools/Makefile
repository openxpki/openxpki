# Makefile for myperl buildtools needed for oxi package build

PACKAGE_NAME		:= myperl-buildtools
include ../myperl-common.mk

-include ../../Makefile.local
-include Makefile.local

# Override location of CPANM set in myperl-common.mk
CPANM		:= $(PERL) $(PWD)/cpanm
CPANM_OPTS = $(CPAN_MIRROR) --notest --skip-satisfied --skip-installed --build-args="INSTALLPRIVLIB=$(SITELIB)"

install: info cpanm 
	mkdir -p $(DESTDIR)/$(SITESCRIPTEXP)
	install -t $(DESTDIR)/$(SITESCRIPTEXP) cpanm
	PERL5LIB=$(PERL5LIB) \
			 PERL_MB_OPT=$(PERL_MB_OPT) \
			 PERL_MM_OPT=$(PERL_MM_OPT) \
			 DESTDIR=$(DESTDIR) \
			 $(CPANM) $(CPANM_OPTS) ExtUtils::MakeMaker
	PERL5LIB=$(PERL5LIB) \
			 PERL_MB_OPT=$(PERL_MB_OPT) \
			 PERL_MM_OPT=$(PERL_MM_OPT) \
			 DESTDIR=$(DESTDIR) \
			 $(CPANM) $(CPANM_OPTS) Config::Std Test::NoWarnings Test::Tester Test::Deep
	#
	# Cleanup for missing support in cpanm for DESTDIR with .meta files
	-mv $(DESTDIR)/lib/perl5/$(ARCHNAME)/.meta $(DESTDIR)$(SITEARCH)/
	# try to *safely* remove the unneeded directories
	-rmdir $(DESTDIR)/lib/perl5/$(ARCHNAME) $(DESTDIR)/lib/perl5 $(DESTDIR)/lib
	# remove perllocal.pod, if installed
	-rm $(DESTDIR)$(ARCHLIB)/perllocal.pod
	# myperl issue #2 - until I can get Pinto running, just remove the offending files
	# Note: since this is a nasty kludge, I'll leave the fail-on-error behavior
	# of make.
	rm -rf \
		$(DESTDIR)$(SITEMAN3EXP)/CPAN::Meta*.3 \
		$(DESTDIR)$(SITEMAN3EXP)/Module::Build* \
		$(DESTDIR)$(SITELIB)/Module/Build.pm \
		$(DESTDIR)$(SITELIB)/Module/Build \
		$(DESTDIR)$(ARCHLIB)/auto/Module/Build 
	# myperl issue #2 - let's just trash these for now
	rm -rf \
		$(DESTDIR)$(SITESCRIPTEXP)/config_data \
		$(DESTDIR)$(SITEMAN1EXP)/config_data.1 \
		$(DESTDIR)$(SITEMAN3EXP)/inc::latest.3 \
		$(DESTDIR)$(SITELIB)/inc

cpanm:
	curl -LO http://xrl.us/cpanm
	chmod +x cpanm


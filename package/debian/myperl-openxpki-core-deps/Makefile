# Makefile for OpenXPKI Perl Dependencies

PACKAGE_NAME		:= myperl-openxpki-core-deps
COREDIR				:= ../../../core/server
include				   ../myperl-common.mk

-include ../../Makefile.local
-include Makefile.local

PACKAGE_VER := $(shell ../../../tools/vergen --format version)
PACKAGE_REL := $(shell ../../../tools/vergen --format PKGREL)


install: info
	PERL5LIB=$(PERL5LIB) PERL_MB_OPT=$(PERL_MB_OPT) DESTDIR=$(DESTDIR) PERL_MM_OPT=$(PERL_MM_OPT) \
		$(CPANM) $(CPANM_OPTS) Config::Std Class::Std
	cd $(COREDIR) && \
		PERL5LIB=$(PERL5LIB) \
		PERL_MB_OPT=$(PERL_MB_OPT) \
		DESTDIR=$(DESTDIR) \
		PERL_MM_OPT=$(PERL_MM_OPT) \
		$(CPANM) $(CPANM_OPTS) --installdeps .
#		$(CPANM) $(CPANM_OPTS) Class::Std Crypt::OpenSSL::AES
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
		$(DESTDIR)$(SITEMAN3EXP)/Sub::Util.3 \
		$(DESTDIR)$(SITEMAN3EXP)/Scalar::Util.3 \
		$(DESTDIR)$(SITEMAN3EXP)/Module::Build* \
		$(DESTDIR)$(SITELIB)/Module/Build.pm \
		$(DESTDIR)$(SITELIB)/Module/Build \
		$(DESTDIR)$(SITEARCH)/auto/Module/Build \
		$(DESTDIR)$(ARCHLIB)/auto/Module/Build 

	# myperl issue #2 - let's just trash these for now
	rm -rf \
		$(DESTDIR)$(SITESCRIPTEXP)/config_data \
		$(DESTDIR)$(SITEMAN1EXP)/config_data.1 \
		$(DESTDIR)$(SITEMAN3EXP)/inc::latest.3 \
		$(DESTDIR)$(SITELIB)/inc


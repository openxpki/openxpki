# Makefile for OpenXPKI 

PACKAGE_NAME		:= myperl-openxpki-core
include	../myperl-common.mk

COREDIR = ../../../core/server
EXAMPLES := ../../../config

-include ../../Makefile.local
-include Makefile.local

.PHONY: examples

# Deprecated... moved to install target
examples:
	mkdir -p examples
	tar -cf - -C $(EXAMPLES) \
		sampleconfig.sh sql apache/openxpki.conf README.md | \
		tar -xf - -C examples
	tar -czf examples/openxpki-etc.tgz -C $(EXAMPLES) openxpki
	tar -czf examples/profiles-etc.tgz -C $(EXAMPLES) profiles
	tar -czf examples/openxpki-feature-etc.tgz -C $(EXAMPLES) feature

install: info
	# Core
	cd $(COREDIR) && \
		PERL5LIB=$(PERL5LIB) \
		PERL_MB_OPT=$(PERL_MB_OPT) \
		DESTDIR=$(DESTDIR) \
		PERL_MM_OPT=$(PERL_MM_OPT) \
		$(CPANM) $(CPANM_OPTS) .
	# Examples
	mkdir -p $(DESTDIR)$(SHARE)/examples
	tar -cf - -C $(EXAMPLES) \
		sampleconfig.sh sql apache/openxpki.conf README.md | \
		tar -xf - -C $(DESTDIR)$(SHARE)/examples
	tar -czf $(DESTDIR)$(SHARE)/examples/openxpki-etc.tgz -C $(EXAMPLES) openxpki
	tar -czf $(DESTDIR)$(SHARE)/examples/profiles-etc.tgz -C $(EXAMPLES) profiles
	tar -czf $(DESTDIR)$(SHARE)/examples/openxpki-feature-etc.tgz -C $(EXAMPLES) feature
	#
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
		$(DESTDIR)$(SITEMAN3EXP)/CGI.3 \
		$(DESTDIR)$(SITEMAN3EXP)/CGI::Apache.3 \
		$(DESTDIR)$(SITEMAN3EXP)/CGI::Carp.3 \
		$(DESTDIR)$(SITEMAN3EXP)/CGI::Cookie.3 \
		$(DESTDIR)$(SITEMAN3EXP)/CGI::Pretty.3 \
		$(DESTDIR)$(SITEMAN3EXP)/CGI::Push.3 \
		$(DESTDIR)$(SITEMAN3EXP)/CGI::Switch.3 \
		$(DESTDIR)$(SITEMAN3EXP)/CGI::Util.3 \
		$(DESTDIR)$(SITEMAN3EXP)/CPAN::Meta*.3 \
		$(DESTDIR)$(SITELIB)/CGI.pm \
		$(DESTDIR)$(SITELIB)/CGI/Apache.pm \
		$(DESTDIR)$(SITELIB)/CGI/Carp.pm \
		$(DESTDIR)$(SITELIB)/CGI/Cookie.pm \
		$(DESTDIR)$(SITELIB)/CGI/Pretty.pm \
		$(DESTDIR)$(SITELIB)/CGI/Push.pm \
		$(DESTDIR)$(SITELIB)/CGI/Switch.pm \
		$(DESTDIR)$(SITELIB)/CGI/Util.pm \
		$(DESTDIR)$(SITEMAN3EXP)/Sub::Util* \
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


# Makefile for myperl-dbd-mysql

PACKAGE_NAME	:= myperl-dbd-mysql
include ../myperl-common.mk

install: info
	PERL5LIB=$(PERL5LIB) PERL_MB_OPT=$(PERL_MB_OPT) PERL_MM_OPT=$(PERL_MM_OPT) DESTDIR=$(DESTDIR) \
		$(CPANM) $(CPANM_OPTS) \
		Test::NoWarnings
	PERL5LIB=$(PERL5LIB) PERL_MB_OPT=$(PERL_MB_OPT) PERL_MM_OPT=$(PERL_MM_OPT) DESTDIR=$(DESTDIR) \
		$(CPANM) $(CPANM_OPTS) \
		Test::Tester Test::Deep DBD::mysql
	# remove perllocal.pod, if installed
	-rm $(DESTDIR)$(ARCHLIB)/perllocal.pod
	-rmdir $(DESTDIR)$(ARCHLIB) $(DESTDIR)$(PRIVLIB)
	# Cleanup for missing support in cpanm for DESTDIR with .meta files
	#mv $(DESTDIR)/lib/perl5/$(ARCHNAME)/.meta $(DESTDIR)$(SITEARCH)/
	# try to *safely* remove the unneeded directories
	#rmdir $(DESTDIR)/lib/perl5/$(ARCHNAME) $(DESTDIR)/lib/perl5 $(DESTDIR)/lib


# This Makefile contains the stuff common to all debian packages
# that use myperl. 
#
# The package Makefile should look something like this:
#
# 	PACKAGE_NAME := myperl-fcgi
#
# 	# Note: these two vars should probably come via the ENV or
# 	# as params for 'make ...'
# 	PACKAGE_VER  := 1.2.3
# 	PACKAGE_REL  := 4
#
# 	include ../myperl-common.mk
#
#	install:
#		<commands to install modules with CPANM>
#
# NOTE: This has only been tested with packages that use the debian
# 		"3.0 (native)" format (in debian/source/format).

PERL		:= /opt/myperl/bin/perl
CPANM		:= $(PERL) $(dir $(PERL))/cpanm

# $(call assert,condition,message)
define assert
$(if $1,,$(error Assertion failed: $2))
endef

# $(call assert-not-null,make-variable)
define assert-not-null
$(call assert,$($1),The variable "$1" is null)
endef

# $(call assert-not-root,make-variable)
define assert-not-root
$(call assert,$(if $(filter $($1),/),,ERR),The variable "$1" is "/")
endef

# Purpose: fetch configuration variables from Perl binary
# Usage: $(call perlcfg,KEY)
define perlcfg
$(shell $(PERL) "-V:$1" | awk -F\' '{print $$2}')
endef



SITELIB		= $(call perlcfg,sitelib)
SITEARCH	= $(call perlcfg,sitearch)
SITELIBEXP	= $(DESTDIR)$(call perlcfg,sitelibexp)
ARCHNAME	= $(call perlcfg,archname)
ARCHLIB		= $(call perlcfg,archlib)
PRIVLIB		= $(call perlcfg,privlib)
SITEMAN1EXP	= $(call perlcfg,siteman1direxp)
SITEMAN3EXP	= $(call perlcfg,siteman3direxp)
SITESCRIPTEXP	= $(call perlcfg,sitescriptexp)
SHARE		= /opt/myperl/share

VENDORLIB	= $(call perlcfg,vendorlib)
VENDORARCH	= $(call perlcfg,vendorarch)
VENDORLIBEXP	= $(call perlcfg,vendorlibexp)
VENDORMAN1EXP	= $(call perlcfg,vendorman1direxp)
VENDORMAN3EXP	= $(call perlcfg,vendorman3direxp)
VENDORSCRIPTEXP	= $(call perlcfg,vendorscriptexp)
PRIVLIB	= $(call perlcfg,privlib)


# The --reinstall flag ensures that the package is built even if cpanm finds
# the module already installed. I tried using this, but found that I ended
# up with Test::Harness in both myperl and this supplemental package
#CPANM		:= $(PERL) $(PWD)/cpanm
CPANM_OPTS = $(CPAN_MIRROR) --notest --skip-satisfied --skip-installed --build-args="INSTALLPRIVLIB=$(SITELIB)"

# Environment vars needed for proper Perl module installation
export PERL5LIB		= $(DESTDIR)$(SITEARCH):$(DESTDIR)$(SITELIB):$(DESTDIR)/lib/perl5
export PERL_MB_OPT	= "--destdir '$(DESTDIR)' --installdirs site"
export PERL_MM_OPT	= "INSTALLDIRS=site DESTDIR=$(DESTDIR) INSTALLPRIVLIB=$(SITELIB)"

info:
	@echo "PACKAGE_NAME = $(PACKAGE_NAME)"
	@echo "PACKAGE_VER  = $(PACKAGE_VER)"
	@echo "PACKAGE_REL	= $(PACKAGE_REL)"
	@echo "PERL5LIB     = $(PERL5LIB)"
	@echo "PERL_MB_OPT  = $(PERL_MB_OPT)"
	@echo "PERL_MM_OPT  = $(PERL_MM_OPT)"
	@echo "ARCHNAME     = $(ARCHNAME)"
	@echo "DESTDIR      = $(DESTDIR)"
	@echo "COREDIR      = $(COREDIR)"
	@echo "PERL         = $(PERL)"
	@echo "CPANM        = $(CPANM)"
	@echo "CPANM_OPTS   = $(CPANM_OPTS)"

debian/changelog:
	$(call assert-not-null,PACKAGE_NAME)
	$(call assert-not-null,PACKAGE_VER)
	$(call assert-not-null,PACKAGE_REL)
	test -d $(dir $@) || mkdir $(dir $@)
	debchange --create --package $(PACKAGE_NAME) \
		--newversion $(PACKAGE_VER).$(PACKAGE_REL) autobuild

clean:
	$(call assert-not-null,PACKAGE_NAME)
	$(call assert-not-root,DESTDIR)
	rm -rf $(DESTDIR) debian/$(PACKAGE_NAME) 

#realclean: clean
#	rm -rf debian/changelog

# This target writes the package and other debian files to the parent directory '..'
# It will cause the debian helper stuff to run all the above target(s).
package: debian/changelog
	DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc



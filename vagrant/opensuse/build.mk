#!/usr/bin/make -f
#
# build.mk - used on build host (e.g. in vagrant instance) to build packages
#

GREP	:= $(shell which grep)
AWK		:= $(shell which awk)
SORT	:= $(shell which sort)
PR		:= $(shell which pr)
CURRENT_MAKEFILE := $(word $(words $(MAKEFILE_LIST)), $(MAKEFILE_LIST))

SUDO := sudo

PINTO_DIR := /pinto
USE_PINTO := $(wildcard $(PINTO_DIR)/stacks/oxibld)

ifdef USE_PINTO
export CPANM_MIRROR := --mirror file:/$(PINTO_DIR)/stacks/oxibld --mirror-only
endif

DEP.MYPERL.VER := 5.20.2
DEP.MYPERL.REL := 1
DEP.MYPERL.GITURI := /git/myperl
DEP.MYPERL.GITDIR := $(HOME)/git/myperl

TARGET_ARCH := $(shell rpmbuild --eval='%{_target_cpu}' 2>/dev/null)

PERL_SRCBASE := http://ftp.gwdg.de/pub/languags/perl/CPAN/src/5.0
PERL_SRCBASE := http://www.cpan.org/src/5.0
PERL_TARBALL := perl-$(DEP.MYPERL.VER).tar.bz2

OPENXPKI.GITURI := /git/openxpki
OPENXPKI.GITDIR := $(HOME)/git/openxpki
OPENXPKI.VER := $(shell cd $(OPENXPKI.GITDIR) && $(OPENXPKI.GITDIR)/tools/vergen --format version)

#CODE_DIR := $(HOME)/git/openxpki
#CODE_VER := $(shell cd $(CODE_DIR) && $(CODE_DIR)/tools/vergen --format version)

CONF_DIR := $(HOME)/git/config
CONF_VER := $(shell cd $(CONF_DIR) && $(OPENXPKI.GITDIR)/tools/vergen --format version)

DEP.CRYPT_ECDH.GITURI := /git/crypt-ecdh
DEP.CRYPT_ECDH.GITDIR := $(HOME)/git/crypt-ecdh


# The TARGET_ALIASES are the short alias names for each of the
# packages to be built

TARGET_ALIASES := myperl myperl-buildtools myperl-inline-c myperl-fcgi myperl-openxpki-core-deps myperl-openxpki-core myperl-openxpki-i18n

VAGRANT_RPMS := \
	$(patsubst %,/vagrant/rpms/%,\
	myperl-$(DEP.MYPERL.VER)-$(DEP.MYPERL.REL).$(TARGET_ARCH).rpm \
	myperl-apache-mod-perl-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm \
	myperl-apache-controller-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm \
	myperl-inline-c-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm \
	myperl-fcgi-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm \
	myperl-openxpki-core-deps-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm \
	myperl-openxpki-i18n-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm \
	)

RPMBUILD_RPMS := \
	$(patsubst /vagrant/rpms/%,$(HOME)/rpmbuild/RPMS/$(TARGET_ARCH)/%,$(VAGRANT_RPMS))

# $(call assert,condition,message)
define assert
  $(if $1,,$(error Assertion failed: $2))
endef
# $(call assert-not-installed,rpm-name)
define assert-not-installed
	@rpm -qi --quiet $1; test $$? = 1 || \
		(echo "ERROR: $1 already installed"; exit 1)
endef

define filename-to-packagename
$(patsubst %-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm,%,$(notdir $1))
endef

.PHONY: help
help:
	@echo "The following make targets are available: "
	@echo 
	@$(MAKE) -f $(CURRENT_MAKEFILE)						\
	   	--print-data-base --question no-such-target		\
		2>&1 |											\
	$(GREP) -v -e 'no-such-target' -e '^makefile' |	\
	$(AWK) '/^[^.%][-A-Za-z0-9_]*:/						\
		{ print substr($$1, 1, length($$1)-1) }' |		\
	$(SORT) |											\
	$(PR) --omit-pagination --width=80 --columns=4

info:
	@echo "MAKE=$(MAKE)"
	@echo "GREP=$(GREP)"
	@echo "AWK=$(AWK)"
	@echo "SORT=$(SORT)"
	@echo "PR=$(PR)"
	@echo "MAKEFILE_LIST=$(MAKEFILE_LIST)"

debug:
	@echo "OPENXPKI.GITDIR = $(OPENXPKI.GITDIR)"
	@echo "OPENXPKI.VER = $(OPENXPKI.VER)"
	@echo "CONF_DIR = $(CONF_DIR)"
	@echo "CONF_VER = $(CONF_VER)"
	@echo "VAGRANT_RPMS = $(VAGRANT_RPMS)"
	@echo "RPMBUILD_RPMS = $(RPMBUILD_RPMS)"
	@echo "CPANM_MIRROR (env) = $$CPANM_MIRROR"

#all: $(VAGRANT_RPMS)
all: $(TARGET_ALIASES)

clean:
	cd $(DEP.MYPERL.GITDIR) && make suse-clean
	rm -rf $(VAGRANT_RPMS) $(RPMBUILD_RPMS)
	-sudo rpm -e myperl

# This helper takes care of cloning all the needed repos
git-clone: $(DEP.MYPERL.GITDIR) $(OPENXPKI.GITDIR) $(DEP.KEYNANNY.GITDIR) 

$(DEP.MYPERL.GITDIR):
	git clone $(DEP.MYPERL.GITURI) $(DEP.MYPERL.GITDIR)

$(OPENXPKI.GITDIR):
	git clone $(OPENXPKI.GITURI) $(OPENXPKI.GITDIR)

$(DEP.KEYNANNY.GITDIR):
	git clone $(DEP.KEYNANNY.GITURI) $(DEP.KEYNANNY.GITDIR)

git-pull:
	cd $(DEP.MYPERL.GITDIR) && git pull --ff-only
	cd $(OPENXPKI.GITDIR) && git pull --ff-only
	cd $(DEP.KEYNANNY.GITDIR) && git pull --ff-only

myperl: /vagrant/rpms/myperl-$(DEP.MYPERL.VER)-$(DEP.MYPERL.REL).$(TARGET_ARCH).rpm

ifdef USE_PINTO
$(PINTO_DIR)/$(PERL_TARBALL):
	wget -O $@ $(PERL_SRCBASE)/$(PERL_TARBALL)

$(PINTO_DIR)/cpanm:
	wget -O $@ https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm

$(DEP.MYPERL.GITDIR)/$(PERL_TARBALL): $(PINTO_DIR)/$(PERL_TARBALL)
	cp -a $< $@

$(DEP.MYPERL.GITDIR)/cpanm: $(PINTO_DIR)/cpanm
	cp -a $< $@
endif

/vagrant/rpms:
	mkdir $@

/vagrant/rpms/myperl-$(DEP.MYPERL.VER)-$(DEP.MYPERL.REL).$(TARGET_ARCH).rpm: \
		/vagrant/rpms \
		$(DEP.MYPERL.GITDIR) 
	$(call assert-not-installed,myperl)
	cd $(DEP.MYPERL.GITDIR) && make fetch-perl suse
	cp $(HOME)/rpmbuild/RPMS/$(TARGET_ARCH)/$(notdir $@) $@
	$(SUDO) rpm -ivh --oldpackage --replacepkgs $@

ifdef USE_PINTO
/vagrant/rpms/myperl-$(DEP.MYPERL.VER)-$(DEP.MYPERL.REL).$(TARGET_ARCH).rpm: \
		$(DEP.MYPERL.GITDIR)/$(PERL_TARBALL) \
		$(DEP.MYPERL.GITDIR)/cpanm 
endif

myperl-buildtools: /vagrant/rpms/myperl-buildtools-$(DEP.MYPERL.VER)-$(DEP.MYPERL.REL).$(TARGET_ARCH).rpm

/vagrant/rpms/myperl-buildtools-$(DEP.MYPERL.VER)-$(DEP.MYPERL.REL).$(TARGET_ARCH).rpm:
	$(call assert-not-installed,$(call filename-to-packagename,myperl-buildtools))
	$(call assert,$(OPENXPKI.VER),Need to run 'git-clone' target)
	cd $(OPENXPKI.GITDIR)/package/suse/$(call filename-to-packagename,myperl-buildtools) && \
		PERL5LIB=\$$HOME/perl5/lib/perl5/ make
	cp $(HOME)/rpmbuild/RPMS/$(TARGET_ARCH)/$(notdir $@) $@
	$(SUDO) rpm -ivh --oldpackage --replacepkgs $@
	

# Plan-B
plan-b: /vagrant/rpms/myperl-openxpki-client-html-mason-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm

.PHONY: myperl-apache-mod-perl myperl-apache-controller myperl-inline-c myperl-fcgi myperl-dbd-oracle

myperl-apache-mod-perl: /vagrant/rpms/myperl-apache-mod-perl-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm
myperl-apache-controller: /vagrant/rpms/myperl-apache-controller-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm
myperl-inline-c: /vagrant/rpms/myperl-inline-c-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm
myperl-fcgi: /vagrant/rpms/myperl-fcgi-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm
myperl-dbd-oracle: /vagrant/rpms/myperl-dbd-oracle-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm
myperl-openxpki-core-deps: /vagrant/rpms/myperl-openxpki-core-deps-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm
myperl-openxpki-core: /vagrant/rpms/myperl-openxpki-core-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm
myperl-openxpki-i18n: /vagrant/rpms/myperl-openxpki-i18n-$(OPENXPKI.VER)-1.$(TARGET_ARCH).rpm

%.rpm: $(OPENXPKI.GITDIR)
	$(call assert-not-installed,$(call filename-to-packagename,$@))
	$(call assert,$(OPENXPKI.VER),Need to run 'git-clone' target)
	cd $(OPENXPKI.GITDIR)/package/suse/$(call filename-to-packagename,$@) && \
		PERL5LIB=\$$HOME/perl5/lib/perl5/ make
	cp $(HOME)/rpmbuild/RPMS/$(TARGET_ARCH)/$(notdir $@) $@
	$(SUDO) rpm -ivh $@

myperl-crypt-ecdh: myperl-crypt-ecdh-$(OXI_VERSION)-1.$(TARGET_ARCH).rpm

myperl-crypt-ecdh-$(OXI_VERSION)-1.$(TARGET_ARCH).rpm: $(DEP.CRYPT_ECDH.GITDIR)
	for i in $(OPENXPKI.GITDIR)/.VERSION_*; do \
		cd $(CONFIG.GITDIR)/package/suse/myperl-crypt-ecdh && ln -sf $$i;\
	done
	cd $(CONFIG.GITDIR)/package/suse/myperl-crypt-ecdh \
		&& PERL5LIB=\$$HOME/perl5/lib/perl5/ make



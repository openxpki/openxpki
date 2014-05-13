#!/usr/bin/make -f
#
# vag-build.mk - build oxi packages using vagrant instances
#
# This makefile helps automate the package build process for openxpki. It
# is designed to use Vagrant with two instances: 'build' and 'test'.
#
#
# USAGE:
#
# After setting up your Vagrant environment (see below), just run the
# following to create the oxi RPM packages (in the current directory):
#
# 	./vag-build.mk
#
# When done, you can run the following to clean everything up (the
# 'destroy' target will run 'vagrant destroy' in your Vagrant directory):
#
#   ./vag-build.mk destroy clean
#
# Set PERL_SKIP_TEST=1 to skip the Perl and CPAN tests
#
# PREREQUISITES:
#
# Obviously, you must have Vagrant installed and a SuSE SLES-11 SP3 'box'
# that is either pre-boxed or provisioned with the various build prereqs.
#
# To simplify the build, you'll need some shared folders defined in your
# Vagrantfile to map the following directories in your build instance:
#
# 	/vagrant		This one is done automatically by Vagrant
# 	/code-repo		Point this one to your oxi working repo
# 					(e.g: ~/git/openxpki)
#	/inst.images	The directory containing SuSE SLES-11 SP3 RPM packages
#	/mirrors		Directory containing cache of Perl/CPAN archives
#
# In my setup, I have a Vagrant shared folder that points to the DVD
# directory and I run the following (in the 'build' instance):
#
#   SLESSP3=/inst.images/<dir-with-sles-sp3>
#   SDKSP3=/inst.images/<dir-with-sles-sdk-sp3>
#   rpm -Uv --oldpackage $SLESSP3/openssl-0.9.*.rpm 
#	rpm -Uv $SLESSP3/zlib-1.2.7*.rpm $SDKSP3/zlib-devel-1.2.7*.rpm
#	rpm -Uv $SLESSP3/libopenssl0_9_8-0.9.*.rpm $SDKSP3/libopenssl-devel-0.9.8*.rpm
#	rpm -Uv $SDKSP3/perl-Error-0.17015-*.rpm $SDKSP3/perl-File-HomeDir*.rpm $SDKSP3/perl-AppConfig*.rpm $SDKSP3/perl-Template-Toolkit*.rpm
#	rpm -Uv $SDKSP3/libexpat-devel-*.rpm
#	rpm -Uv $SLESSP3/cvs-1*.rpm $SLESSP3/gettext-tools-*.rpm
#	rpm -Uv $SDKSP3/git-core-1.7.12.*.rpm
#
# I also fix up the RPM Build configuration (in the 'build' instance):
#
#	if [ ! -d ~vagrant/.rpmbuild ]; then
#		mkdir -p ~vagrant/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
#		chown -R vagrant.users ~vagrant/rpmbuild
#	fi
#
#	if [ ! -f ~vagrant/.rpmmacros ]; then
#		echo '%_topdir %(echo $HOME)/rpmbuild' > ~vagrant/.rpmmacros
#		chown vagrant.users ~vagrant/.rpmmacros
#	fi
#
# Lastly, I install a couple of CPAN modules needed for the oxi build
# (in the 'build' instance):
#
#	mkdir -p ~/cpan-inst
#
#	perl -MClass::Std -e 1 2>/dev/null
#	if [ $? != 0 ]; then
#		echo "Need install of 'Class::Std'"
#	    if [ ! -f /mirrors/perl/Class-Std-0.011.tar.gz ]; then
#	        mkdir -p /mirrors/perl
#	        wget -O /mirrors/perl/Class-Std-0.011.tar.gz http://cpan.metacpan.org/authors/id/D/DC/DCONWAY/Class-Std-0.011.tar.gz
#	    fi
#		(cd ~/cpan-inst && tar -xzf /mirrors/perl/Class-Std-0.011.tar.gz && cd Class-Std-0.011 && perl Makefile.PL && make install)
#	fi
#	
#	perl -MConfig::Std -e 1 2>/dev/null
#	if [ $? != 0 ]; then
#		echo "Need install of 'Config::Std'"
#	    if [ ! -f /mirrors/perl/Config-Std-0.901.tar.gz ]; then
#	        mkdir -p /mirrors/perl
#	        wget -O /mirrors/perl/Config-Std-0.901.tar.gz http://cpan.metacpan.org/authors/id/B/BR/BRICKER/Config-Std-0.901.tar.gz
#	    fi
#		(cd ~/cpan-inst && tar -xzf /mirrors/perl/Config-Std-0.901.tar.gz && cd Config-Std-0.901 && perl Makefile.PL && make install)
#	fi
#	
#

#################################################################
# LOCAL CONFIGURATION
#
# Override these in your own vag-build.mk.local, if necessary
#################################################################

# Path to your Vagrant directory (e.g.: location of Vagrantfile)
VAG_DIR := ../../vagrant/suse
PKG_VER := $(shell ../../tools/vergen --format "MAJOR.MINOR.RELEASE-PKGREL")
VAG_PROVIDER := virtualbox
CODE_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
DEP_PATH := /usr/share/openxpki-perldeps-core/CURRENT/bin

-include vag-build.mk.local

#################################################################
# VARIABLES (SHOULDN'T NEED MODIFICATIONS)
#################################################################

OXI_PERLDEP_RPM = openxpki-perldeps-core-$(PKG_VER).x86_64.rpm
OXI_CORE_RPM = perl-openxpki-core-$(PKG_VER).x86_64.rpm
OXI_I18N_RPM = openxpki-i18n-$(PKG_VER).x86_64.rpm
OXI_MASON_RPM = perl-openxpki-client-html-mason-$(PKG_VER).x86_64.rpm

#RPMS := $(patsubst %,$(VAG_DIR)/%,$(OXI_PERLDEP_RPM) $(OXI_CORE_RPM) $(OXI_I18N_RPM) $(OXI_MASON_RPM))
RPMS := $(OXI_PERLDEP_RPM) $(OXI_CORE_RPM) $(OXI_I18N_RPM) $(OXI_MASON_RPM)
STATES := $(patsubst %,$(VAG_DIR)/%,.code-repo.state .perldeps-inst.state .oxicore-inst.state .oxii18n-inst.state .oximason-inst.state)
VAG_INSTANCES := build test
SSH_CFGS = $(patsubst %,$(VAG_DIR)/%.sshcfg,$(VAG_INSTANCES))
VAG_ID_FILES := $(patsubst %,$(VAG_DIR)/.vagrant/machines/%/$(VAG_PROVIDER)/id,$(VAG_INSTANCES))

all: $(RPMS)

info:
	@echo "PKG_VER = $(PKG_VER)"

########################################
# VAGRANT OPERATIONS
########################################

.PRECIOUS: $(VAG_ID_FILES)

# Create the Vagrant instance(s)
$(VAG_DIR)/.vagrant/machines/%/$(VAG_PROVIDER)/id:
	cd $(VAG_DIR) && vagrant up $*

# Create the .sshcfg for each instance
$(VAG_DIR)/%.sshcfg: $(VAG_DIR)/.vagrant/machines/%/$(VAG_PROVIDER)/id
	(cd $(VAG_DIR) && vagrant ssh-config $*) > $@.tmp
	mv $@.tmp $@

# convenience target for ssh session to configured instances
ssh-%: $(VAG_DIR)/%.sshcfg
	ssh -F $(VAG_DIR)/$*.sshcfg $*

destroy:
	cd $(VAG_DIR) && vagrant destroy

fdestroy:
	cd $(VAG_DIR) && vagrant destroy -f

########################################
# PACKAGE BUILD
########################################

$(VAG_DIR)/.code-repo.state: $(VAG_DIR)/build.sshcfg
	ssh -F $(VAG_DIR)/build.sshcfg build \
		"git clone --single-branch --depth=1 --branch=$(CODE_BRANCH) file:///code-repo ~/git/openxpki"
	touch $@

$(OXI_PERLDEP_RPM): $(VAG_DIR)/build.sshcfg $(VAG_DIR)/.code-repo.state
	ssh -F $(VAG_DIR)/build.sshcfg build "cd ~/git/openxpki/package/suse/openxpki-perldeps-core && make CPAN_MIRROR_DIR=$(CPAN_MIRROR_DIR) CPAN_ADDON=\"$(CPAN_ADDON)\" PERL_SKIP_TEST=$(PERL_SKIP_TEST)"
	scp -F $(VAG_DIR)/build.sshcfg build:rpmbuild/RPMS/x86_64/$(OXI_PERLDEP_RPM) $@

$(VAG_DIR)/.perldeps-inst.state: $(VAG_DIR)/build.sshcfg $(OXI_PERLDEP_RPM)
	ssh -F $(VAG_DIR)/build.sshcfg build "sudo rpm -Uvh rpmbuild/RPMS/x86_64/openxpki-perldeps-core-$(PKG_VER).x86_64.rpm"
	touch $@

$(OXI_CORE_RPM): $(VAG_DIR)/build.sshcfg $(VAG_DIR)/.perldeps-inst.state
	ssh -F $(VAG_DIR)/build.sshcfg build \
		"cd ~/git/openxpki/package/suse/perl-openxpki-core && PATH=$(DEP_PATH):\$$PATH make"
	scp -F \
		$(VAG_DIR)/build.sshcfg build:git/openxpki/package/suse/perl-openxpki-core/$(OXI_CORE_RPM) \
		$@

$(VAG_DIR)/.oxicore-inst.state: $(VAG_DIR)/build.sshcfg $(OXI_CORE_RPM)
	ssh -F $(VAG_DIR)/build.sshcfg build "sudo rpm -Uvh git/openxpki/package/suse/perl-openxpki-core/$(OXI_CORE_RPM)"
	touch $@

$(OXI_I18N_RPM): $(VAG_DIR)/build.sshcfg $(VAG_DIR)/.perldeps-inst.state
	ssh -F $(VAG_DIR)/build.sshcfg build \
		"cd ~/git/openxpki/package/suse/openxpki-i18n && PATH=$(DEP_PATH):\$$PATH make"
	scp -F \
		$(VAG_DIR)/build.sshcfg build:git/openxpki/package/suse/openxpki-i18n/$(OXI_I18N_RPM) \
		$@

$(VAG_DIR)/.oxii18n-inst.state: $(VAG_DIR)/build.sshcfg $(OXI_I18N_RPM)
	ssh -F $(VAG_DIR)/build.sshcfg build "sudo rpm -Uvh git/openxpki/package/suse/openxpki-i18n/$(OXI_I18N_RPM)"
	touch $@

$(OXI_MASON_RPM): $(VAG_DIR)/build.sshcfg $(VAG_DIR)/.oxicore-inst.state
	ssh -F $(VAG_DIR)/build.sshcfg build \
		"cd ~/git/openxpki/package/suse && PATH=$(DEP_PATH):\$$PATH make perl-openxpki-client-html-mason"
	scp -F \
		$(VAG_DIR)/build.sshcfg build:git/openxpki/package/suse/perl-openxpki-client-html-mason/$(OXI_MASON_RPM) \
		$@

$(VAG_DIR)/.oximason-inst.state: $(VAG_DIR)/build.sshcfg $(OXI_MASON_RPM)
	ssh -F $(VAG_DIR)/build.sshcfg build "sudo rpm -Uvh git/openxpki/package/suse/perl-openxpki-client-html-mason/$(OXI_MASON_RPM)"
	touch $@

clean:
	rm -rf $(RPMS) $(STATES) $(SSH_CFGS) 

# Helper targets
.PHONY: perldep core i18n mason test
perldep: $(OXI_PERLDEP_RPM)
core: $(OXI_CORE_RPM)
i18n: $(OXI_I18N_RPM)
mason: $(OXI_MASON_RPM)
test: $(VAG_DIR)/.oxii18n-inst.state $(VAG_DIR)/.oximason-inst.state

########################################
# DEBUGGING STUFF
########################################

git-status: $(VAG_DIR)/build.sshcfg
	ssh -F $(VAG_DIR)/build.sshcfg build "cd ~/git/openxpki && git status"

########################################
# INSTALL PACKAGES ON TEST INSTANCE
########################################

# Install packages on 'test'
inst-test: $(VAG_DIR)/test.sshcfg $(RPMS)
	ssh -F $(VAG_DIR)/test.sshcfg test "sudo /usr/sbin/groupadd openxpki"
	ssh -F $(VAG_DIR)/test.sshcfg test "sudo /usr/sbin/useradd -m -g openxpki openxpki"
	ssh -F $(VAG_DIR)/test.sshcfg test "cd /vagrant && sudo rpm -ivh $(RPMS)"

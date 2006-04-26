#
# OpenXPKI Deployment Makefile
#
# Written by Martin Bartosch for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 80 $
#

BINDIR        = [% dir.bindir %]
SYSCONFDIR    = [% dir.sysconfdir %]
INSTALLPREFIX = [% dir.installprefix %]
PERLLIB       = [% dir.perllib %]

CFG           = bin/openxpki-metaconf
INSTALL       = /usr/bin/install
CONFIGFILE    = etc/openxpki.conf

###########################################################################
# no user serviceable parts below this line

RUNUSER    = [% server.runuser %]
RUNGROUP   = [% server.rungroup %]
ADMUSER    = [% server.admuser %]
ADMGROUP   = [% server.admgroup %]

ifneq ($(shell id -nu), 'root')
	RUNUSER  = $(shell id -nu)
	RUNGROUP = $(shell id -ng)
	ADMUSER  = $(shell id -nu)
	ADMGROUP = $(shell id -ng)
	NONROOT  = 1
endif

###########################################################################

all: help summary

#
# OpenXPKI Deployment Makefile
#
# Written by Martin Bartosch for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 80 $
#

BINDIR        = [% dir.bindir %]
SYSCONFDIR    = [% dir.sysconfdir %]
INSTALLPREFIX = [% dir.installprefix %]
PERLLIB       = [% dir.perllib %]

STATEDIR      = [% dir.openxpkistatedir %]
SESSIONDIR    = [% dir.openxpkisessiondir %]

CFG           = bin/openxpki-metaconf
INSTALL       = /usr/bin/install
CONFIGFILE    = etc/openxpki.conf

###########################################################################
# no user serviceable parts below this line

RUNUSER    = [% server.runuser %]
RUNGROUP   = [% server.rungroup %]
ADMUSER    = [% server.admuser %]
ADMGROUP   = [% server.admgroup %]

ifneq ($(shell id -nu), 'root')
	RUNUSER  = $(shell id -nu)
	RUNGROUP = $(shell id -ng)
	ADMUSER  = $(shell id -nu)
	ADMGROUP = $(shell id -ng)
	NONROOT  = 1
endif

###########################################################################

all: help summary

checkuser:
	@if [ "$(NONROOT)" = "1" ] ; then \
		echo ; \
		echo "NOTE: You are not root." ; \
		echo "I will try to proceed to install the system anyway using your UID $(RUNUSER)" ; \
		echo ; \
	fi

install: checkuser makedirs installetc installbin postinstallhelp

installbin:
	@echo Installing binary files to $(INSTALLPREFIX)$(BINDIR)
	$(INSTALL) -o $(ADMUSER) -g $(ADMGROUP) -m 0750 -d $(INSTALLPREFIX)$(BINDIR)
	$(INSTALL) -o $(ADMUSER) -g $(ADMGROUP) -m 0755 bin/openxpki-metaconf $(INSTALLPREFIX)$(BINDIR)/openxpki-metaconf
	$(CFG) --config openxpki.conf --force --file bin/openxpkictl --dstdir $(INSTALLPREFIX)$(BINDIR)
	chown $(ADMUSER):$(ADMGROUP) $(INSTALLPREFIX)$(BINDIR)/openxpkictl
	chmod 0755 $(INSTALLPREFIX)$(BINDIR)/openxpkictl
	$(CFG) --config openxpki.conf --force --file bin/openxpki-configure --dstdir $(INSTALLPREFIX)$(BINDIR)
	chown $(ADMUSER):$(ADMGROUP) $(INSTALLPREFIX)$(BINDIR)/openxpki-configure
	chmod 0755 $(INSTALLPREFIX)$(BINDIR)/openxpki-configure

installetc:
	@echo Installing configuration files to $(INSTALLPREFIX)$(SYSCONFDIR)
	$(INSTALL) -o $(ADMUSER) -g $(ADMGROUP) -m 0750 -d $(INSTALLPREFIX)$(SYSCONFDIR)
	$(CFG) --config openxpki.conf --delcfgvalue dir.installprefix --writecfg $(INSTALLPREFIX)$(SYSCONFDIR)/openxpki.conf
	chown $(ADMUSER):$(ADMGROUP) $(INSTALLPREFIX)$(SYSCONFDIR)/openxpki.conf
	chmod 640 $(INSTALLPREFIX)$(SYSCONFDIR)/openxpki.conf
	$(INSTALL) -o $(ADMUSER) -g $(ADMGROUP) -m 0755 -d $(INSTALLPREFIX)$(SYSCONFDIR)/templates
	@( cd etc && for template in templates/* ; do \
		$(INSTALL) -o $(ADMUSER) -g $(ADMGROUP) -m 0755 -d $(INSTALLPREFIX)$(SYSCONFDIR)/$$template || exit 1 ;\
		for file in $$template/*.xml $$template/*.conf ; do \
			$(INSTALL) -o $(ADMUSER) -g $(ADMGROUP) -m 0644 $$file $(INSTALLPREFIX)$(SYSCONFDIR)/$$template/`basename $$file` || exit 1 ; \
		done ; \
	done )

makedirs:
	@echo Creating state directories
	$(INSTALL) -o $(RUNUSER) -g $(RUNGROUP) -m 0755 -d $(STATEDIR)
	$(INSTALL) -o $(RUNUSER) -g $(RUNGROUP) -m 0700 -d $(SESSIONDIR)

clean:
	rm -f Makefile openxpki.conf

help:
	@echo "OpenXPKI Deployment Tool"
	@echo
	@echo "Usage:"
	@echo "make install      - install system files"
	@echo

postinstallhelp:
	@echo
	@echo "Installation complete"
	@echo
	@echo "You will now have to generate the PKI-specific configuration."
	@echo "Please run the following commands:"
	@echo
	@echo "cd $(SYSCONFDIR)"
	@echo "./openxpki-configure"
	@echo

summary:
	@echo "Installation summary:"
	@echo
	@echo "Readonly file and directory ownership: $(ADMUSER):$(ADMGROUP)"
	@echo "OpenXPKI daemon runtime user:          $(RUNUSER):$(RUNGROUP)"
	@echo
	@echo "Installation directories:"
	@echo "BINDIR:                  $(BINDIR)"
	@echo "Configuration directory: $(SYSCONFDIR)"

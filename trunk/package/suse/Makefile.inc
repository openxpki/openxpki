## Written 2011 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2011 by The OpenXPKI Project

# Common definitions for all SuSE package Makefiles
# NOTE: You may create a file called Makefile.local in this directory
# to override any of these settings!

# common includes for package builds
include $(TOPDIR)/trunk/package/common/Makefile.inc

# standard directory for RPM builds, to override this use Makefile.local
RPMBASE=/usr/src/packages

ifdef PREFIX
PERL_MAKEPL_ARGS="PREFIX=$(PREFIX)"
endif


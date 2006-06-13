# file: src/scripts/Makefile
#
# © 2006 The OpenXPKI Project

#FIXME what is with DEST_DIR

INSTALL = /usr/bin/install -c

prefix = /Users/martin/local
exec_prefix = /Users/martin/local

DEST_BINDIR     = $(DESTDIR)${exec_prefix}/bin
DEST_MANDIR     = $(DESTDIR)${prefix}/man
DEST_SYSCONFDIR = $(DESTDIR)${prefix}/etc
DEST_TEMPLATEDIR = $(DESTDIR)${prefix}/etc/openxpki/templates

DEST_DIRS = $(DEST_BINDIR) $(DEST_MANDIR) $(DEST_SYSCONFDIR)

CONF_DIRS = \
	$(DEST_TEMPLATEDIR)

PROGS =	\
	openxpki-configure	\
	openxpki-metaconf	\
	openxpkiadm		\
	openxpkictl

TEMPLATEDIR = etc/templates

TEMPLATES = default

#---- variable settings above, rules below ----

.PHONY:	default install

default:	build-man

build-man:
	mkdir -p man
	for PROG in $(PROGS); do pod2man bin/$$PROG man/$$PROG.1; done

install:	install-progs install-templates

install-progs:	$(DEST_BINDIR)
	for PROG in $(PROGS); do \
		$(INSTALL) -m 755 bin/$$PROG $(DEST_BINDIR)/$$PROG; \
		$(INSTALL) -m 644 man/$$PROG.1 $(DEST_MANDIR)/man1/$$PROG.1; \
	done

install-templates:	$(CONF_DIRS)
	for TEMPLATE in $(TEMPLATES) ; do \
		$(INSTALL) -d -m 755 $(DEST_TEMPLATEDIR)/$$TEMPLATE || exit 1; \
		for FILE in `ls $(TEMPLATEDIR)/$$TEMPLATE`; do \
			$(INSTALL) -m 644 $(TEMPLATEDIR)/$$TEMPLATE/$$FILE $(DEST_TEMPLATEDIR)/$$TEMPLATE; \
		done ; \
	done

$(DEST_DIRS) $(CONF_DIRS):
	$(INSTALL) -d -m 755 $@

clean::
	$(RM) -f man/*
	$(RMDIR) -f man

distclean::
	$(RM) -f man/*
	$(RMDIR) -f man

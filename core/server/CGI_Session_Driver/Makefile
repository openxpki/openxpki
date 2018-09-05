PREFIX?=	/usr
INSTALL_DIR =  $(DESTDIR)$(PREFIX)/share/perl5/CGI/Session/Driver
INSTALL      = install
VERSION_FILE    = ./VERSION
PACKAGE      ?= openxpki-cgi-session-driver

TOPDIR := ../../../

# In package build, tools/vergen isn't available
-include $(TOPDIR)/package/common/vergen.mk

#---- variable settings above, rules below ----

.PHONY:	default install clean

default:: dist

install::
	$(MAKE) install_dir DIR=$(INSTALL_DIR)
	cp *.pm $(INSTALL_DIR)

install_dir:
	@if (test ! -d $(DIR)); then \
		$(INSTALL) -m 755 -d $(DIR); \
	else \
		echo directory already exists; \
	fi

clean::
	rm -f *tgz

writeversion:
	@  if version=$$($(VERGEN) --format version 2>/dev/null); then \
		echo "$$version" > $(VERSION_FILE); \
		fi
	@( if (test ! -f $(VERSION_FILE) ) ; then \
		echo "Could not determine version" ; \
		exit 1; \
	fi )

readversion: writeversion
VERSION=$(shell cat $(VERSION_FILE))

dist: readversion
	if (test -d $(PACKAGE)-$(VERSION)) ; then \
		rm -rf $(PACKAGE)-$(VERSION)/ ; \
	fi
	mkdir $(PACKAGE)-$(VERSION)
	tar -c -p -f - \
		--exclude "$(PACKAGE)-*" \
		. | \
		tar -C $(PACKAGE)-$(VERSION)/ -x -f -
	tar cf $(PACKAGE)-$(VERSION).tar $(PACKAGE)-$(VERSION)
	gzip --best --force $(PACKAGE)-$(VERSION).tar
	rm -rf $(PACKAGE)-$(VERSION)/


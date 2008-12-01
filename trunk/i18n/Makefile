VERGEN = ../../tools/vergen
PREFIX?=	/usr
LOCALE_DIR   = $(DESTDIR)$(PREFIX)/share/locale
MO_FILE      = openxpki.mo
INSTALL      = install
LANGS         = en_US en_GB de_DE ru_RU
PO_SOURCES   = $(LANGS:%=%/openxpki.po)
MO_TRANSLATIONS = $(LANGS:%=%/$(MO_FILE))
POT_SOURCES  = ../perl-modules/core/trunk ../clients/perl/OpenXPKI-Client ../clients/perl/OpenXPKI-Client-SCEP ../clients/perl/OpenXPKI-Client-HTML-Mason ../deployment
VERSION_FILE    = ./VERSION

#---- variable settings above, rules below ----

.PHONY:	default test install clean clean.local distclean openxpki.pot

default::	$(MO_TRANSLATIONS)
	@echo Languages: $(LANGS)

$(PO_SOURCES)::
	@if (test ! -d $(@:openxpki.po=)); then echo creating directory for $(@:openxpki.po=); mkdir $(@:openxpki.po=); fi
	@if (test ! -f $@); then echo creating po file $@; cp openxpki.pot $@; fi
	@if (test `uname` = "SunOS"); then \
                gmsgmerge -s --update $@ openxpki.pot; \
	else \
		msgmerge -s --update $@ openxpki.pot; \
	fi
	@rm -f $@~
	@perl convert.pl $@ > $@_utf8 2>/dev/null
	@if (test ! -z "`diff $@ $@_utf8`"); then echo no utf8; exit 1; fi
	@rm -f $@_utf8

## do not depend on openxpki.pot or some directories - this does not work
scan:
	perl build-pot.pl $(POT_SOURCES) > openxpki.pot
	$(MAKE) $(PO_SOURCES)

install::	$(LANGS)
	$(MAKE) install_dir DIR=$(LOCALE_DIR)
	@set -e; for lang in $(LANGS); do \
		$(MAKE) install_dir DIR=$(LOCALE_DIR)/$$lang; \
		$(MAKE) install_dir DIR=$(LOCALE_DIR)/$$lang/LC_MESSAGES; \
		if (test `uname` = "SunOS"); then \
			$(INSTALL) -m 644 -f $(LOCALE_DIR)/$$lang/LC_MESSAGES $$lang/$(MO_FILE); \
		else \
		        $(INSTALL) -m 644 $$lang/$(MO_FILE) $(LOCALE_DIR)/$$lang/LC_MESSAGES/$(MO_FILE); \
		fi \
	done

install_dir:
	@if (test ! -d $(DIR)); then \
		$(INSTALL) -m 755 -d $(DIR); \
	else \
		echo directory already exists; \
	fi

.SUFFIXES: .mo .po

.po.mo:
	@if (test -f $<.local)  ; then \
		echo "Using local file" ; \
		msgcat --use-first $<.local $< | msgfmt -o $@ - ; \
	else \
		msgfmt -o $@ $< ; \
	fi

test install clean distclean::

clean::
	rm -f */*.po~

distclean:: clean
	rm -f *.pot */*.mo

writeversion:
	@( if (test -f $(VERGEN)) ; then \
		$(VERGEN) --format version > $(VERSION_FILE); \
	fi )
	@( if (test ! -f $(VERSION_FILE) ) ; then \
		echo "Could not determine version" ; \
		exit 1; \
	fi )

readversion: writeversion
VERSION=$(shell cat $(VERSION_FILE))

#dist:	VERSION=`$(VERGEN) --format version`
dist: readversion
	if (test -d openxpki-i18n-$(VERSION)) ; then \
		rm -rf openxpki-i18n-$(VERSION)/ ; \
	fi
	mkdir openxpki-i18n-$(VERSION)
	tar -c -p -f - \
		--exclude "*.svn" \
		--exclude "openxpki-i18n-*" \
		--exclude "*.1" \
		--exclude "*~" \
		. | \
		tar -C openxpki-i18n-$(VERSION)/ -x -f -
	tar cf openxpki-i18n-$(VERSION).tar openxpki-i18n-$(VERSION)
	gzip --best --force openxpki-i18n-$(VERSION).tar
	rm -rf openxpki-i18n-$(VERSION)/



OPENXPKI_MAJOR_VERSION = "0.9"
PREFIX?=	/usr
LOCALE_DIR   = $(DESTDIR)$(PREFIX)/share/locale
MO_FILE      = openxpki.mo
INSTALL      = install
LANGS         = en_GB de_DE
PO_SOURCES   = $(LANGS:%=%/openxpki.po)
MO_TRANSLATIONS = $(LANGS:%=%/$(MO_FILE))
POT_SOURCES  = ../perl-modules ../clients ../deployment

#---- variable settings above, rules below ----

.PHONY:	default test install clean clean.local distclean openxpki.pot

default::	$(MO_TRANSLATIONS)
	@echo Languages: $(LANGS)

$(PO_SOURCES):	openxpki.pot
	@if (test ! -d $(@:openxpki.po=)); then echo creating directory for $(@:openxpki.po=); mkdir $(@:openxpki.po=); fi
	@if (test ! -e $@); then echo creating po file $@; cp openxpki.pot $@; fi
	msgmerge --update $@ openxpki.pot
	@rm -f $@~
	@perl convert.pl $@ > $@_utf8 2>/dev/null
	@if (test ! -z `diff $@ $@_utf8`); then echo no utf8; exit 1; fi
	@rm -f $@_utf8

## do not depend on openxpki.pot or some directories - this does not work
scan:
	sh build-pot.sh $(POT_SOURCES) > openxpki.pot
	make $(PO_SOURCES)

install::	$(LANGS)
	make install_dir DIR=$(LOCALE_DIR)
	set -e; for lang in $(LANGS); do \
		make install_dir DIR=$(LOCALE_DIR)/$$lang; \
		make install_dir DIR=$(LOCALE_DIR)/$$lang/LC_MESSAGES; \
		$(INSTALL) -m 644 $$lang/$(MO_FILE) $(LOCALE_DIR)/$$lang/LC_MESSAGES/$(MO_FILE); \
	done

install_dir:
	@if (test ! -d $(DIR)); then \
		$(INSTALL) -m 755 -d $(DIR); \
	else \
		echo directory already exists; \
	fi

.SUFFIXES: .mo .po

.po.mo:
	msgfmt -o $@ $<

test install clean distclean::

distclean clean::
	rm -f */*.po~

dist:	REVISION=${OPENXPKI_MAJOR_VERSION}.`svn info | grep Revision | awk '{ print $$2 }'`
dist:
	if [ -d openxpki-i18n-$(REVISION) ] ; then \
		rm -rf openxpki-i18n-$(REVISION)/ ; \
	fi
	mkdir openxpki-i18n-$(REVISION)
	tar -c -p -f - \
		--exclude "*.svn" \
		--exclude "openxpki-i18n-*" \
		--exclude "*.1" \
		--exclude "*~" \
		. | \
		tar -C openxpki-i18n-$(REVISION)/ -x -f -
	tar cf openxpki-i18n-$(REVISION).tar openxpki-i18n-$(REVISION)
	gzip --best openxpki-i18n-$(REVISION).tar
	rm -rf openxpki-i18n-$(REVISION)/


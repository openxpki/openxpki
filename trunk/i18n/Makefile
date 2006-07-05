
LOCALE_DIR   = $(DESTDIR)/usr/share/locale
MO_FILE      = openxpki.mo
INSTALL      = install
LANG         = en_GB
POT_SOURCES  = ../perl-modules ../clients

#---- variable settings above, rules below ----

.PHONY:	default test install clean clean.local distclean openxpki.pot

default::	$(LANG)
	@echo Languages: $(LANG)

## do not depend on openxpki.pot - this does not work
$(LANG):
	@if (test ! -d $@); then echo creating directory for $@; mkdir $@; fi
	@if (test ! -e $@/openxpki.po); then echo creating po file for $@; cp openxpki.pot $@/openxpki.po; fi
	msgmerge --update $@/openxpki.po openxpki.pot
	@rm -f $@/openca.po~
	@perl convert.pl $@/openxpki.po > $@/openxpki.po_utf8 2>/dev/null
	@if (test ! -z `diff $@/openxpki.po $@/openxpki.po_utf8`); then echo no utf8; exit 1; fi
	@rm -f $@/openxpki.po_utf8
	msgfmt -o $@/openxpki.mo $@/openxpki.po

openxpki.pot:	$(POT_SOURCES) build-pot.sh
	sh build-pot.sh $(POT_SOURCES) > $@

install::	$(LANG)
	make install_dir DIR=$(LOCALE_DIR)
	set -e; for lang in $(LANG); do \
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

dist:	REVISION=`svn info | grep Revision | awk '{ print $$2 }'`
dist:
	if [ -d openxpki-i18n-$(REVISION) ] ; then \
		rm -rf openxpki-i18n-$(REVISION)/ ; \
	fi
	mkdir openxpki-i18n-$(REVISION)
	tar -c -p -S -f - \
		--exclude "*.svn" \
		--exclude "openxpki-i18n-*" \
		--exclude "*.1" \
		--exclude "*~" \
		. | \
		tar -C openxpki-i18n-$(REVISION)/ -x -f -
	tar czf openxpki-i18n-$(REVISION).tar.gz openxpki-i18n-$(REVISION)
	rm -rf openxpki-i18n-$(REVISION)/


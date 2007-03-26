
FOP=fop
DOCBOOK=/usr/share/xml/docbook/stylesheet/nwalsh

OSTYPE=$(shell uname)
ifeq "$(OSTYPE)" "FreeBSD"
DOCBOOK=/usr/local/share/xsl/docbook
endif

ifndef OUTPUT_DIR
OUTPUT_DIR=..
endif

XSLTPROC_OPTS= \
	--stringparam html.stylesheet default.css \
	--stringparam fop1.extensions "1" \
	--stringparam paper.type "A4"

## DO NOT HARDCODE PATHS !!!
## Please set DOCBOOK and FOP in the file Makefile.vars.
## The file Makefile.vars is ignored by subversion.
##
## Please add FOP and DOCBOOK to the file Makefile.vars.

-include Makefile.vars

default: openxpki-manual

check:
	xmllint $(XMLLINT_OPTS) --noout --postvalid openxpki-manual.xml

openxpki-manual: html pdf

html:
	xsltproc $(XSLTPROC_OPTS) $(DOCBOOK)/html/profile-docbook.xsl openxpki-manual.xml > $(OUTPUT_DIR)/openxpki-manual.html
	cp default.css $(OUTPUT_DIR)/
	xsltproc $(XSLTPROC_OPTS) --stringparam base.dir $(OUTPUT_DIR)/chunked/ $(DOCBOOK)/html/profile-chunk.xsl openxpki-manual.xml
	cp default.css $(OUTPUT_DIR)/chunked/

pdf:
	xsltproc $(XSLTPROC_OPTS) \
		$(DOCBOOK)/fo/docbook.xsl openxpki-manual.xml > $(OUTPUT_DIR)/openxpki-manual.fo
	$(FOP) -fo $(OUTPUT_DIR)/openxpki-manual.fo -pdf $(OUTPUT_DIR)/openxpki-manual.pdf
	rm $(OUTPUT_DIR)/openxpki-manual.fo 

clean:
	rm -f $(OUTPUT_DIR)/openxpki-manual.html
	rm -f $(OUTPUT_DIR)/openxpki-manual.fo
	rm -f $(OUTPUT_DIR)/openxpki-manual.pdf
	rm -f $(OUTPUT_DIR)/chunked/*.html

dist-clean: clean

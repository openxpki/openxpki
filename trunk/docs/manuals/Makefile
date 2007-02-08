
FOP=fop
DOCBOOK=/usr/share/xml/docbook/stylesheet/nwalsh/

XSLTPROC_OPTS=
XMLLINT_OPTS=

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
	xsltproc $(XSLTPROC_OPTS) $(DOCBOOK)/html/docbook.xsl openxpki-manual.xml > ../openxpki-manual.html

pdf:
	xsltproc $(XSLTPROC_OPTS) \
		--stringparam fop1.extensions "1" \
		--stringparam paper.type "A4" \
		$(DOCBOOK)/fo/docbook.xsl openxpki-manual.xml > ../openxpki-manual.fo
	$(FOP) -fo ../openxpki-manual.fo -pdf ../openxpki-manual.pdf
	rm ../openxpki-manual.fo 

clean:
	rm -f ../openxpki-manual.html
	rm -f ../openxpki-manual.fo
	rm -f ../openxpki-manual.pdf

dist-clean: clean

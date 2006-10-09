FOP_SH=~/docbook/fop-0.20.5/fop.sh

default: openxpki-manual

check:
	xmllint --noout --postvalid openxpki-manual.xml

openxpki-manual: html pdf

html:
	xsltproc docbook-html.xsl openxpki-manual.xml > ../openxpki-manual.html

pdf:
	xsltproc docbook-fo.xsl openxpki-manual.xml > ../openxpki-manual.fo
	$(FOP_SH) -fo ../openxpki-manual.fo -pdf ../openxpki-manual.pdf
	rm ../openxpki-manual.fo 

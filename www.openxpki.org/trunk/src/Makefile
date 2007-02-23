# 
# Process Mason templates and populate directory $DSTDIR with the
# generated files.
#

SRCDIR=htdocs
DSTDIR=../htdocs

all: process docs

process:
	@if [ ! -d $(DSTDIR) ] ; then mkdir $(DSTDIR) ; fi
	perl generate_html.pl $(SRCDIR) $(DSTDIR)

docs:
	cd ../../../trunk/docs/manuals && OUTPUT_DIR=../../../www.openxpki.org/trunk/htdocs/docs/manual make

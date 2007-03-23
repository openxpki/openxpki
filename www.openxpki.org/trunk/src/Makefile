# 
# Process Mason templates and populate directory $DSTDIR with the
# generated files.
#

SRCDIR=htdocs
DSTDIR=../htdocs
MAKE=$(shell which gmake)

all: process docs

checkmake:
ifeq "$(MAKE)" ""
MAKE=make
endif

process:
	@if [ ! -d $(DSTDIR) ] ; then mkdir $(DSTDIR) ; fi
	perl generate_html.pl $(SRCDIR) $(DSTDIR)

docs: checkmake
	@echo "MAKE = $(MAKE)"
	cd ../../../trunk/docs/manuals && OUTPUT_DIR=../../../www.openxpki.org/trunk/htdocs/docs/manual $(MAKE)

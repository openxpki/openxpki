# 
# Process Mason templates and populate directory $DSTDIR with the
# generated files.
#

SRCDIR=htdocs
DSTDIR=../htdocs

all: process

process:
	@if [ ! -d $(DSTDIR) ] ; then mkdir $(DSTDIR) ; fi
	perl generate_html.pl $(SRCDIR) $(DSTDIR)

processall:
	@if [ ! -d $(DSTDIR) ] ; then mkdir $(DSTDIR) ; fi
	perl generate_html.pl --force $(SRCDIR) $(DSTDIR)

clean:
	rm -rf $(DSTDIR)

## Written 2011 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2011 by The OpenXPKI Project
#
# This is a demo Makefile demonstrating the use of the build variable
# template mechanism defined in Makefile.inc
#
# Run make to see what this is doing and inspect the output file demo.
#

TOPDIR=../../..

# You simply need to
include Makefile.inc

# this is how you can pass additional 
TT_EXTRA_SYMBOLS = --define LUXURY_YACHT="Throatwobbler Mangrove" \
	--define WHIZZO_QUALITY="Crunchy Frog"

all: demo

# simply specify a target file. This assumes that there's a file 
# demo.template in the current directory and will automatically process 
# it via Template Toolkit
demo: demo.template

clean:
	rm -f demo

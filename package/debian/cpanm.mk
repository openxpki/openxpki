# cpanm.mk - helper makefile for installing cpanm in build process
#
# This could probably be packaged as a supplemental package for myperl,
# but for now let's just leave it as a simple build dependency.

CPANM = $(PERL) $(PWD)/cpanm

cpanm:
	curl -LO http://xrl.us/cpanm
	chmod +x cpanm


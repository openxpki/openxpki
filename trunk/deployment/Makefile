
default:
	autoconf
	automake --add-missing || echo Ignoring noise from automake
	./configure
	make

## dummy for packaging tools
distclean::

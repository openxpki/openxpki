# This include Makefile provides a central location for
# setting the perl and myperl versions/releases. It is
# overridden by the environment variables, if set.

ifndef PERL_VERSION
	PERL_VERSION := 5.24.0
endif

ifndef MYPERL_RELEASE
	MYPERL_RELEASE := 1
endif




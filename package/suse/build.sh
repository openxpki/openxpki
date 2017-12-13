#!/bin/bash
#
# package/suse/build.sh - Build OpenXPKI packages for SLES 11 in Vagrant
#
# This script depends on a Vagrant SLES11 image with a few packages
# already installed, including myperl and myperl-buildtools.

# Exit on error
set -e
set -x

basedir="$PWD"

if [ -e "$basedir/settings.rc" ]; then
    . $basedir/settings.rc
fi
if [ -e "$basedir/settings-myperl.rc" ]; then
    . $basedir/settings-myperl.rc
fi

# Directory where rpmbuild puts the new packages
rpmsdir=~/rpmbuild/RPMS/x86_64

# Directory where we consolidate the new packages
test -d $basedir/rpms || mkdir -p $basedir/rpms

echo "DEBUG: determining oxi version" >&2
: ${OXI_VERSION:=$(perl tools/vergen --format version)}
echo "DEBUG: OXI_VERSION=$OXI_VERSION" >&2

if [ -z "$OXI_VERSION" ]; then
    echo "ERROR - failed to detect OpenXPKI version" 1>&2
    exit 1
fi

# 
# OpenXPKI Core Dependencies
#
if ! rpm -q myperl-openxpki-core-deps >/dev/null 2>&1; then
    (cd package/suse/myperl-openxpki-core-deps && \
        PERL_MM_OPT='INC="$OPENSSL_INC"' PERL5LIB=$HOME/perl5/lib/perl5/ make \
        DEBUG=$DEBUG )
    test $? == 0 || die "Error building myperl-openxpki-core-deps"
    sudo rpm -ivh \
        $rpmsdir/myperl-openxpki-core-deps-$OXI_VERSION-1.x86_64.rpm
    cp -av \
        $rpmsdir/myperl-openxpki-core-deps-$OXI_VERSION-1.x86_64.rpm \
        $basedir/rpms/
else
    echo "ERROR: myperl-openxpki-core-deps already installed!!" >&2
fi

#
# OpenXPKI Core
#
if ! rpm -q myperl-openxpki-core >/dev/null 2>&1; then
    (cd package/suse/myperl-openxpki-core && \
        PERL_MM_OPT='INC="$OPENSSL_INC"' PERL5LIB=$HOME/perl5/lib/perl5/ make \
        DEBUG=$DEBUG )
    test $? == 0 || die "Error building myperl-openxpki-core"
    sudo rpm -ivh $rpmsdir/myperl-openxpki-core-$OXI_VERSION-1.x86_64.rpm
    cp -av \
        $rpmsdir/myperl-openxpki-core-$OXI_VERSION-1.x86_64.rpm \
        $basedir/rpms/myperl-openxpki-core-$OXI_VERSION-1.x86_64.rpm 
else
    echo "ERROR: myperl-openxpki-core already installed!!" >&2
fi

#
# OpenXPKI I18N
#
if ! rpm -q myperl-openxpki-i18n >/dev/null 2>&1; then
    (cd package/suse/myperl-openxpki-i18n && \
        PERL5LIB=$HOME/perl5/lib/perl5/ make \
        DEBUG=$DEBUG )
    test $? == 0 || die "Error building myperl-openxpki-i18n"
    sudo rpm -ivh $rpmsdir/myperl-openxpki-i18n-$OXI_VERSION-1.x86_64.rpm
    cp -av \
        $rpmsdir/myperl-openxpki-i18n-$OXI_VERSION-1.x86_64.rpm \
        $basedir/rpms
else
    echo "ERROR: myperl-openxpki-i18n already installed!!" >&2
fi


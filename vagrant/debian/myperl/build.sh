#!/bin/bash
# Building Oxi on SLES 11 SP3 or vagrant debian
#
# Runtime:
#
#   t1.micro    ca. 80 mins
#   m3.medium   ca. 20 mins
#
# TODO: mysql
#       sudo zypper install libmysqlclient-devel
#
# NOTE: When using mysql, add the PATH to the openssl.so
#       (/opt/myperl/ssl/lib/) to ldconfig
#
#       Or add the file /etc/ld.conf.d/openssl.conf with the following:
#       /opt/mypler/ssl/lib/
#
# CONFIGURATION:
#
# Local ENV vars can be set manually or read from the file 'local.rc'. The
# following variables are supported:
#
# MYPERL_URL    This is the URL used by 'git clone ...' to fetch a working
#               copy of the myperl repo. When running in our oxi vagrant,
#               it will look for a pre-configured shared folder. By
#               default, it will just fetch directly from github.
#
# MYPERL_BRANCH This is the branch to switch to in the myperl repo before
#               building. Only set this if you need to force a non-default
#               branch.
#
# CPAN_MIRROR   This is used to pass the '-M' option to the cpanm command.
#               In the vagrant instance, this should be automatically
#               detected. If you override it, include the '-M' option in
#               the string like this:
#
#                   CPAN_MIRROR="-M file:///mirrors/minicpan"

# exit on error
set -e
# verbose execution
#set -x

function pkg_installed {
    case $DISTNAME in
        suse|sles)
            rpm -q "$1" >/dev/null 2>&1
            return $?
            ;;
        debian)
            dpkg -s "$1" >/dev/null 2>&1
            return $?
            ;;
        *)
            echo "Unsupported distro '$DISTNAME'" 1>&2
            exit 1
            ;;
    esac

    return 1
}

function pkg_inst {
    case $DISTNAME in
        suse|sles)
            rpm -i "$1"
            return $?
            ;;
        debian)
            if [ -f "$1" ]; then
                sudo dpkg -i "$1"
                return $?
            else
                sudo aptitude install -y "$1"
                return $?
            fi
            ;;
        *)
            echo "Unsupported distro '$DISTNAME'" 1>&2
            exit 1
            ;;
    esac

    return 1
}



DISTNAME=unknown

if [ -e /etc/debian_version ]; then
    DISTNAME=debian
fi
if [ -e /etc/SuSE-release ]; then
    DISTNAME=suse
fi

if [ "$DISTNAME" == "unknown" ]; then
    echo "Unsupported distribution!!!" 1>&2
    exit 1
fi

############################################################
# Bootstrap
############################################################
if ! pkg_installed git-core; then
    pkg_inst git-core
fi


############################################################
# BEGIN CONFIGURATION
############################################################

# The VAG_*_REPO vars are the paths of the synced folders as
# configured in the Vagrantfile and found in the guest instance.
VAG_MYPERL_REPO=/myperl-repo
VAG_CODE_REPO=/code-repo

# The GH_*_GITURL vars are the 'default' locations of the repos
# on github themlselves. Note: for local configuration override,
# set MYPERL_GITURL and OPENXPKI_GITURL instead.
GH_MYPERL_GITURL=https://github.com/mrscotty/myperl.git
GH_OPENXPKI_GITURL=https://github.com/openxpki/openxpki.git

#MYPERL_VERSION=5.20.2
MYPERL_RELEASE=1
PERL_VERSION=

#OPENXPKI_GITURL=https://github.com/mrscotty/openxpki.git

#OPENXPKI_BRANCH=develop
#OPENXPKI_BRANCH=master
#OPENXPKI_BRANCH=feature/suse

#KEYNANNY_GITURL=https://github.com/mrscotty/KeyNanny.git
#KEYNANNY_BRANCH=feature/makemaker

# Source in local override of above config vars
if [ -f local.rc ]; then
    . local.rc
fi

############################################################
# Decide on value for MYPERL_GITURL from the following choices
# in descending priority:
#
# - Value already set in ENV from local.rc or manually
# - Vagrant shared folder (local clone folder was found during 'vagrant up ...')
# - Github
# 
############################################################

if [ -z "$MYPERL_GITURL" ] && [ -f $VAG_MYPERL_REPO/.git/config ]; then
    echo "INFO: Found local myperl git repo in $VAG_MYPERL_REPO"
    MYPERL_GITURL=$VAG_MYPERL_REPO
fi

if [ -z "$MYPERL_GITURL" ]; then
    echo "INFO: will fetch myperl repo directly from github"
    MYPERL_GITURL=$GH_MYPERL_GITURL
fi

############################################################
# Decide on value for OPENXPKI_GITURL from the following choices
# in descending priority:
#
# - Value already set in ENV from local.rc or manually
# - Vagrant shared folder (local clone folder was found during 'vagrant up ...')
# - Github
# 
############################################################

if [ -z "$OPENXPKI_GITURL" ] && [ -f $VAG_CODE_REPO/.git/config ]; then
    echo "INFO: Found local openxpki git repo in $VAG_CODE_REPO"
    OPENXPKI_GITURL=$VAG_CODE_REPO
fi

if [ -z "$OPENXPKI_GITURL" ]; then
    echo "INFO: will fetch openxpki repo directly from github"
    OPENXPKI_GITURL=$GH_OPENXPKI_GITURL
fi


#if [ -d /code-repo ]; then
#    # Smells like a vagrant instance, use the local /code-repo dir
#    OPENXPKI_GITURL=/code-repo
#    OPENXPKI_BRANCH=$(cd $OPENXPKI_GITURL && git branch | grep '^*' | cut -d\  -f 2)
#fi

if [ -z "$CPAN_MIRROR" ] && [ -d /mirrors/minicpan ]; then
    echo "INFO: detected CPAN mirror in /mirrors/minicpan"
    export CPAN_MIRROR="-M file:///mirrors/minicpan"
fi

if [ "$DISTNAME" == "suse" ] && [ -z "$ORACLE_HOME" ]; then
    echo "INFO: detected suse OS, but no ORACLE_HOME"
    echo "INFO: using default value for ORACLE_HOME for the tested vag box"
    ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
fi

############################################################
# END CONFIGURATION
############################################################

#echo "############################################################"
#echo "# PREREQS"
#echo "############################################################"

if [ "$DISTNAME" == "suse" ]; then
# TODO: rebuild ami to include this...
if [ ! -f /usr/share/man/man3/Template.3pm ]; then
  sudo cpanm Template
fi

# UGLY HACK DUE TO CURRENT OPENSSL CONFIG
# This is for an error with SSLeay.so not finding the OpenSSL symbols
#if [ -d /usr/local/lib && -d /usr/local/lib64 ]; then
#    sudo rmdir /usr/local/lib || (echo "ERROR: /usr/local/lib NOT EMPTY"; exit 1)
#    sudo ln -s /usr/local/lib64 /usr/local/lib
#fi
if [ ! -L /usr/local/include/openssl ]; then
  sudo ln -s /opt/myperl/ssl/include/openssl /usr/local/include/
fi

if [ ! -L /usr/local/lib64 ]; then
    if [ -d /usr/local/lib64 ]; then
        sudo rmdir /usr/local/lib64
    fi
    sudo ln -s /opt/myperl/ssl/lib /usr/local/lib64
fi

fi

function cleantmp
{
    rm -rf ~/.cpanm ~/rpmbuild/BUILD/*
    rm -rf ~/openssl-1.0.1m
}

function die {
    echo $* 1>&2
    exit 1
}

function run_git {
    echo "############################################################"
    echo "# FETCH/UPDATE GIT REPOS"
    echo "############################################################"
    test -d ~/git/myperl || git clone --quiet $MYPERL_GITURL ~/git/myperl
    test -d ~/git/openxpki || git clone --quiet $OPENXPKI_GITURL ~/git/openxpki

    if [ -n "$MYPERL_BRANCH" ]; then
        echo "INFO: switching myperl repo branch to '$MYPERL_BRANCH'"
        (cd ~/git/myperl && git checkout $MYPERL_BRANCH)
    fi
    (cd ~/git/myperl && git pull)

    if [ -n "$OPENXPKI_BRANCH" ]; then
        echo "INFO: switching openxpki repo branch to '$OPENXPKI_BRANCH'"
        (cd ~/git/openxpki && git checkout $OPENXPKI_BRANCH)
    fi
    (cd ~/git/openxpki && git pull)

    if [ -n "$KEYNANNY_GITURL" ]; then
        test -d ~/git/keynanny || git clone $KEYNANNY_GITURL ~/git/keynanny
        if [ -n "$KEYNANNY_BRANCH" ]; then
            (cd ~/git/keynanny && git checkout $KEYNANNY_BRANCH)
        fi
        (cd ~/git/keynanny && git pull)
    fi
}

function get_perl_version {
    if [ -z "$PERL_VERSION" ]; then
        # Default to version listed in myperl
        PERL_VERSION=$(cd ~/git/myperl && make perl-ver-string)
    fi
    echo "$PERL_VERSION"
}

function get_myperl_version {
    case $DISTNAME in
        suse)
            MYPERL_VERSION=$(cd ~/git/myperl && make suse-ver-string)
            ;;
        debian)
            MYPERL_VERSION=$(cd ~/git/myperl && make debian-ver-string)
            ;;
    esac
    if [ -z "$MYPERL_VERSION" ]; then
        echo "ERROR - failed to detect myperl version" 1>&2
        exit 1
    fi
    echo "$MYPERL_VERSION"
}

function get_myperl_release {
    case $DISTNAME in
        debian)
            RELEASE=$(cd ~/git/myperl && make myperl-deb-release)
            ;;
    esac
    if [ -z "$RELEASE" ]; then
        echo "ERROR - failed to detect myperl package release" 1>&2
        exit 1
    fi
    echo "$RELEASE"
}

function get_buildtools_version
{
    case $DISTNAME in
        debian)
            VERSION=$(cd ~/git/myperl && make perl-ver-string)
            RELEASE=$(cd ~/git/myperl && make myperl-deb-release)
            ;;
    esac
    echo "${VERSION}.${RELEASE}"
}


function get_oxi_version {
    OXI_VERSION=$(cd ~/git/openxpki && perl tools/vergen --format version)
    if [ -z "$OXI_VERSION" ]; then
        echo "ERROR - failed to detect OpenXPKI version" 1>&2
        exit 1
    fi
    echo "$OXI_VERSION"
}

function get_oxi_pkgrel {
    OXI_PKGREL=$(cd ~/git/openxpki && perl tools/vergen --format PKGREL)
    if [ -z "$OXI_PKGREL" ]; then
        echo "ERROR - failed to detect OpenXPKI pkgrel" 1>&2
        exit 1
    fi
    echo "$OXI_PKGREL"
}


#if [ -n "$KEYNANNY_GITURL" ]; then
function get_keynanny_version {
    KEYNANNY_VERSION=$(cd ~/git/keynanny && git describe --tags | \
        perl -p -e 's/.*(\d+\.\d+)-?(\d*).*/\1/')
    if [ -z "$KEYNANNY_VERSION" ]; then
        echo "ERROR - failed to detect KeyNanny version" 1>&2
        exit 1
    fi
}
#fi

function run_openssl {
    echo "############################################################"
    echo "# BUILD LOCAL OPENSSL"
    echo "# Note: This is becase SLES-11 comes with OpenSSL 0.9. The"
    echo "# local installation can symlink this directory to somewhere"
    echo "# more useful, if needed"
    echo "############################################################"

    export OPENSSL_PREFIX=/opt/myperl/ssl
    export OPENSSL_INCLUDE=$OPENSSL_PREFIX/include
    export OPENSSL_INC=$OPENSSL_PREFIX/include
    export OPENSSL_LIB=$OPENSSL_PREFIX/lib

    if $OPENSSL_PREFIX/bin/openssl version -f | grep -q fPIC ; then
        echo "OpenSSL built with -fPIC"
    else
        echo "WARN: Need to rebuild OpenSSL with -fPIC"
        export CFLAGS="-fPIC"
        wget http://openssl.org/source/openssl-1.0.1m.tar.gz
        tar -xzf openssl-1.0.1m.tar.gz
        (cd ~/openssl-1.0.1m && ./config --prefix=$OPENSSL_PREFIX 
            --openssldir=$OPENSSL_PREFIX shared)
        (cd ~/openssl-1.0.1m && make depend all)
        (cd ~/openssl-1.0.1m && sudo make install)
    fi
}

function run_cache
{
    PERL_VERSION=$(get_perl_version)
    
    if [ -s /vagrant/perl-${PERL_VERSION}.tar.bz2 ]; then
        cp -a /vagrant/perl-${PERL_VERSION}.tar.bz2 ~/git/myperl/
    fi

    if [ -s /vagrant/cpanm ]; then
        cp -a /vagrant/cpanm ~/git/myperl/
    fi
}

############################################################
# myperl
############################################################

function run_myperl {
    cleantmp
    (cd ~/git/myperl && make fetch-perl $DISTNAME)
    MYPERL_VERSION=$(get_myperl_version)
    case $DISTNAME in
        suse)
            sudo rpm -ivh --oldpackage --replacepkgs \
                ~/rpmbuild/RPMS/x86_64/myperl-$MYPERL_VERSION.x86_64.rpm
            ;;
        debian)
            sudo dpkg --install \
                ~/git/myperl/myperl_${MYPERL_VERSION}_$(dpkg --print-architecture).deb
            ;;
    esac
}

function run_buildtools
{
    cleantmp
    PERL_VERSION=$(get_perl_version)
    MYPERL_VERSION=$(get_myperl_version)
    OXI_VERSION=$(get_oxi_version)
    VERSION=$(cd ~/git/myperl && make perl-ver-string)
    RELEASE=$(cd ~/git/myperl && make myperl-deb-release)
    case $DISTNAME in
        suse)
            (cd ~/git/openxpki/package/suse/myperl-buildtools && \
                PERL5LIB=$HOME/perl5/lib/perl5 make \
                PERL_VERSION=$PERL_VERSION \
                CPAN_MIRROR="$CPAN_MIRROR" \
                )
            sudo rpm -ivh --oldpackage --replacepkgs \
            ~/rpmbuild/RPMS/x86_64/myperl-buildtools-$MYPERL_VERSION.x86_64.rpm
            ;;
        debian)
            (cd ~/git/openxpki/package/debian/myperl-buildtools && \
                PERL5LIB=$HOME/perl5/lib/perl5 make \
                PERL_VERSION=$PERL_VERSION \
                CPAN_MIRROR="$CPAN_MIRROR" \
                PACKAGE_VER="$VERSION" \
                PACKAGE_REL="$RELEASE" \
                clean package)
            sudo dpkg --install \
                ~/git/openxpki/package/debian/myperl-buildtools_${VERSION}.${RELEASE}_$(dpkg --print-architecture).deb
          ;;
    esac
}

function run_fcgi
{
    cleantmp
    PERL_VERSION=$(get_perl_version)
    MYPERL_RELEASE=$(get_myperl_release)
    (cd ~/git/openxpki/package/$DISTNAME/myperl-fcgi && \
        PERL5LIB=$HOME/perl5/lib/perl5/ make \
        CPAN_MIRROR="$CPAN_MIRROR" \
        PACKAGE_VER="$PERL_VERSION" \
        PACKAGE_REL="$MYPERL_RELEASE" \
        clean package)
    test $? == 0 || die "Error building myperl-fcgi"
    case $DISTNAME in
        suse)
            sudo rpm -ivh ~/rpmbuild/RPMS/x86_64/myperl-fcgi-$OXI_VERSION-1.x86_64.rpm
            ;;
        debian)
            sudo dpkg --install \
                ~/git/openxpki/package/debian/myperl-fcgi_${PERL_VERSION}.${MYPERL_RELEASE}_$(dpkg --print-architecture).deb
            ;;
    esac
}

function run_oxideps 
{
    cleantmp
    PERL_VERSION=$(get_perl_version)
    OXI_VERSION=$(get_oxi_version)
    OXI_PKGREL=$(get_oxi_pkgrel)
    (cd ~/git/openxpki/package/$DISTNAME/myperl-openxpki-core-deps && \
        PERL_MM_OPT='INC="$OPENSSL_INC"' PERL5LIB=$HOME/perl5/lib/perl5/ make \
        PACKAGE_VER=$OXI_VERSION PACKAGE_REL=$OXI_PKGREL \
                CPAN_MIRROR="$CPAN_MIRROR" \
        clean package)
    test $? == 0 || die "Error building myperl-openxpki-core-deps"
    case $DISTNAME in
        suse)
            sudo rpm -ivh \
                ~/rpmbuild/RPMS/x86_64/myperl-openxpki-core-deps-${OXI_VERSION}-${OXI_PKGREL}.x86_64.rpm
            ;;
        debian)
            sudo dpkg --install \
                ~/git/openxpki/package/debian/myperl-openxpki-core-deps_${OXI_VERSION}.${OXI_PKGREL}_$(dpkg --print-architecture).deb
            ;;
    esac
}


function run_oracle
{
if [ -d "$ORACLE_HOME" ]; then
    export ORACLE_HOME
    if [ -n "$LD_LIBRARY_PATH" ]; then
        export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
    else
        export LD_LIBRARY_PATH=$ORACLE_HOME/lib
    fi

    if ! rpm -q myperl-dbd-oracle >/dev/null 2>&1; then
        cleantmp
        (cd ~/git/openxpki/package/suse/myperl-dbd-oracle && \
            PERL_MM_OPT='INC="$OPENSSL_INC"' PERL5LIB=$HOME/perl5/lib/perl5/ make)
        test $? == 0 || die "Error building myperl-dbd-oracle"
        sudo rpm -ivh ~/rpmbuild/RPMS/x86_64/myperl-dbd-oracle-$OXI_VERSION-1.x86_64.rpm
    fi
fi
}

function run_mysql
{
    cleantmp
    OXI_VERSION=$(get_oxi_version)
    OXI_PKGREL=$(get_oxi_pkgrel)
    (cd ~/git/openxpki/package/$DISTNAME/myperl-dbd-mysql && \
        PERL_MM_OPT='INC="$OPENSSL_INC"' PERL5LIB=$HOME/perl5/lib/perl5/ make \
        PACKAGE_VER=$OXI_VERSION PACKAGE_REL=$OXI_PKGREL \
                CPAN_MIRROR="$CPAN_MIRROR" \
        clean package)
    test $? == 0 || die "Error building myperl-dbd-mysql"
    case $DISTNAME in
        suse)
            sudo rpm -ivh \
                ~/rpmbuild/RPMS/x86_64/myperl-dbd-mysql-${OXI_VERSION}-${OXI_PKGREL}.x86_64.rpm
            ;;
        debian)
            sudo dpkg --install \
                ~/git/openxpki/package/debian/myperl-dbd-mysql_${OXI_VERSION}.${OXI_PKGREL}_$(dpkg --print-architecture).deb
            ;;
    esac
}

function run_oxi
{
    cleantmp
    PERL_VERSION=$(get_perl_version)
    OXI_VERSION=$(get_oxi_version)
    OXI_PKGREL=$(get_oxi_pkgrel)
    (cd ~/git/openxpki/package/$DISTNAME/myperl-openxpki-core && \
        PERL_MM_OPT='INC="$OPENSSL_INC"' PERL5LIB=$HOME/perl5/lib/perl5/ make \
        PACKAGE_VER=$OXI_VERSION PACKAGE_REL=$OXI_PKGREL \
                CPAN_MIRROR="$CPAN_MIRROR" \
        clean package)
    test $? == 0 || die "Error building myperl-openxpki-core"
    case $DISTNAME in
        suse)
            sudo rpm -ivh \
                ~/rpmbuild/RPMS/x86_64/myperl-openxpki-core-${OXI_VERSION}-${OXI_PKGREL}.x86_64.rpm
            ;;
        debian)
            sudo dpkg --install \
                ~/git/openxpki/package/debian/myperl-openxpki-core_${OXI_VERSION}.${OXI_PKGREL}_$(dpkg --print-architecture).deb
            ;;
    esac
}

function run_oxii18n
{
    cleantmp
    OXI_VERSION=$(get_oxi_version)
    OXI_PKGREL=$(get_oxi_pkgrel)
    (cd ~/git/openxpki/package/$DISTNAME/myperl-openxpki-i18n && \
        PERL_MM_OPT='INC="$OPENSSL_INC"' PERL5LIB=$HOME/perl5/lib/perl5/ make \
        PACKAGE_VER=$OXI_VERSION PACKAGE_REL=$OXI_PKGREL \
                CPAN_MIRROR="$CPAN_MIRROR" \
        clean package)
    test $? == 0 || die "Error building myperl-openxpki-i18n"
    case $DISTNAME in
        suse)
            sudo rpm -ivh \
                ~/rpmbuild/RPMS/x86_64/myperl-openxpki-i18n-${OXI_VERSION}-${OXI_PKGREL}.x86_64.rpm
            ;;
        debian)
            sudo dpkg --install \
                ~/git/openxpki/package/debian/myperl-openxpki-i18n_${OXI_VERSION}.${OXI_PKGREL}_$(dpkg --print-architecture).deb
            ;;
    esac
}

function run_keynanny
{
    if [ -n "$KEYNANNY_GITURL" ]; then
        cleantmp
        (cd ~/git/keynanny && \
            PERL5LIB=$HOME/perl5/lib/perl5/ make version package)
        test $? == 0 || die "Error building myperl-keynanny"
        KEYNANNY_VERSION=$(cat ~/git/keynanny/VERSION)
        sudo rpm -ivh \
            ~/rpmbuild/RPMS/x86_64/keynanny-$KEYNANNY_VERSION-1.x86_64.rpm
    fi
}

function run_all {
    run_git
    run_cache
    if [ "$DISTNAME" == "suse" ]; then
        echo "### calling run_openssl..."
        run_openssl
    fi
    if ! pkg_installed myperl; then
        echo "### calling run_myperl..."
        run_myperl
    fi
    if ! pkg_installed myperl-buildtools; then
        echo "### calling run_buildtools..."
        run_buildtools
    fi
    if ! pkg_installed myperl-fcgi; then
        echo "### calling run_fcgi..."
        run_fcgi
    fi
    if ! pkg_installed myperl-openxpki-core-deps; then
        echo "### calling run_oxideps..."
        run_oxideps
    fi
    if ! pkg_installed myperl-dbd-oracle; then
        echo "### calling run_oracle..."
        run_oracle
    fi
    if ! pkg_installed myperl-dbd-mysql; then
        echo "### calling run_mysql"
        run_mysql
    fi
    if ! pkg_installed myperl-openxpki-core; then
        echo "### calling run_oxi..."
        run_oxi
    fi
    if ! pkg_installed myperl-openxpki-i18n; then
        echo "### calling run_oxii18n..."
        run_oxii18n
    fi
    if ! pkg_installed myperl-keynanny; then
        echo "### calling run_keynanny..."
        run_keynanny
    fi
}


cmd="$1"

case "$cmd" in
    info)
        echo "MYPERL_VERSION        = $(get_myperl_version)"
        echo "PERL_VERSION          = $(get_perl_version)"
        echo "BUILDTOOLS_VERSION    = $(get_buildtools_version)"
        echo "OXI_VERSION           = $(get_oxi_version)"
        echo "OXI_PKGREL            = $(get_oxi_pkgrel)"
        ;;
    git|cache|myperl|buildtools|fcgi|oxideps|oracle|mysql|oxi|oxii18n|keynanny)
        echo "Running 'run_$cmd' ..."
        run_$cmd
        ;;
    all)
        run_all
        ;;
    realclean)
        if [ "$DISTNAME" == "debian" ]; then
            for i in myperl-openxpki-i18n myperl-openxpki-core myperl-dbd-oracle myperl-openxpki-core-deps myperl-fcgi myperl-dbd-mysql myperl-buildtools myperl; do
                if pkg_installed $i; then
                    sudo dpkg -r $i
                fi
            done
        fi
        ;;
    collect)
        if [ "$DISTNAME" == "debian" ]; then
            mkdir -p /vagrant/myperl/deb
            cp --verbose \
                ~/git/myperl/myperl*.deb \
                ~/git/openxpki/package/debian/*.deb \
                /vagrant/myperl/deb/
        fi
        ;;
    *)
        echo "No command specified"
        exit 1
        ;;
esac



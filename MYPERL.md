# MYPERL

As a simplified alternative to individual packages for the plethora of
CPAN modules we require, the myperl installation may be used.

# BUILDING PACKAGES

## Before You Start

On your build system, you should have the following repository clones:

    ~/git/myperl     -> e.g. http://github.com/mrscotty/myperl.git
    ~/git/openxpki   -> e.g. http://github.com/openxpki/openxpki.git

## SuSE

### myperl

    cd ~/git/myperl && make fetch-perl suse
    sudo rpm -Uvh ~/rpmbuild/RPMS/x86_64/myperl-<PERLVER>-<MYPERLREL>.x86_64.rpm

### build tools

    /opt/myperl/bin/perl -I~/perl5/lib/perl5/ /usr/bin/cpanm Config::Std


### DBD::mysql

    cd ~/git/openxpki/package/suse/myperl-dbd-mysql && make 
    sudo rpm -Uvh ~/rpmbuild/RPMS/x86_64/myperl-dbd-mysql-<OXI_VER>-1.x86_64.rpm

### Apache mod\_perl
    
    cd ~/git/openxpki/package/suse/myperl-apache-mod-perl && make 
    
### DBD::Oracle

    cd ~/git/openxpki/package/suse/myperl-dbd-oracle && make 

### OXI core dependencies

    cd ~/git/openxpki/package/suse/myperl-openxpki-core-deps && make 
    sudo rpm -Uvh \
        ~/rpmbuild/RPMS/x86_64/myperl-openxpki-core-deps-<OXI_VER>-1.x86_64.rpm

### OXI core

    cd ~/git/openxpki/package/suse/myperl-openxpki-core && make 
    sudo rpm -Uvh \
        ~/rpmbuild/RPMS/x86_64/myperl-openxpki-core-<OXI_VER>-1.x86_64.rpm
    



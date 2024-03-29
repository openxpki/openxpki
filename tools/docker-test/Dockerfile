FROM debian:10-slim

#
# RUN commands are split to be able to change something in the config and still
# have Docker cache the FS layers with the earlier commands.
#

#
# Setup - packages
#
ARG DEBIAN_FRONTEND=noninteractive

# language-pack-de ... needed for the i18n test
# wamerican ... provides /usr/share/dict/words (used by OpenXPKI::Server::API2::Plugin::Crypto::password_quality)
RUN apt-get update && \
    apt-get -qq -y install \
        locales \
        build-essential \
        git \
        expat libexpat-dev \
        openssl libssl-dev \
        libmariadbclient-dev \
        apache2 \
        mariadb-server \
        curl \
        pkg-config \
        nano \
        figlet \
        wamerican \
        && \
    apt-get clean

#
# Setup - cpanm and "default" modules
#
COPY cpanminus /
RUN cat /cpanminus | perl - App::cpanminus && rm /cpanminus
# modules needed by OpenXPKI
COPY cpanfile /
RUN cpanm --quiet --notest --installdeps /
# modules needed in startup.pl
RUN cpanm --quiet --notest PPI Devel::Cover DateTime File::Slurp

#
# Prepare MySQL
# (copied from /lib/systemd/system/mariadb.service)
RUN /usr/bin/install -m 755 -o mysql -g root -d /var/run/mysqld

#
# Copy scripts from symlinked directories
#
ADD scripts.tar /tools-copy/

#
# Setup - locales
#
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.UTF-8

#
# Configuration
#
# We do not specify MariaDB host and port to use socket connection
ENV OXI_TEST_SAMPLECONFIG_DIR=/opt/openxpki-config \
    OXI_TEST_DB_MYSQL_NAME=openxpki \
    OXI_TEST_DB_MYSQL_USER=openxpki \
    OXI_TEST_DB_MYSQL_PASSWORD=openxpki \
    OXI_TEST_DB_MYSQL_DBUSER=root \
    OXI_TEST_DB_MYSQL_DBPASSWORD="" \
    OXI_TEST_ONLY=""

COPY startup.pl /
RUN chmod 0755 startup.pl
CMD ["/startup.pl"]

FROM debian:8.6

#
# RUN commands are split to be able to change something in the config and still
# have Docker cache the FS layers with the earlier commands.
#

#
# Setup - packages
#
ARG DEBIAN_FRONTEND=noninteractive

# language-pack-de is needed for the i18n test
RUN apt-get update && \
    apt-get -qq -y install \
        locales \
        build-essential \
        git \
        expat libexpat-dev \
        openssl libssl-dev \
        libmysqlclient-dev \
        apache2 \
        mysql-server \
        curl \
        pkg-config \
        nano \
        figlet \
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
ENV OXI_TEST_DB_MYSQL_NAME=openxpki \
    OXI_TEST_DB_MYSQL_USER=openxpki \
    OXI_TEST_DB_MYSQL_PASSWORD=openxpki \
    OXI_TEST_DB_MYSQL_DBHOST=127.0.0.1 \
    OXI_TEST_DB_MYSQL_DBPORT=3306 \
    OXI_TEST_DB_MYSQL_DBUSER=root \
    OXI_TEST_DB_MYSQL_DBPASSWORD="" \
    OXI_TEST_ONLY=""

COPY startup.pl /
RUN chmod 0755 startup.pl
ENTRYPOINT ["/startup.pl"]
# Defaults for "user+repo" and "branch" to test:
#CMD ["develop", "openxpki/openxpki"]

FROM ubuntu:14.04

#
# Scripts are split to be able to change something in the config and still
# have Docker cache the FS layers with the earlier commands.
#

#
# Setup - packages
#
ARG DEBIAN_FRONTEND=noninteractive

# language-pack-de is needed for the i18n test
RUN apt-get update
RUN apt-get -qq -y install \
        build-essential \
        git \
        expat libexpat-dev \
        openssl libssl-dev \
        language-pack-de \
        libmysqlclient-dev \
        apache2
RUN apt-get -qq -y install \
        mysql-server
RUN apt-get -qq -y install \
        curl
RUN apt-get -qq -y install \
        pkg-config
RUN apt-get clean

#
# Setup - cpanm and "default" modules
#
RUN curl -s -L https://cpanmin.us | perl - --sudo App::cpanminus
COPY cpanfile /
RUN cpanm --quiet --notest --installdeps /


#
# Setup - files and locales
#
COPY startup.sh /
RUN chmod 0755 startup.sh

ENV LANG en_US.UTF-8
RUN locale-gen en_US.utf8

#
# Configuration
#
ENV OXI_TEST_DB_MYSQL_NAME openxpki
ENV OXI_TEST_DB_MYSQL_USER openxpki
ENV OXI_TEST_DB_MYSQL_PASSWORD openxpki

ENTRYPOINT ["/startup.sh"]
CMD ["openxpki/openxpki", "develop"]

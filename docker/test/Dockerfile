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
        apache2 \
        mysql-server \
        curl \
        pkg-config
RUN apt-get clean

#
# Setup - cpanm and "default" modules
#
RUN curl -s -L https://cpanmin.us | perl - --sudo App::cpanminus
COPY cpanfile /
RUN cpanm --quiet --notest --installdeps /


#
# Setup - locales
#
ENV LANG en_US.UTF-8
RUN locale-gen en_US.utf8

#
# Configuration
#
ENV OXI_TEST_DB_MYSQL_NAME openxpki
ENV OXI_TEST_DB_MYSQL_USER openxpki
ENV OXI_TEST_DB_MYSQL_PASSWORD openxpki
ENV OXI_TEST_DB_MYSQL_DBHOST 127.0.0.1
ENV OXI_TEST_DB_MYSQL_DBPORT 3306
ENV OXI_TEST_DB_MYSQL_DBUSER root
ENV OXI_TEST_DB_MYSQL_DBPASSWORD ""

COPY startup.sh /
RUN chmod 0755 startup.sh
ENTRYPOINT ["/startup.sh"]
# Defaults for "user+repo" and "branch" to test:
CMD ["develop", "openxpki/openxpki"]

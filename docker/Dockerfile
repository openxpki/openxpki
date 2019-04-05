FROM debian:jessie

ARG DEBIAN_FRONTEND=noninteractive
ARG OPENXPKI_NOCONFIG=1

# Debian has removed the update repos as jessie is near EOL
RUN sed -i '/jessie-updates/d' /etc/apt/sources.list
RUN apt-get update && \
    apt-get install --assume-yes --force-yes libdbd-mysql-perl libapache2-mod-fcgid apache2 wget locales

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && dpkg-reconfigure --frontend=noninteractive locales

RUN wget https://packages.openxpki.org/v2/debian/openxpki.list -O /etc/apt/sources.list.d/openxpki.list
RUN wget https://packages.openxpki.org/v2/debian/Release.key -O - | apt-key add -
RUN (apt-get update && apt-get install --assume-yes --force-yes libopenxpki-perl openxpki-i18n openxpki-cgi-session-driver || /bin/true)
RUN apt-get clean
RUN ln -s /etc/openxpki/apache2/openxpki.conf /etc/apache2/conf-enabled/
RUN a2enmod cgid fcgid

VOLUME /var/log/openxpki /etc/openxpki

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /var/log/openxpki/

CMD ["/usr/bin/openxpkictl","start","--no-detach"]

EXPOSE 80 443

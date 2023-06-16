# build container
FROM debian:bookworm AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG OPENXPKI_NOCONFIG=1

WORKDIR /tmp

# stuff for building the repository
RUN apt update && apt install -y gpg reprepro

# packages required for testing
RUN apt install --assume-yes libtest-deep-perl libtest-exception-perl \
    default-mysql-server libdbd-mysql-perl 

COPY build-deps.lst .
RUN cat build-deps.lst | xargs apt install --assume-yes

# make sure libcryptx-perl is found by dh-make-perl and package versions are found
RUN apt-file update && apt-cache dumpavail | dpkg --merge-avail

# This inits the cpan module for dh-make-perl
RUN (echo y;echo o conf prerequisites_policy follow;echo o conf commit)|cpan

COPY build-in-docker.sh /usr/bin/entrypoint.sh
RUN chmod 755 /usr/bin/entrypoint.sh

VOLUME /packages

ENTRYPOINT [ "/usr/bin/entrypoint.sh" ]

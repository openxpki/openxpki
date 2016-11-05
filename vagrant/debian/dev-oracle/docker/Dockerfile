FROM centos:6

#
# Configuration
#
ENV ORACLE_HOME /u01/app/oracle/product/11.2.0/xe
ENV PATH $ORACLE_HOME/bin:$PATH
ENV ORACLE_SID=XE

EXPOSE 1521
EXPOSE 8080

CMD /usr/sbin/startup.sh

#
# Setup
#
# Note: scripts are split to be able to change something in the config and still
# have Docker cache the FS layers with the earlier commands.
#
RUN mkdir /setup

COPY setup/packages /setup/packages
RUN /setup/packages/run.sh

COPY setup/config /setup/config
RUN /setup/config/run.sh

RUN rm -rf /setup

COPY startup.sh /usr/sbin/
RUN chmod +x /usr/sbin/startup.sh

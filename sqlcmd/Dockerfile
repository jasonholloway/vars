FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y curl bash gnupg

SHELL ["/usr/bin/bash", "-c"]

RUN { curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -; } \
  && { curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/msprod.list; } \
  && apt-get update

RUN ACCEPT_EULA=y apt-get install -y --fix-missing mssql-tools unixodbc-dev
RUN cd /usr/local/bin \
  && ln -s /opt/mssql-tools/bin/sqlcmd \
  && ln -s /opt/mssql-tools/bin/bcp

RUN apt-get install -y libcurl4-openssl-dev

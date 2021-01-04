# Get the docker image version passed by arguments
ARG IMAGE_VERSION
FROM $IMAGE_VERSION

#mcr.microsoft.com/mssql/server:2019-latest

# Switch to root user for access to apt-get install
USER root

# Install dos2unix to convert end-of-line from windows to unix pattern
RUN apt-get -y update  && \
        apt-get install -y dos2unix

# Get the SA default password passed by arguments
ARG SA_PASSWORD

# Set env variables
ENV ACCEPT_EULA=Y \
    MSSQL_SA_PASSWORD=$SA_PASSWORD

# Create working directory
RUN mkdir -p /usr/src/app; chmod 777 /usr/src/app
WORKDIR /usr/src/app

# Copy files to the working directory and run dos2unix tool to convert end-of-line
COPY sql/createdb.sql bin/entrypoint.sh /usr/src/app/
RUN dos2unix *

# Expose the SQL Server port to the host
EXPOSE 1433

HEALTHCHECK --interval=20s --timeout=180s --retries=6 \
  CMD [ "/opt/mssql-tools/bin/sqlcmd -U SA -P "$SA_PASSWORD" -Q 'SELECT Name from sys.Databases;'" ]

# Switch to mssql user run the entrypoint script to start SQL Server
#USER mssql
#ENTRYPOINT /bin/bash ./entrypoint.sh
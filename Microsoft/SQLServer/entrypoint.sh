#start SQL Server and run the script to create the DB
/opt/mssql/bin/sqlservr; \
/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "Admin@2020" -b -i /usr/src/app/createdb.sql
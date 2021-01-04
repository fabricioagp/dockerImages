Use MASTER
GO

IF EXISTS 
   (
     SELECT name FROM master.dbo.sysdatabases 
     WHERE name = N'sandbox'
    )
BEGIN
    SELECT 'Database Sandbox already Exists!' AS Message
END
ELSE
BEGIN
    CREATE DATABASE sandbox
    SELECT 'Database Sandbox successfully created!'
END
GO

SELECT Name from sys.Databases;
GO

exec sp_configure 'contained database authentication', 1
RECONFIGURE
ALTER DATABASE sandbox SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE sandbox SET containment=partial;
ALTER DATABASE sandbox SET MULTI_USER;
GO

USE SANDBOX
GO

IF EXISTS (SELECT 1 FROM sys.sql_logins where name='app_login')
  BEGIN
    SELECT 'Login app_login already Exists!' AS Message
  END
ELSE
  BEGIN
    CREATE LOGIN app_login WITH PASSWORD = 'user@2020';
  END
GO

IF EXISTS (SELECT 1 FROM sys.database_principals where type_desc = 'SQL_USER' and name='app_owner')
  BEGIN
    SELECT 'User app_owner already Exists!' AS Message
  END
ELSE
  BEGIN
    CREATE USER app_owner FOR LOGIN app_login WITH DEFAULT_SCHEMA = dbo;
    GRANT CONNECT TO app_owner;
  END
GO
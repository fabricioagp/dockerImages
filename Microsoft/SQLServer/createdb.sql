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

USE sandbox
GO
create user dusrbdpdpj99 with password = 'user@2020';
SELECT containment_desc FROM sys.databases WHERE name='sandbox'
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
--
USE sandbox
create user dusrbdpdpj99 with password = 'user@2020';
GO
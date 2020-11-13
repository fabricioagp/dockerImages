
# Show all running containers on host machine 
docker ps

Write-Host `n
Write-Host WARNING: If the sqlsrv-sandbox container already exists, it will be removed and recreated.
Write-Host If you do not want to contine, press Ctrl+C to exit.
Write-Host ''
pause

# Remove the container
docker rm sqlsrv-sandbox -f

# Ask for the new SA password
Write-Host `n
$SA_PASSWD = Read-Host -AsSecureString -Prompt "Input the new SA password (The password must be at least 8 characters)"

# Build the SQL Server image
Write-Host `n
Write-Host ===> Building the SQL Server docker image
docker build -t sqlsrv .

# Create docker volume
Write-Host `n
Write-Host ===> Creating Docker volume for data persistence

if ((docker volume ls -f name=mssql-data)) {

    docker volume rm mssql-data
    docker volume create mssql-data

} 
else {

    docker volume create mssql-data

}

# Create the SQL Server container
Write-Host `n
Write-Host ===> Creating SQL Server container
docker run --name sqlsrv-sandbox -v mssql-data:/var/opt/mssql -h sqldb1 -p 1433:1433 -d sqlsrv

# Clean up dungling images
docker container prune -f
docker image prune -f

# Convert the SecureString to standard one
$STD_SA_PASSWD = (New-Object PSCredential "user",$SA_PASSWD).GetNetworkCredential().Password

# Change the SA password
Start-Sleep -s 60
while ((docker inspect -f {{.State.Health.Status}} sqlsrv-sandbox) -ne 'healthy')
{
    Start-Sleep -s 10
}
docker exec -it sqlsrv-sandbox /opt/mssql-tools/bin/sqlcmd -U SA -P "Admin@2020" -b -Q "ALTER LOGIN SA WITH PASSWORD = '$STD_SA_PASSWD'"

# Print log of the container
docker logs sqlsrv-sandbox

# Show all running containers on host machine 
Write-Host `n
Write-Host ===> Find below all containers running on the host
docker ps

# Pause to avoid abruptly exitting
Write-Host ''
pause
# ------------------------------------------------------------------------------
# docker_setup.ps1
# 
# Since: November, 2020
# Author: Fabricio Pinto (fabricioagp@gmail.com)
# Description: This is script is a utility tool that automates the build of a
#              SQL Server docker image and creation of a container running this image. 
#              Also, creates a database called Sandbox, changes the SA password and 
#              gives the option to run custom scripts in the end.
#
#              Basically, it first checks if the container sqlsrv-sandbox exists. 
#              If so, it is removed. Then, asks for the new SA password that will be
#              changed later. Builds the image using custom docker file, creates/recreates 
#              the docker volume mssql-data which is used for data persistence. In this
#              step it also wipes the directory of the volume to ensure no previous 
#              installation wil be used. Then, creates the container sqlsrv-sandbox,
#              cleans up dungling images and containers, and run database related 
#              activities, such as change SA password, creation of Sandbox database 
#              and custom SQL scripts.
#
# 
# DO NOT ALTER OR REMOVE THIS HEADER.
# 
#    MODIFIED               (MM/DD/YY)
#        
#    
# -------------------------------------------------------------------------------

# Set to ask for option whenever errors
$ErrorActionPreference = 'Inquire'

# Function Get-Error
#
# This function evaluates the return code from a command and can exit with error (exit 1) 
# or just print an error message and continue
#
# Parameters:
#   $RC: True of false. Always use $? to get the return code status from the last command
#   $Continue: True of false. Indicate if the process can continue or exit immediately
#   $ProcessName: String. The name of the process.
#
# How to use:
#   Get-Error $? true "Checking whether directory is empty"
#
function Get-Error {
    param ($RC, $Continue, $ProcessName)
    #
    if ((-not $RC) -and (-not $Continue)) 
    {
        Write-Host ERROR: Error on the step $ProcessName. This process will be aborted now!
        exit 1
    }
    elseif ((-not $RC) -and $Continue) 
    {
        Write-Host ERROR: Error on the step $ProcessName. Check log for error details!
    }
}

# Function Test-FullPath
#
# This function evaluates a path and return it to a variable. If it is invalid, it asks 
# twice more before exiting with error (exit 1). In case avalid directory is input in 
# a iteraction, it returns the new value to a variable
#
# Parameters:
#   $filepath: String. A relative path to evaluate
#   $Message: String. The message to be prompt during user interaction
#
# How to use:
#   $DirPath = Test-FullPath C:\Users\User1 "Input a valid directory path"
#
function Test-FullPath {
    param ($filepath, $Message)
    #
    $vContPath = 0
    while (-not (Test-Path -Path $filepath) -and $vContPath -le 1)
    {
        Write-Host ERROR: Invalid Path $filepath! Check the path and input a valid directory path. 
        Write-Host ''
        $filepath = Read-Host -Prompt $Message
        $vContPath++
    }
    if (-not (Test-Path -Path $filepath) -and $vContPath -gt 1)
    {
        Write-Error -Message "Invalid option! This script will be aborted." -Category InvalidArgument 
        exit 1
    }
    else 
    {
        return $filepath 
    }
}

# Function Set-MenuScriptSQL
#
# This is a simple function to print options of a specific menu and return the option 
# to a variable.
#
# Parameters:
#   $filepath: String. A relative path to evaluate
#   $Message: String. The message to be prompt during user interaction
#
# How to use:
#   $MenuOpt = Set-MenuScriptSQL
#
function Set-MenuScriptSQL {
    # prompt to run a specific file or all .sql in a directory 
    Write-Host 'Please, choose an option below:'
    Write-Host ' 1) Run a specific .sql file'
    Write-Host ' 2) Run all .sql files in a directory'
    Write-Host ''
    $Opt = Read-Host -Prompt 'Input your choice'
    Write-Host ''
    return $opt
}

# Start a process to pool the output to a file
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Inquire"
Set-Variable -Name SpoolLogFile -Value $home\sqlserver_docker.out
Start-Transcript -path $SpoolLogFile

# Check if docker is running on the host and abort in case it is not.
if (-not (docker version))
{
    Write-Error -Message 'Error checking Docker service!' -Category ResourceUnavailable `
                -RecommendedAction 'Check if the Docker service is properly running on this host and try again.'
}

# Show the status of the container sqlsrv-sandbox if it exists in this host.
docker ps -a -f name=sqlsrv-sandbox
Get-Error $? true "Listing details of container sqlsrv-sandbox"

Write-Host `n
Write-Host WARNING: If the sqlsrv-sandbox container already exists, it will be removed and recreated.
Write-Host If you do not want to contine, press Ctrl+C to exit.
Write-Host ''
pause

# Remove the container
docker rm sqlsrv-sandbox -f
Get-Error $? false "Removing container sqlsrv-sandbox"

# Ask for the new SA password
Write-Host `n
$SA_PASSWD = Read-Host -AsSecureString -Prompt "Input the new SA password (The password must be at least 8 characters)"

# Build the SQL Server image
Write-Host `n
Write-Host ===> Building the SQL Server docker image
docker build -t sqlsrv .
Get-Error $? false "Creating docker image (docker build)"

# Create docker volume
Write-Host `n
Write-Host ===> Creating Docker volume for data persistence

if (((docker volume ls -f name=mssql-data --format "{{.Name}}") | Measure-Object -line).Lines -gt 0) 
{
    docker volume rm mssql-data
    Get-Error $? false "Removing docker volume mssql-data"
    docker volume create mssql-data
    Get-Error $? false "Creating docker volume mssql-data"
}
else 
{
    docker volume create mssql-data
    Get-Error $? false "Creating docker volume mssql-data"
}

# Wiping the content of mssql-data volume
docker run --rm -v mssql-data:/var/opt/mssql ubuntu rm -rf /var/opt/mssql/data /var/opt/mssql/log /var/opt/mssql/secrets /var/opt/mssql/.system
Get-Error $? false "Wiping the content of mssql-data volume"

# Create the SQL Server container
Write-Host `n
Write-Host ===> Creating SQL Server container
docker run --name sqlsrv-sandbox -v mssql-data:/var/opt/mssql -h sqldb1 -p 1433:1433 -d sqlsrv
Get-Error $? false "Creating docker container sqlsrv-sandbox"

# Clean up dungling images
docker container prune -f
Get-Error $? true "Docker Images Cleanup"
docker image prune -f
Get-Error $? true "Docker Images Cleanup"

# Convert the SecureString to standard one
$STD_SA_PASSWD = (New-Object PSCredential "user",$SA_PASSWD).GetNetworkCredential().Password

# Validating container's state
Write-Host `n
Write-Host Validating the state of container. Only continues when it is healthy
$vContWhile = 0
while (((docker inspect -f "{{.State.Health.Status}}" sqlsrv-sandbox) -ne 'healthy') -and ($vContWhile -le 10))
{
    $vContWhile++
    Start-Sleep -s 10
}

# Change the SA password
Write-Host `n
Write-Host ===> Changing SA password
docker exec sqlsrv-sandbox /opt/mssql-tools/bin/sqlcmd -U SA -P "Admin@2020" -b -Q "ALTER LOGIN SA WITH PASSWORD = '$STD_SA_PASSWD'"
Get-Error $? false "Changing SQL Server SA password"

# Creating Sandbox Dabase 
Write-Host `n
Write-Host ===> Creating the Database and User schemas
docker exec sqlsrv-sandbox /opt/mssql-tools/bin/sqlcmd -U SA -P $STD_SA_PASSWD -b -i /usr/src/app/createdb.sql
Get-Error $? false "Running Create Database script"

# Print log of the container
Write-Host `n
Write-Host ===> Container log
docker logs sqlsrv-sandbox
Get-Error $? true "Container log"

# Show all running containers on host machine 
Write-Host `n
Write-Host ===> List of containers running on the host
docker ps

# Show connection info on the screen
Write-Host `n
Write-Host Find below the details to connect to the Sandbox Database
Write-Host ''
Write-Host Hostname: locahost
Write-Host Port: 1433
Write-Host Database: sandbox
Write-Host Username: SA
Write-Host Password: Password entered earlier

# Running custom SQL scripts
Write-Host `n
Write-Host ===> Running custom database scripts
Write-Host ''
$ScriptsOpt = Read-Host -Prompt "Do you want to run custom SQL scripts against Sandbox database? (Y/N)(Default:N)"
Write-Host ''

# Validate the input. If invalid or different than Y, set default value (N) and continue the script.
if (([string]::IsNullOrWhiteSpace($ScriptsOpt)) -or ($ScriptsOpt -ne 'Y' -and $ScriptsOpt -ne 'N') -or ($ScriptsOpt -eq 'N'))
{
    $ScriptsOpt = 'N'
    Write-Host Script succesfully completed! You can now press Enter to close this windows.
}
# If Y, continue with other options
elseif ($ScriptsOpt -eq 'Y') 
{
    Write-Host IMPORTANT: Only .sql files will be run against the Sandbox database.
    Write-Host ''
    $ScriptRunOpt = Set-MenuScriptSQL
    $vControl = 1
    $vContWrongOpt = 0
    while (($vControl -eq 1) -and ($vContWrongOpt -le 1))
    {
        switch ($ScriptRunOpt) 
        {
            # Option 1: Ask for the script name, run it against the database and exit.
            1 { 
                $ScriptName = Read-Host -Prompt "Input the relative path of the script"
                Write-Host ''
                # Evaluate if the path is valid
                $ScriptName = Test-FullPath $ScriptName "Input the relative path of the script"
                # Copy the file to container and run the script against the sandbox database
                docker cp $ScriptName sqlsrv-sandbox:/usr/src/app
                $CurFileName = Get-ChildItem -Path $ScriptName -Name
                docker exec sqlsrv-sandbox /opt/mssql-tools/bin/sqlcmd -U SA -P $STD_SA_PASSWD -b -d sandbox -i $CurFileName -o /usr/src/app/customScript.out
                docker exec sqlsrv-sandbox cat /usr/src/app/customScript.out
                Get-Error $? true "Running single custom script"
                Write-Host ''
                Write-Host Script succesfully completed! You can now press Enter to close this windows.
                $vControl = 0
                Break
            }
            # Option 2: Run all *.sql scripts from a directory in a loop.
            2 { 
                # Ask for the scripts directory
                $ScriptPath = Read-Host -Prompt "Input the relative path of the scripts directory"
                # Evaluate if the path is valid
                $ScriptPath = Test-FullPath $ScriptPath "Input the relative path of the scripts directory"
                # Check if there are .sql files in the directory. 
                if (Get-ChildItem -Path $ScriptPath -Name -Include *.sql)
                {
                    # Read all .sql files in the directory and loop running all them against the sandbox database
                    Get-ChildItem -Path $ScriptPath -Name -Include *.sql |
                    ForEach-Object -Process `
                    {
                        if (!$_.PSIsContainer) 
                        {
                            # Set the current file name to a variable
                            $fname = $_
                            # Copy the file to container and run the script against the sandbox database
                            docker cp $ScriptPath\$fname sqlsrv-sandbox:/usr/src/app
                            docker exec sqlsrv-sandbox /opt/mssql-tools/bin/sqlcmd -U SA -P $STD_SA_PASSWD -b -d sandbox -i /usr/src/app/$fname -o /usr/src/app/customScript.out
                            docker exec sqlsrv-sandbox cat /usr/src/app/customScript.out
                            Get-Error $? true "Running single custom script"
                        }
                    }
                    Write-Host ''
                    Write-Host Script succesfully completed! You can now press Enter to close this windows.                   
                    $vControl = 0
                    Break
                }
                # If not .sql files, ask for the correct directory path
                else 
                {
                    Write-Host ERROR: There is no .sql file in this directory!
                    Write-Host ''
                    $vControl = 1  
                    $vContWrongOpt++
                    $ScriptRunOpt = Set-MenuScriptSQL 
                }

            }
            # Other option: Exit
            Default {
                Write-Host ERROR: Invalid option.
                Write-Host ''
                $vControl = 1
                $vContWrongOpt++
                $ScriptRunOpt = Set-MenuScriptSQL
            }
        }
    }
}

# Stop spool process
Stop-Transcript

# Pause to avoid abruptly exitting
Write-Host ''
pause
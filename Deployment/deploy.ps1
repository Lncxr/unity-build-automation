# This script assumes AWS.Tools PowerShell modules for S3 and GameLift to have been previously installed
# -----------------------
# Diagnostics
# -----------------------
# $PSVersionTable                                       Your version of PowerShell
# Get-AWSPowerShellVersion                              Use this to determine the version of AWS.Tools you have installed
# Get-AWSPowerShellVersion -ListServiceVersionInfo      Your installed module(s), GameLift and its SDK assembly ver. should be listed here
# Update-AWSToolsModule -CleanUp                        Use this to update AWS.Tools to the latest ver.
# -----------------------

Set-ExecutionPolicy Unrestricted # RemoteSigned

# Dot source relevant functions
. $PSScriptRoot\deploy.functions.ps1

Write-Host 'Starting deployment...'

$path = $args[0]

# -----------------------
# Main Routine
# -----------------------

# Validate build source file directory exists
CheckBuildSourceFilesExist -sourceFilePath $path

# TODO : Enable bucket versioning
WriteToS3Bucket -relativePath $path

# 'CreateBuild' API Operation
$id = CreateGameLiftBuild

# 'CreateFleet' API Operation
CreateFleetFromBuildResult -buildID $id

Write-Host 'Deployment complete!' `
    -BackgroundColor Green

Exit 200
Import-Module -Name 'AWS.Tools.Common'
Import-Module -Name 'AWS.Tools.IdentityManagement'
Import-Module -Name 'AWS.Tools.GameLift'
Import-Module -Name 'AWS.Tools.S3'

# Do not enter your access credentials manually, otherwise they'll be readable via your command history
# $access = aws configure get aws_access_key_id
# $secret = aws configure get aws_secret_access_key

# Assign AWS credentials, shouldn't need this if your environment (.aws) is set up correctly
# Set-AWSCredential `
#                 -AccessKey $access `
#                 -SecretKey $secret `
#                 -StoreAs default

# Adapt this for your own bucket + descriptive name for your application
$bucket = 'your-deployment-provider-bucket'
$key = 'AutomatedBuild.zip'

Function CheckBuildSourceFilesExist() {
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = 'Path to the latest build source files.')]
        [ValidateNotNullOrEmpty()]
        [string]$sourceFilePath
    )

    $result = Test-Path -Path $sourceFilePath'\'$key -PathType Leaf

    Write-Host 'Result of CheckBuildSourceFilesExist is : ' $result
    
    If (!$result) {
        Write-Host 'No folder found, attempting to compress build source files...'
    
        CompressBuildFolder -relativePath $path
    }
    Else {
        Write-Host 'Found build source files! Uploading to S3...'
    }
}

# Creates a .zip file to be uploaded to S3 for deployment via GameLift
Function CompressBuildFolder {
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = 'Relative path to the latest build to compress.')]
        [ValidateNotNullOrEmpty()]
        [string]$relativePath
    )

    Write-Host 'Compressing build source files at : ' $path

    Compress-Archive -Path $relativePath'\*' `
        -DestinationPath $relativePath'\'$key
}

# Uploads relevant build files to S3 as a compressed .zip archive
Function WriteToS3Bucket {
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = 'Please input the relative path to the latest build.')]
        [string]$relativePath
    )

    $result = Test-Path -Path $relativePath

    # Guard case
    If(!$result)
    {
        Throw 'Invalid file path!'
    }

    Write-Host 'Retrieving build from : ' $relativePath

    # Sanity check
    If (Test-S3Bucket -BucketName $bucket) {
        Write-Verbose 'Test-S3Bucket : $bucket found!'
    }
    Else {
        Write-Error 'Test-S3Bucket : $bucket could not be found!'

        Exit 404
    }

    # Use enumerator when working with unzipped files (multi-item)
    # $sourceFiles = Get-ChildItem $RelativePath

    # For a single item
    $sourceFolder = Get-Item $relativePath'\'$key

    # TODO : This unfortunately doesn't return anything, investigate alt. API calls
    Write-S3Object -BucketName $bucket -File $sourceFolder
}

# Retrieves relevant server app binaries from S3 and creates a new GameLift build
Function CreateGameLiftBuild {
    Write-Host 'Creating GameLift build via S3'

    $s3Response = Get-S3Bucket -BucketName $bucket 

    Write-Host 'Bucket name is : '$s3Response.BucketName

    # New-GMLBuild requires an IAM role allowing GameLift read-access to the S3 bucket
    # Provision an IAM role and adapt the label here to reference it
    $role = Get-IAMRole -RoleName 'Your_GameLift_Deployment_Provider_Role'

    # Debug
    $object = Get-S3Object -BucketName $s3Response.BucketName -Key $key

    # Within the GameLift mgmt. console you'll see build size listed as '0'
    # Don't panic - this is because it's hosted via S3, you can debug source file size below
    Write-Host 'GetObject via S3 : ' $object.Key ' sizeof : ' $object.Size

    $buildResult = New-GMLBuild -Name 'DummyServerApp' `
        -Version '0.0.1' `
        -StorageLocation_Bucket $s3Response.BucketName `
        -StorageLocation_Key $key `
        -StorageLocation_RoleArn $role.Arn `
        -OperatingSystem AMAZON_LINUX

    # Return BuildID (string)
    return $buildResult.Build.BuildId
}

# Spins up a fleet of EC2 instances hosting the server app
Function CreateFleetFromBuildResult {
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = 'Please supply the unique ID of your GameLift build.')]
        [ValidateNotNullOrEmpty()]
        [string]$buildID
    )

    # Guard case
    If($buildResult = $null) {
        Write-Host 'Cannot create fleet, supplied build result is null!' -ForegroundColor Red
        Exit 400
    }

    Write-Host 'Spinning up fleet from build : ' $buildResult.Build.BuildId

    # AWS.Tools.GameLift doesn't expose an alias for 'ServerProcess' so we have to pipe data into an object ref manually
    $serverProcess = New-Object Amazon.GameLift.Model.ServerProcess

    # ...and also doesn't expose an alias for 'IpPermission'
    $permission = New-Object Amazon.GameLift.Model.IpPermission
    
    # TODO : LaunchPath should be relative? Check if GameLift automatically prepends '/local/game/'
    $serverProcess.LaunchPath = '/local/game/dummy-server-app.x86_64'
    $serverProcess.Parameters = '-logFile /local/game/logs/server.log -batchmode -nographics'
    $serverProcess.ConcurrentExecutions = 2

    # An 'IpProtocol' object ref resolves to a string value, let's fudge it
    $permission.Protocol = 'TCP'
    $permission.FromPort = 7000
    $permission.ToPort = 8000
    $permission.IpRange = '0.0.0.0/0'

    New-GMLFleet -BuildId $buildID `
        -Name 'dummy-server-app-fleet' `
        -Description 'Simple test fleet, max 2 conc. users' `
        -FleetType ON_DEMAND `
        -EC2InstanceType c4.large `
        -RuntimeConfiguration_ServerProcess $serverProcess `
        -RuntimeConfiguration_MaxConcurrentGameSessionActivation 2 `
        -RuntimeConfiguration_GameSessionActivationTimeoutSecond 120 `
        -EC2InboundPermission $permission

    # Dispose of object refs
    Remove-Variable serverProcess | Remove-Variable permission
}
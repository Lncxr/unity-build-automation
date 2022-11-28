@ECHO ON

Rem Version of Unity currently used in your project - for me this is currently 2021.3.11f1
SET UnityVersion=%~1

Rem Windows, Linux, MacOS, etc...
SET BuildTarget=%~2

SET DeploymentDirectory=%CD%

Rem Adapt this based on where you store your project folder
SET BuildDirectory=D:\Unity\unity-build-automation\Builds

SET UnityEditorDirectory=C:\Program Files\Unity\Hub\Editor\%UnityVersion%\Editor

Rem Ensure this script has access to your Unity Editor (via Program Files)
CD /D %UnityEditorDirectory%

Rem Run Unity in silent mode and build the application binaries
Unity.exe -quit -batchMode -projectPath %BuildDirectory:~,31% -executeMethod BuildScript.%BuildTarget%

Rem Navigate back to the infrastructure directory to invoke our deployment scripts
CD /D %DeploymentDirectory%

SET PSScript= %CD%\deploy.ps1

SET PowerShellDir= C:\Windows\System32\WindowsPowerShell\v1.0

CD /D "%PowerShellDir%"

Powershell -ExecutionPolicy Bypass -Command "& '%PSScript%' '%BuildDirectory%'"

EXIT /B
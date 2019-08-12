[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try {
	Import-VstsLocStrings "$PSScriptRoot\task.json"

    # Get inputs.
    $input_errorActionPreference = Get-VstsInput -Name 'errorActionPreference' -Default 'Stop'
    switch ($input_errorActionPreference.ToUpperInvariant()) {
        'STOP' { $ErrorActionPreference = 'Stop' }
        'CONTINUE' { $ErrorActionPreference = 'Continue'}
        'SILENTLYCONTINUE' { $ErrorActionPreference='SilentlyContinue'}
        default {
            Write-Error (Get-VstsLocString -Key 'PS_InvalidErrorActionPreference' -ArgumentList $input_errorActionPreference)
        }
    }

    $input_SwaggerURL = Get-VstsInput -Name 'SwaggerURL' -Require
    $input_Namespace = Get-VstsInput -Name 'Namespace' -Require
	$input_AddServiceClientCredentials = Get-VstsInput -Name 'AddServiceClientCredentials' -AsBool -Require
  

    Write-Output "Inputs..."
	Write-Output "Working Directory: $env:SYSTEM_DEFAULTWORKINGDIRECTORY"
	Write-Output "PSScriptRoot: $PSScriptRoot"
    Write-Output "Swagger URL: $input_SwaggerURL"
    Write-Output "Namespace: $input_Namespace"
	Write-Output "AddServiceClientCredentials: $input_AddServiceClientCredentials"
	Write-Output "ErrorActionPreference : $input_errorActionPreference"


	nuget install eShopWorld.AutoRest.CreateProject -OutputDirectory $env:SYSTEM_DEFAULTWORKINGDIRECTORY

	$packageDirectory = Get-ChildItem -Directory -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -Filter "eshopworld.autorest.createproject*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
	$packageDirName = $packageDirectory.Name

	Write-Output "full path to downloaded tool $env:SYSTEM_DEFAULTWORKINGDIRECTORY\$packageDirName\tools"

	$env:path+=";C:\Windows\ServiceProfiles\NetworkService\AppData\Roaming\npm"
	$env:path+=";$env:SYSTEM_DEFAULTWORKINGDIRECTORY\$packageDirName\tools"

	#if autorest is installed, skip the set up
	$autorestNPMCheck = npm ls -g autorest
	Write-Host $autorestNPMCheck

	if (!$autorestNPMCheck -or $autorestNPMCheck.Count -lt 2 -or !$autorestNPMCheck[1].Contains("autorest"))
	{
		Write-Output "invoking 'npm install -g autorest@latest'"
		npm install -g autorest@latest
	}

	try
	{
		Write-Output "Retrieving definition json from $input_SwaggerURL"
		Invoke-WebRequest $input_SwaggerURL -o $env:SYSTEM_DEFAULTWORKINGDIRECTORY/definition.json -ErrorAction Stop
	}
	catch
	{
		Write-Error "Problem retrieving definition file $input_SwaggerURL"
        exit
	}

	$credentialSwitch = if ($input_AddServiceClientCredentials) {"--add-credentials"} else {""}

	Write-Output "Invoking 'autorest --input-file=$env:SYSTEM_DEFAULTWORKINGDIRECTORY\definition.json --csharp --output-folder=$env:SYSTEM_DEFAULTWORKINGDIRECTORY\output --namespace=$input_Namespace $credentialSwitch'"
	$autorestOutput = autorest --input-file=$env:SYSTEM_DEFAULTWORKINGDIRECTORY\definition.json --csharp --output-folder=$env:SYSTEM_DEFAULTWORKINGDIRECTORY\output --namespace=$input_Namespace $credentialSwitch	--verbose --debug 2>&1
	if ($LASTEXITCODE -ne 0)
	{
		Write-Error "autorest command failed with $autorestOutput"
		exit
	}

	$createProjectOutput = dotnet autorest-createproject -s $env:SYSTEM_DEFAULTWORKINGDIRECTORY\definition.json -o $env:SYSTEM_DEFAULTWORKINGDIRECTORY\output 2>&1
	if ($LASTEXITCODE -ne 0)
	{
		Write-Error "dotnet autorest-createproject command failed with $createProjectOutput"
		exit
	}

	popd

	pushd $env:SYSTEM_DEFAULTWORKINGDIRECTORY\output
	$buildOutput = dotnet build -c release 2>&1

	if ($LASTEXITCODE -ne 0)
	{
		Write-Error "dotnet build command failed with $buildOutput"
		exit
	}

	popd
} finally {
	Trace-VstsLeavingInvocation $MyInvocation
}
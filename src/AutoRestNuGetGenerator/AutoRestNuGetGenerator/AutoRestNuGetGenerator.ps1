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
  

    Write-Output "Inputs..."
    Write-Output "Swagger URL: $input_SwaggerURL"
    Write-Output "Namespace: $input_Namespace"
	Write-Output "ErrorActionPreference : $input_errorActionPreference"

	$env:path+=";C:\Windows\ServiceProfiles\NetworkService\AppData\Roaming\npm"

	Write-Output "invoking 'npm install -g autorest@latest'"
	npm install -g autorest@latest

	Write-Output "invoking 'autorest --reset'"
	autorest --reset

	try
	{
		Write-Output "Retrieving definition json from $input_SwaggerURL"
		Invoke-WebRequest $input_SwaggerURL -o definition.json -ErrorAction Stop
	}
	catch
	{
		Write-Error "Problem retrieving definition file $input_SwaggerURL"
        exit
	}

	autorest --input-file=definition.json --csharp --output-folder=output --namespace=$input_Namespace
	dotnet-autorest-createproject/dotnet autorest-createproject -s definition.json -o output

	pushd output

	dotnet build -c release

	popd
} finally {
	Trace-VstsLeavingInvocation $MyInvocation
}
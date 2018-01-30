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
    $input_OutputFolder = Get-VstsInput -Name 'OutputFolder' -Require
  

    Write-Output "Inputs..."
    Write-Output "Swagger URL: $input_SwaggerURL"
    Write-Output "output folder: $input_OutputFolder"
	Write-Output "ErrorActionPreference : $input_errorActionPreference"

	$env:path+=";C:\Windows\ServiceProfiles\NetworkService\AppData\Roaming\npm"
	$env:path+=";C:\tools\dotnet-autorest-createproject"

	try
	{
		Write-Output " invoking 'Update-Module DevOpsFlex.Automation.PowerShell -Force -ErrorAction Stop'"
		Update-Module DevOpsFlex.Automation.PowerShell -Force -ErrorAction Stop
	}
	catch
	{
		Write-Output "invoking 'Install-Module DevOpsFlex.Automation.PowerShell -Force -Scope CurrentUser -ErrorAction $input_errorActionPreference'"
		Install-Module DevOpsFlex.Automation.PowerShell -Force -Scope CurrentUser -ErrorAction $input_errorActionPreference
	}

	Write-Output "invoking 'npm install -g autorest@latest'"
	npm install -g autorest@latest

	Write-Output "invoking 'autorest --reset'"
	autorest --reset

	New-AutoRestProject $input_SwaggerURL $input_OutputFolder

} finally {
	Trace-VstsLeavingInvocation $MyInvocation
}
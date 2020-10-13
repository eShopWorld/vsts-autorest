[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try {
    Import-VstsLocStrings "$PSScriptRoot\task.json"

    # Get inputs.
    $input_errorActionPreference = Get-VstsInput -Name 'errorActionPreference' -Default 'Stop'
    switch ($input_errorActionPreference.ToUpperInvariant()) {
        'STOP' { $ErrorActionPreference = 'Stop' }
        'CONTINUE' { $ErrorActionPreference = 'Continue' }
        'SILENTLYCONTINUE' { $ErrorActionPreference = 'SilentlyContinue' }
        default {
            Write-Error (Get-VstsLocString -Key 'PS_InvalidErrorActionPreference' -ArgumentList $input_errorActionPreference)
        }
    }

    $input_SwaggerURL = Get-VstsInput -Name 'SwaggerURL'
    $input_SwaggerPath = Get-VstsInput -Name 'SwaggerPath'
    $input_Namespace = Get-VstsInput -Name 'Namespace' -Require
    $input_ClientName = Get-VstsInput -Name 'Clientname'
    $input_AddServiceClientCredentials = Get-VstsInput -Name 'AddServiceClientCredentials' -AsBool -Require
    $input_OpenAPIv3 = Get-VstsInput -Name 'OpenAPIv3' -AsBool
    $input_BuildClientProject = Get-VstsInput -Name 'BuildClient' -AsBool
    $input_BuildArguments = Get-VstsInput -Name 'BuildArguments'


    Write-Output "Input Parameters..."
    Write-Output "Working Directory: $env:SYSTEM_DEFAULTWORKINGDIRECTORY"
    Write-Output "PSScriptRoot: $PSScriptRoot"
    Write-Output "Swagger URL: $input_SwaggerURL"
    Write-Output "Swagger Path: $input_SwaggerPath"
    Write-Output "Namespace: $input_Namespace"
    Write-Output "Clientname: $input_ClientName"
    Write-Output "AddServiceClientCredentials: $input_AddServiceClientCredentials"
    Write-Output "Open API V3: $input_OpenAPIv3"
    Write-Output "BuildClientProject : $input_BuildClientProject"
    Write-Output "BuildArguments : $input_BuildArguments"
    Write-Output "ErrorActionPreference : $input_errorActionPreference"

    if ($input_BuildClientProject) {
        Write-Output "Installing the eShopWorld.AutoRest.CreateProject nuget package"

        nuget install eShopWorld.AutoRest.CreateProject -OutputDirectory $env:SYSTEM_DEFAULTWORKINGDIRECTORY

        $packageDirName = (Get-ChildItem -Directory -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -Filter "eshopworld.autorest.createproject*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name

        Write-Output "Full path to the eShopWorld.AutoRest.CreateProject nuget package $env:SYSTEM_DEFAULTWORKINGDIRECTORY\$packageDirName"
        
        $env:path += ";$env:SYSTEM_DEFAULTWORKINGDIRECTORY\$packageDirName\tools"
    }    

    $env:path += ";C:\Windows\ServiceProfiles\NetworkService\AppData\Roaming\npm"
    
    #if autorest is installed, skip the set up
    $autorestNPMCheck = npm ls -g autorest
    Write-Host $autorestNPMCheck

    if (!$autorestNPMCheck -or $autorestNPMCheck.Count -lt 2 -or !$autorestNPMCheck[1].Contains("autorest")) {
        Write-Output "Autorest not found locally, invoking 'npm install -g autorest@latest'"
        npm install -g autorest@latest
    }

    if (Test-Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY\definition.json) {
        Write-Output "Removing previous swagger definition file"
        Remove-Item $env:SYSTEM_DEFAULTWORKINGDIRECTORY\definition.json -Force
    }
  
    if (Test-Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY\output) {
        Write-Output "Removing previous autorest output files"
        Remove-Item $env:SYSTEM_DEFAULTWORKINGDIRECTORY\output -Force -Recurse
    }

    if ($input_SwaggerURL.Length -gt 0) {
        try {
            Write-Output "Retrieving definition json from $input_SwaggerURL"
            Invoke-WebRequest $input_SwaggerURL -o $env:SYSTEM_DEFAULTWORKINGDIRECTORY/definition.json -ErrorAction Stop
        }
        catch {
            $failed = $true
            Write-VstsTaskError -Message "Problem retrieving definition file $input_SwaggerURL"
        }
    }
    elseif ($input_SwaggerPath -gt 0) {
        try {
            Copy-Item -Path $input_SwaggerPath -Destination $env:SYSTEM_DEFAULTWORKINGDIRECTORY/definition.json
        }
        catch {
            $failed = $true
            Write-VstsTaskError -Message "Problem copying swagger file $input_SwaggerPath"
        }
    }
    else {
        $failed = $true
        Write-VstsTaskError -Message "No Swagger URL or Path to definition.json file provided."
    }

    $credentialSwitch = if ($input_AddServiceClientCredentials) { "--add-credentials" } else { "" }
    $v3Switch = if ($input_OpenAPIv3) { "--v3" } else { "" }
    $clientNameSwitch = if ($input_ClientName) { "--override-client-name=$input_ClientName" } else { "" }

    Write-Output "Invoking 'autorest --input-file=$env:SYSTEM_DEFAULTWORKINGDIRECTORY\definition.json --csharp --output-folder=$env:SYSTEM_DEFAULTWORKINGDIRECTORY\output --namespace=$input_Namespace $clientNameSwitch $credentialSwitch $v3Switch'"
    $autorestOutput = autorest --input-file=$env:SYSTEM_DEFAULTWORKINGDIRECTORY\definition.json --csharp --output-folder=$env:SYSTEM_DEFAULTWORKINGDIRECTORY\output --namespace=$input_Namespace $clientNameSwitch $credentialSwitch $v3Switch --verbose --debug 2>&1
    if ($LASTEXITCODE -ne 0) {
        $failed = $true
        Write-VstsTaskError -Message "autorest command failed with $autorestOutput"
    }

    if ($input_BuildClientProject) {
        Write-Output "Invoking 'dotnet autorest-createproject -s $env:SYSTEM_DEFAULTWORKINGDIRECTORY\definition.json -o $env:SYSTEM_DEFAULTWORKINGDIRECTORY\output 2>&1'"
        $createProjectOutput = dotnet autorest-createproject -s $env:SYSTEM_DEFAULTWORKINGDIRECTORY\definition.json -o $env:SYSTEM_DEFAULTWORKINGDIRECTORY\output 2>&1
        if ($LASTEXITCODE -ne 0) {
            $failed = $true
            Write-VstsTaskError -Message "dotnet autorest-createproject command failed with $createProjectOutput"
        }
    
        $buildSwitch = if ($input_BuildArguments) { $input_BuildArguments } else { "" }
        Push-Location $env:SYSTEM_DEFAULTWORKINGDIRECTORY\output

        Write-Output "Invoking 'dotnet build $buildSwitch' to create the nuget package"
        dotnet build $buildSwitch
        Pop-Location

        if ($LASTEXITCODE -ne 0)
        {
            $failed = $true
            Write-VstsTaskError -Message "dotnet build command failed"
        }
    }

    Write-Output "Package created..."
    Get-ChildItem -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY\output -Filter '*.nupkg' -Recurse

    if ($failed) {
        Write-VstsSetResult -Result 'Failed' -Message "Error detected" -DoNotThrow
    }
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
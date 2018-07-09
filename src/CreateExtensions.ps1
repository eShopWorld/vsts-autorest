$path = npm prefix -g

$tfxCli = Join-Path $path "node_modules\tfx-cli\_build\tfx-cli.js"

$extensions = Get-ChildItem -Path . -Filter *-extension.json -Recurse -Force

$extensions | % { $extensionArgs += $_.FullName + " " }

Write-Output "Calling command: 'node $tfxCli extension create --manifest-globs $extensionArgs'"

Invoke-Expression -Command "node '$tfxCli' extension create --manifest-globs $extensionArgs"
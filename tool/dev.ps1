<#
.SYNOPSIS
  Trakta developer script for Windows: a shortcut for tool/bin/dev.dart.

.DESCRIPTION
  Run from anywhere inside the repository:

    powershell -ExecutionPolicy Bypass -File tool\dev.ps1            # everything (setup + check)
    powershell -ExecutionPolicy Bypass -File tool\dev.ps1 setup      # pub get, rules sync, codegen
    powershell -ExecutionPolicy Bypass -File tool\dev.ps1 check      # analyze, all tests, schema, sync and offline checks
    powershell -ExecutionPolicy Bypass -File tool\dev.ps1 rules      # verify Skatteverket rates (network)

  On macOS and Linux, run `dart tool/bin/dev.dart` with the same arguments.
  Output is also written to .dev-logs\last-run.log (git-ignored).
#>
param([ValidateSet('all', 'setup', 'check', 'rules')][string]$Task = 'all')

$Root = Split-Path -Parent $PSScriptRoot
dart (Join-Path $Root 'tool\bin\dev.dart') $Task
exit $LASTEXITCODE

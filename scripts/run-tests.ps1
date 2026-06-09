<#
    Runs the Merge Control Apex test suite in the target org.

    Usage:
      pwsh scripts/run-tests.ps1                 # run all local tests, one synchronous run
      pwsh scripts/run-tests.ps1 -PerClass       # run each test class separately, summarized
      pwsh scripts/run-tests.ps1 -TargetOrg gsgDEV
      pwsh scripts/run-tests.ps1 -PerClass -StopOnFail
#>
param(
    [string]$TargetOrg = "",          # defaults to the configured target-org when blank
    [switch]$PerClass,                # run one `sf` invocation per test class instead of all at once
    [switch]$StopOnFail               # (with -PerClass) stop at the first class with a failure
)

$ErrorActionPreference = "Stop"
$repoRoot   = Split-Path -Parent $PSScriptRoot
$classesDir = Join-Path $repoRoot "force-app/main/default/classes"
$resultsDir = Join-Path $repoRoot "test-results"
if (-not (Test-Path $resultsDir)) { New-Item -ItemType Directory -Path $resultsDir | Out-Null }

# discover every *_TEST class in the repo
$testClasses = Get-ChildItem -Path $classesDir -Filter "*_TEST.cls" |
    ForEach-Object { $_.BaseName } | Sort-Object

if (-not $testClasses) { Write-Error "No *_TEST.cls classes found under $classesDir"; exit 1 }

# build the org flag (omit when blank so the configured default is used)
$orgArgs = @()
if ($TargetOrg) { $orgArgs = @("--target-org", $TargetOrg) }

Write-Host "Found $($testClasses.Count) test classes." -ForegroundColor Cyan

if (-not $PerClass) {
    # one synchronous run of every test class; human + json output saved to test-results/
    $classArgs = @()
    foreach ($c in $testClasses) { $classArgs += @("--tests", $c) }

    # NOTE: --synchronous only supports a single class, so the run-all path runs async + waits
    & sf apex run test @orgArgs @classArgs `
        --result-format human `
        --code-coverage `
        --wait 30 `
        --output-dir $resultsDir
    exit $LASTEXITCODE
}

# --- per-class mode: one invocation per class, collect pass/fail ---
$summary = @()
$anyFail = $false
foreach ($c in $testClasses) {
    Write-Host "`n=== $c ===" -ForegroundColor Cyan
    & sf apex run test @orgArgs --tests $c --result-format human --synchronous --wait 30
    $code = $LASTEXITCODE
    $status = if ($code -eq 0) { "PASS" } else { "FAIL"; $anyFail = $true }
    $summary += [pscustomobject]@{ TestClass = $c; Result = $status; ExitCode = $code }
    if ($StopOnFail -and $code -ne 0) { Write-Host "Stopping on first failure." -ForegroundColor Yellow; break }
}

Write-Host "`n================ SUMMARY ================" -ForegroundColor Cyan
$summary | Format-Table -AutoSize
if ($anyFail) { exit 1 } else { exit 0 }

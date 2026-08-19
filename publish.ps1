<#
.SYNOPSIS
  Commit and push. If the resume source changed, also compile a new versioned PDF.
  If only docs/scripts changed, just git add / commit / push.

.EXAMPLE
  .\publish.ps1 -Message "Update Buildplate bullets"

.EXAMPLE
  .\publish.ps1 -Message "Split editing docs out of README"

.EXAMPLE
  .\publish.ps1
#>
param(
  [string]$Message = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$texFile = "prajwal_resume_2026_1page.tex"
$styleFile = "resume-style.tex"
$footerFile = "coop_footer.png"
$resumeSources = @($texFile, $styleFile, $footerFile)

if (-not (Test-Path $texFile)) {
  Write-Error "Missing $texFile"
}

$projectFiles = @(
  $texFile,
  $styleFile,
  $footerFile,
  "preview.png",
  "preview/index.html",
  "README.md",
  "EDITING.md",
  "watch.ps1",
  "publish.ps1",
  ".gitignore",
  ".latexmkrc",
  ".vscode/settings.json"
)

function Test-GitHeadExists {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  git rev-parse --verify HEAD 2>$null | Out-Null
  $ok = ($LASTEXITCODE -eq 0)
  $ErrorActionPreference = $prev
  return $ok
}

function Test-ResumeSourceChanged {
  if (-not (Test-GitHeadExists)) {
    return $true
  }

  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  foreach ($f in $resumeSources) {
    if (-not (Test-Path $f)) {
      continue
    }
    $porcelain = git status --porcelain -- $f 2>$null
    if ($porcelain) {
      $ErrorActionPreference = $prev
      return $true
    }
  }
  $ErrorActionPreference = $prev
  return $false
}

function Invoke-GitPush {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null | Out-Null
  $hasUpstream = ($LASTEXITCODE -eq 0)
  $ErrorActionPreference = $prev

  if ($hasUpstream) {
    git push
  }
  else {
    git push -u origin HEAD
  }
  if ($LASTEXITCODE -ne 0) {
    Write-Error "git push failed."
  }
}

function Invoke-CommitAndPush {
  param(
    [string]$CommitMessage,
    [string[]]$Paths
  )

  $existing = @(Get-ChildItem -File -Filter "Prajwal_UBC_1_Page_Resume_*.pdf" -ErrorAction SilentlyContinue)
  $toAdd = New-Object System.Collections.Generic.List[string]
  foreach ($p in $Paths) {
    if (Test-Path $p) {
      [void]$toAdd.Add($p)
    }
  }
  foreach ($pdf in $existing) {
    [void]$toAdd.Add($pdf.Name)
  }

  git add -- $toAdd.ToArray()

  $status = git status --porcelain
  if (-not $status) {
    Write-Host "Nothing to publish."
    exit 0
  }

  git commit -m $CommitMessage
  if ($LASTEXITCODE -ne 0) {
    Write-Error "git commit failed."
  }

  Invoke-GitPush
}

$resumeChanged = Test-ResumeSourceChanged
$existingPdf = @(Get-ChildItem -File -Filter "Prajwal_UBC_1_Page_Resume_*.pdf" -ErrorAction SilentlyContinue)
$needsBuild = $resumeChanged -or ($existingPdf.Count -eq 0)

if ([string]::IsNullOrWhiteSpace($Message)) {
  if ($needsBuild) {
    $Message = "Update resume"
  }
  else {
    $Message = "Update project files"
  }
}

if (-not $needsBuild) {
  Write-Host "Resume source unchanged - committing project files only (no new PDF version)." -ForegroundColor Cyan
  Invoke-CommitAndPush -CommitMessage $Message -Paths $projectFiles
  Write-Host "Committed and pushed (resume PDF unchanged)." -ForegroundColor Green
  exit 0
}

# Resume changed (or no versioned PDF yet): compile + version bump
$existing = 0
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
if (Test-GitHeadExists) {
  $countRaw = git rev-list --count --grep='\[skip ci\]' --invert-grep HEAD 2>$null
  if ($countRaw -match '^\d+$') {
    $existing = [int]$countRaw
  }
}
$ErrorActionPreference = $prevEap
$version = $existing + 1

$tz = [TimeZoneInfo]::FindSystemTimeZoneById("Pacific Standard Time")
$date = [TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $tz).ToString("yyyy-MM-dd")
$pdfName = "Prajwal_UBC_1_Page_Resume_${date}_v${version}.pdf"

Write-Host "Resume source changed - building $pdfName ..." -ForegroundColor Cyan

$buildJob = "_publish_build"
$ErrorActionPreference = "Continue"
& latexmk -pdf -f -interaction=nonstopmode -file-line-error ("-jobname=" + $buildJob) $texFile
$ErrorActionPreference = "Stop"
if (-not (Test-Path ($buildJob + ".pdf"))) {
  Write-Error "LaTeX compile failed (no PDF produced)."
}

Get-ChildItem -File -Filter "Prajwal_UBC_1_Page_Resume_*.pdf" -ErrorAction SilentlyContinue |
  Remove-Item -Force

Copy-Item -Force ($buildJob + ".pdf") $pdfName

$ErrorActionPreference = "Continue"
& latexmk -C ("-jobname=" + $buildJob) $texFile 2>$null
Remove-Item -Force ($buildJob + ".pdf") -ErrorAction SilentlyContinue
$ErrorActionPreference = "Stop"

if (Get-Command pdftoppm -ErrorAction SilentlyContinue) {
  $ErrorActionPreference = "Continue"
  & pdftoppm -png -r 200 -f 1 -l 1 $pdfName preview_tmp
  $ErrorActionPreference = "Stop"
  if (Test-Path "preview_tmp-1.png") {
    Move-Item -Force "preview_tmp-1.png" "preview.png"
  }
}
else {
  Write-Warning "pdftoppm not found; skipping preview.png update."
}

if (Test-Path "README.md") {
  $readme = Get-Content -Raw "README.md"
  $readme = [regex]::Replace(
    $readme,
    'Prajwal_UBC_1_Page_Resume_\d{4}-\d{2}-\d{2}_v\d+\.pdf',
    $pdfName
  )
  $readme = $readme.Replace("RESUME_PDF_PLACEHOLDER", $pdfName)
  Set-Content -Path "README.md" -Value $readme -NoNewline
}

$ErrorActionPreference = "Continue"
git ls-files -- "Prajwal_UBC_1_Page_Resume_*.pdf" 2>$null | ForEach-Object {
  if (-not (Test-Path $_)) {
    git rm --quiet --ignore-unmatch -- $_
  }
}
$ErrorActionPreference = "Stop"

$pathsForCommit = $projectFiles + @($pdfName)
Invoke-CommitAndPush -CommitMessage $Message -Paths $pathsForCommit
Write-Host "Published $pdfName locally and pushed to GitHub." -ForegroundColor Green

<#
.SYNOPSIS
  Compile the resume locally, write one versioned PDF, refresh README preview,
  commit, and push. No GitHub Actions build.

.EXAMPLE
  .\publish.ps1 -Message "Update Buildplate bullets"

.EXAMPLE
  .\publish.ps1
#>
param(
  [string]$Message = "Update resume"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$texFile = "prajwal_resume_2026_1page.tex"
if (-not (Test-Path $texFile)) {
  Write-Error "Missing $texFile"
}

# --- Version = upcoming user commit count (exclude [skip ci] commits) ---
# Empty repos have no HEAD yet; native git stderr must not stop the script.
$existing = 0
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
git rev-parse --verify HEAD 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
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

Write-Host "Building $pdfName ..." -ForegroundColor Cyan

# Compile with a temp jobname, then copy to versioned name (keep autocompile.pdf untouched)
$buildJob = "_publish_build"
$ErrorActionPreference = "Continue"
& latexmk -pdf -f -interaction=nonstopmode -file-line-error ("-jobname=" + $buildJob) $texFile
$ErrorActionPreference = "Stop"
if (-not (Test-Path "$buildJob.pdf")) {
  Write-Error "LaTeX compile failed (no PDF produced)."
}

# Remove previous versioned PDFs from the working tree
Get-ChildItem -File -Filter "Prajwal_UBC_1_Page_Resume_*.pdf" -ErrorAction SilentlyContinue |
  Remove-Item -Force

Copy-Item -Force "$buildJob.pdf" $pdfName

# Clean publish build aux
$ErrorActionPreference = "Continue"
& latexmk -C ("-jobname=" + $buildJob) $texFile 2>$null
Remove-Item -Force "$buildJob.pdf" -ErrorAction SilentlyContinue
$ErrorActionPreference = "Stop"

# README preview image
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

# Point README download link at this PDF
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

# Stage sources + artifacts; record deletions of old PDFs
$toAdd = @(
  $texFile,
  "coop_footer.png",
  $pdfName,
  "preview.png",
  "README.md",
  "watch.ps1",
  "publish.ps1",
  ".gitignore",
  ".latexmkrc",
  ".vscode/settings.json"
) | Where-Object { Test-Path $_ }

git add -- $toAdd

# Stage deleted old versioned PDFs (no-op on empty repos)
$ErrorActionPreference = "Continue"
git ls-files -- "Prajwal_UBC_1_Page_Resume_*.pdf" 2>$null | ForEach-Object {
  if (-not (Test-Path $_)) {
    git rm --quiet --ignore-unmatch -- $_
  }
}
$ErrorActionPreference = "Stop"

$status = git status --porcelain
if (-not $status) {
  Write-Host "Nothing to publish."
  exit 0
}

git commit -m $Message
if ($LASTEXITCODE -ne 0) {
  Write-Error "git commit failed."
}

# First push on a new repo needs upstream tracking
$ErrorActionPreference = "Continue"
git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null | Out-Null
$hasUpstream = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = "Stop"

if ($hasUpstream) {
  git push
}
else {
  git push -u origin HEAD
}
if ($LASTEXITCODE -ne 0) {
  Write-Error "git push failed."
}

Write-Host "Published $pdfName locally and pushed to GitHub." -ForegroundColor Green

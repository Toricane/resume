<#
.SYNOPSIS
  Watch the resume .tex (and footer image). After 3 seconds with no further
  changes, recompile to autocompile.pdf so you can keep that PDF open while editing.

.EXAMPLE
  .\watch.ps1

.NOTES
  Opens the PDF in an external viewer (not Cursor). Prefer SumatraPDF for
  auto-reload; Adobe Acrobat often locks the file during compile.
#>
param(
  [int]$DebounceSeconds = 3,
  [switch]$NoOpen
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$texFile = "prajwal_resume_2026_1page.tex"
$footerFile = "coop_footer.png"
$jobName = "autocompile"
$pdfPath = Join-Path $repoRoot ($jobName + ".pdf")

if (-not (Test-Path $texFile)) {
  Write-Error ("Missing " + $texFile)
}

function Get-WatchStamp {
  $parts = @()
  foreach ($f in @($texFile, $footerFile)) {
    if (Test-Path $f) {
      $item = Get-Item $f
      $parts += ($item.FullName + "|" + $item.LastWriteTimeUtc.Ticks + "|" + $item.Length)
    }
  }
  return ($parts -join ";")
}

function Invoke-Compile {
  Write-Host ""
  Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Compiling -> " + $jobName + ".pdf ...") -ForegroundColor Cyan

  $before = [datetime]::MinValue
  if (Test-Path $pdfPath) {
    $before = (Get-Item $pdfPath).LastWriteTimeUtc
  }

  # -f: still write PDF on soft errors (Overleaf-like)
  & latexmk -pdf -f -interaction=nonstopmode -file-line-error ("-jobname=" + $jobName) $texFile | Out-Null

  if ((Test-Path $pdfPath) -and ((Get-Item $pdfPath).LastWriteTimeUtc -gt $before)) {
    Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Ready: " + $pdfPath) -ForegroundColor Green
    return $true
  }

  Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Compile failed. Fix the .tex and save again.") -ForegroundColor Yellow
  return $false
}

function Open-PdfExternal {
  param([string]$Path)

  $candidates = @(
    "$env:LOCALAPPDATA\SumatraPDF\SumatraPDF.exe",
    "$env:ProgramFiles\SumatraPDF\SumatraPDF.exe",
    "${env:ProgramFiles(x86)}\SumatraPDF\SumatraPDF.exe",
    "$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
    "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
  )

  foreach ($exe in $candidates) {
    if (Test-Path $exe) {
      Start-Process -FilePath $exe -ArgumentList("`"$Path`"")
      Write-Host ("Opened in: " + $exe) -ForegroundColor DarkGray
      return
    }
  }

  # Fallback: Windows shell open (still external, not Cursor)
  Start-Process -FilePath "explorer.exe" -ArgumentList("`"$Path`"")
  Write-Host "Opened with the default PDF app via Explorer." -ForegroundColor DarkGray
}

# Initial compile
$ok = Invoke-Compile
if ($ok -and (-not $NoOpen) -and (Test-Path $pdfPath)) {
  Write-Host "Opening autocompile.pdf in an external viewer (close any Cursor PDF tab showing raw text)." -ForegroundColor DarkGray
  Open-PdfExternal -Path $pdfPath
}

$lastStamp = Get-WatchStamp
$pendingSince = $null
$compiling = $false

Write-Host ""
Write-Host ("Watching " + $texFile + " (and " + $footerFile + "). Debounce: " + $DebounceSeconds + "s.") -ForegroundColor Cyan
Write-Host "Keep autocompile.pdf open in your PDF viewer beside the editor. Press Ctrl+C to stop." -ForegroundColor Cyan
Write-Host ""

while ($true) {
  Start-Sleep -Milliseconds 400
  $stamp = Get-WatchStamp

  if ($stamp -ne $lastStamp) {
    $lastStamp = $stamp
    $pendingSince = Get-Date
    Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Change detected - waiting " + $DebounceSeconds + "s ...") -ForegroundColor DarkGray
  }

  if (($null -ne $pendingSince) -and (-not $compiling)) {
    $idle = ((Get-Date) - $pendingSince).TotalSeconds
    if ($idle -ge $DebounceSeconds) {
      $pendingSince = $null
      $compiling = $true

      $lastStamp = Get-WatchStamp
      Invoke-Compile | Out-Null
      $after = Get-WatchStamp
      if ($after -ne $lastStamp) {
        $lastStamp = $after
        $pendingSince = Get-Date
        Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Changed during compile - waiting " + $DebounceSeconds + "s ...") -ForegroundColor DarkGray
      }

      $compiling = $false
    }
  }
}

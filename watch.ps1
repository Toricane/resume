<#
.SYNOPSIS
  Watch the resume sources. After DebounceSeconds with no further changes,
  sync resume.md and the .tex file, then recompile and live-preview.

.EXAMPLE
  .\watch.ps1
#>
param(
  [int]$DebounceSeconds = 3,
  [int]$PreviewPort = 8765,
  [switch]$NoOpen
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$texFile = "prajwal_resume_2026_1page.tex"
$mdFile = "resume.md"
$styleFile = "resume-style.tex"
$footerFile = "coop_footer.png"
$layoutFiles = @($styleFile, $footerFile)
$buildDir = Join-Path $repoRoot "build"
$jobName = "autocompile"
$buildJob = "autocompile_build"
$pdfPath = Join-Path $buildDir ($jobName + ".pdf")
$buildPdfPath = Join-Path $buildDir ($buildJob + ".pdf")
$versionPath = Join-Path $buildDir "version.txt"
$previewUrl = "http://127.0.0.1:$PreviewPort/"

if (-not (Test-Path $texFile)) {
  Write-Error ("Missing " + $texFile)
}

function Get-OneStamp {
  param([string]$RelativePath)
  $path = Join-Path $repoRoot $RelativePath
  if (-not (Test-Path $path)) { return "missing|$RelativePath" }
  $item = Get-Item -LiteralPath $path
  return ($RelativePath + "|" + $item.LastWriteTimeUtc.Ticks + "|" + $item.Length)
}

function Get-GroupStamp {
  param([string[]]$Paths)
  return (($Paths | ForEach-Object { Get-OneStamp $_ }) -join ";")
}

function Invoke-ResumeSync {
  param([string]$SyncDirection)
  & (Join-Path $repoRoot "sync-resume.ps1") -Direction $SyncDirection
}

function Write-PreviewVersion {
  $stamp = (Get-Date).ToString("o")
  if (Test-Path $pdfPath) {
    $stamp = (Get-Item $pdfPath).LastWriteTimeUtc.Ticks.ToString()
  }
  Set-Content -Path $versionPath -Value $stamp -NoNewline
}

function Invoke-Compile {
  Write-Host ""
  Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Compiling -> build/" + $jobName + ".pdf ...") -ForegroundColor Cyan

  $before = [datetime]::MinValue
  if (Test-Path $pdfPath) {
    $before = (Get-Item $pdfPath).LastWriteTimeUtc
  }

  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & latexmk -pdf -f -interaction=nonstopmode -file-line-error ("-jobname=" + $buildJob) $texFile | Out-Null
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prevEap

  if (-not (Test-Path $buildPdfPath)) {
    Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Compile failed (no PDF). Fix the .tex and save again.") -ForegroundColor Yellow
    return $false
  }

  try {
    Copy-Item -Force $buildPdfPath $pdfPath
  }
  catch {
    Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Could not update build/autocompile.pdf (file locked?). Close Acrobat if it has the PDF open.") -ForegroundColor Yellow
    return $false
  }

  $exists = Test-Path $pdfPath
  $updated = $false
  if ($exists) {
    $updated = ((Get-Item $pdfPath).LastWriteTimeUtc -gt $before)
  }

  if ($exists -and ($updated -or ($code -eq 0))) {
    Write-PreviewVersion
    if ($updated) {
      Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Ready (preview will auto-refresh)") -ForegroundColor Green
    }
    else {
      Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Up to date") -ForegroundColor Green
    }
    return $true
  }

  Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Compile failed. Fix the .tex and save again.") -ForegroundColor Yellow
  return $false
}

function Get-ZenBrowserPath {
  $candidates = @(
    "$env:ProgramFiles\Zen Browser\zen.exe",
    "${env:ProgramFiles(x86)}\Zen Browser\zen.exe",
    "$env:LOCALAPPDATA\Zen Browser\zen.exe",
    "$env:LOCALAPPDATA\Programs\Zen\zen.exe"
  )
  foreach ($exe in $candidates) {
    if (Test-Path $exe) { return $exe }
  }
  return $null
}

function Open-Preview {
  param([string]$Url)

  $zen = Get-ZenBrowserPath
  if ($zen) {
    Start-Process -FilePath $zen -ArgumentList $Url
    Write-Host ("Opened live preview in Zen: " + $Url) -ForegroundColor DarkGray
    return
  }

  Start-Process $Url
  Write-Host ("Opened live preview: " + $Url) -ForegroundColor DarkGray
}

function Start-PreviewServer {
  param(
    [string]$Root,
    [int]$Port
  )

  $prefix = "http://127.0.0.1:$Port/"
  $listener = New-Object System.Net.HttpListener
  $listener.Prefixes.Add($prefix)

  try {
    $listener.Start()
  }
  catch {
    Write-Warning ("Could not start preview server on port $Port. $($_.Exception.Message)")
    return $null
  }

  $runspace = [runspacefactory]::CreateRunspace()
  $runspace.Open()
  $runspace.SessionStateProxy.SetVariable("listener", $listener)
  $runspace.SessionStateProxy.SetVariable("root", $Root)

  $ps = [powershell]::Create()
  $ps.Runspace = $runspace
  [void]$ps.AddScript({
    function Get-ContentType([string]$path) {
      switch -Regex ([IO.Path]::GetExtension($path).ToLowerInvariant()) {
        '^\.html$' { return "text/html; charset=utf-8" }
        '^\.pdf$'  { return "application/pdf" }
        '^\.txt$'  { return "text/plain; charset=utf-8" }
        '^\.js$'   { return "application/javascript; charset=utf-8" }
        '^\.mjs$'  { return "application/javascript; charset=utf-8" }
        '^\.css$'  { return "text/css; charset=utf-8" }
        default    { return "application/octet-stream" }
      }
    }

    while ($listener.IsListening) {
      try {
        $ctx = $listener.GetContext()
      }
      catch {
        break
      }

      $req = $ctx.Request
      $res = $ctx.Response
      try {
        $path = $req.Url.AbsolutePath.TrimEnd("/")
        if ([string]::IsNullOrEmpty($path) -or $path -eq "/") {
          $indexPath = Join-Path $root "preview\index.html"
          if (-not (Test-Path $indexPath)) {
            $res.StatusCode = 404
          }
          else {
            $bytes = [IO.File]::ReadAllBytes($indexPath)
            $res.ContentType = "text/html; charset=utf-8"
            $res.ContentLength64 = $bytes.Length
            $res.Headers["Cache-Control"] = "no-store"
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
          }
        }
        elseif ($path -eq "/version") {
          $vp = Join-Path $root "build\version.txt"
          $text = if (Test-Path $vp) { Get-Content -Raw $vp } else { "0" }
          $bytes = [Text.Encoding]::UTF8.GetBytes($text)
          $res.ContentType = "text/plain; charset=utf-8"
          $res.ContentLength64 = $bytes.Length
          $res.Headers["Cache-Control"] = "no-store"
          $res.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        elseif ($path -eq "/autocompile.pdf") {
          $fp = Join-Path $root "build\autocompile.pdf"
          if (-not (Test-Path $fp)) {
            $res.StatusCode = 404
          }
          else {
            $bytes = [IO.File]::ReadAllBytes($fp)
            $res.ContentType = "application/pdf"
            $res.ContentLength64 = $bytes.Length
            $res.Headers["Cache-Control"] = "no-store"
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
          }
        }
        else {
          $res.StatusCode = 404
        }
      }
      catch {
        try { $res.StatusCode = 500 } catch {}
      }
      finally {
        try { $res.OutputStream.Close() } catch {}
        try { $res.Close() } catch {}
      }
    }
  })

  $handle = $ps.BeginInvoke()
  return @{
    Listener = $listener
    PowerShell = $ps
    Handle = $handle
    Runspace = $runspace
    Prefix = $prefix
  }
}

function Stop-PreviewServer {
  param($Server)
  if (-not $Server) { return }
  try {
    if ($Server.Listener -and $Server.Listener.IsListening) {
      $Server.Listener.Stop()
      $Server.Listener.Close()
    }
  }
  catch {}
  try {
    if ($Server.PowerShell) {
      $Server.PowerShell.Stop()
      $Server.PowerShell.Dispose()
    }
  }
  catch {}
  try {
    if ($Server.Runspace) {
      $Server.Runspace.Close()
      $Server.Runspace.Dispose()
    }
  }
  catch {}
}

$server = Start-PreviewServer -Root $repoRoot -Port $PreviewPort
if (-not $server) {
  Write-Warning "Continuing without live preview server."
}

try {
  Invoke-ResumeSync -SyncDirection Reconcile
}
catch {
  Write-Error ("Could not sync resume.md and " + $texFile + ". " + $_.Exception.Message)
}

# Initial compile
$ok = Invoke-Compile
if ($ok -and (-not $NoOpen) -and $server) {
  Write-Host "Opening auto-refreshing preview (Zen if installed)." -ForegroundColor DarkGray
  Open-Preview -Url $previewUrl
}

$syncedMd = Get-OneStamp $mdFile
$syncedTex = Get-OneStamp $texFile
$syncedLayout = Get-GroupStamp $layoutFiles
$lastStamp = "$syncedMd;$syncedTex;$syncedLayout"
$pendingSince = $null
$compiling = $false

Write-Host ""
Write-Host ("Watching " + $mdFile + ", " + $texFile + ", " + ($layoutFiles -join ", ") + ". Debounce: " + $DebounceSeconds + "s.") -ForegroundColor Cyan
Write-Host "Saving resume.md rewrites the .tex file. Saving the .tex file rewrites resume.md." -ForegroundColor Cyan
if ($server) {
  Write-Host ("Live preview: " + $previewUrl + " (pdf.js; keeps zoom/scroll, no flash)") -ForegroundColor Cyan
}
Write-Host "Press Ctrl+C to stop." -ForegroundColor Cyan
Write-Host ""

try {
  while ($true) {
    Start-Sleep -Milliseconds 400
    $curMd = Get-OneStamp $mdFile
    $curTex = Get-OneStamp $texFile
    $curLayout = Get-GroupStamp $layoutFiles
    $stamp = "$curMd;$curTex;$curLayout"

    if ($stamp -ne $lastStamp) {
      $lastStamp = $stamp
      $pendingSince = Get-Date
      $what = New-Object System.Collections.Generic.List[string]
      if ($curMd -ne $syncedMd) { [void]$what.Add($mdFile) }
      if ($curTex -ne $syncedTex) { [void]$what.Add($texFile) }
      if ($curLayout -ne $syncedLayout) { [void]$what.Add("style or footer") }
      Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] " + ($what -join " and ") + " changed - waiting " + $DebounceSeconds + "s ...") -ForegroundColor DarkGray
    }

    if (($null -ne $pendingSince) -and (-not $compiling)) {
      $idle = ((Get-Date) - $pendingSince).TotalSeconds
      if ($idle -ge $DebounceSeconds) {
        $pendingSince = $null
        $compiling = $true

        $mdChanged = $curMd -ne $syncedMd
        $texChanged = $curTex -ne $syncedTex
        $syncFailed = $false
        try {
          if ($mdChanged -and $texChanged) {
            Invoke-ResumeSync -SyncDirection Reconcile
          }
          elseif ($mdChanged) {
            Invoke-ResumeSync -SyncDirection ToTex
          }
          elseif ($texChanged) {
            Invoke-ResumeSync -SyncDirection ToMd
          }
        }
        catch {
          $syncFailed = $true
          Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Sync failed: " + $_.Exception.Message) -ForegroundColor Yellow
        }

        $syncedMd = Get-OneStamp $mdFile
        $syncedTex = Get-OneStamp $texFile
        $syncedLayout = Get-GroupStamp $layoutFiles
        $lastStamp = "$syncedMd;$syncedTex;$syncedLayout"

        if (-not $syncFailed -or $texChanged) {
          Invoke-Compile | Out-Null
          $afterMd = Get-OneStamp $mdFile
          $afterTex = Get-OneStamp $texFile
          $afterLayout = Get-GroupStamp $layoutFiles
          $after = "$afterMd;$afterTex;$afterLayout"
          if ($after -ne $lastStamp) {
            $lastStamp = $after
            $pendingSince = Get-Date
            Write-Host ("[" + (Get-Date -Format "HH:mm:ss") + "] Changed during compile - waiting " + $DebounceSeconds + "s ...") -ForegroundColor DarkGray
          }
        }

        $compiling = $false
      }
    }
  }
}
finally {
  Stop-PreviewServer -Server $server
  Write-Host "Stopped watching."
}

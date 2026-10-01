<#
.SYNOPSIS
  Keep resume.md and prajwal_resume_2026_1page.tex in sync.

.EXAMPLE
  .\sync-resume.ps1 -Direction ToTex

.EXAMPLE
  .\sync-resume.ps1 -Direction ToMd

.EXAMPLE
  .\sync-resume.ps1 -Direction Reconcile
#>
param(
  [ValidateSet('ToTex', 'ToMd', 'Reconcile', 'SelfTest')]
  [string]$Direction = 'Reconcile'
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$texName = 'prajwal_resume_2026_1page.tex'
$mdName = 'resume.md'
$texPath = Join-Path $root $texName
$mdPath = Join-Path $root $mdName

$script:AccentFromLatex = [System.Collections.Generic.Dictionary[string, char]]::new([StringComparer]::Ordinal)
$script:AccentToLatex = [System.Collections.Generic.Dictionary[char, string]]::new()

function Add-Accent {
  param([string]$Command, [int]$Code, [string]$Letter)
  $ch = [char]$Code
  $script:AccentFromLatex["$Command$Letter"] = $ch
  $script:AccentToLatex[$ch] = ('\' + $Command + '{' + $Letter + '}')
}

foreach ($pair in @(
  @('a', 0x00E1), @('e', 0x00E9), @('i', 0x00ED), @('o', 0x00F3), @('u', 0x00FA), @('y', 0x00FD),
  @('A', 0x00C1), @('E', 0x00C9), @('I', 0x00CD), @('O', 0x00D3), @('U', 0x00DA), @('Y', 0x00DD)
)) { Add-Accent "'" ([int]$pair[1]) ([string]$pair[0]) }

foreach ($pair in @(
  @('a', 0x00E0), @('e', 0x00E8), @('i', 0x00EC), @('o', 0x00F2), @('u', 0x00F9),
  @('A', 0x00C0), @('E', 0x00C8), @('I', 0x00CC), @('O', 0x00D2), @('U', 0x00D9)
)) { Add-Accent '`' ([int]$pair[1]) ([string]$pair[0]) }

foreach ($pair in @(
  @('a', 0x00E2), @('e', 0x00EA), @('i', 0x00EE), @('o', 0x00F4), @('u', 0x00FB),
  @('A', 0x00C2), @('E', 0x00CA), @('I', 0x00CE), @('O', 0x00D4), @('U', 0x00DB)
)) { Add-Accent '^' ([int]$pair[1]) ([string]$pair[0]) }

foreach ($pair in @(
  @('a', 0x00E4), @('e', 0x00EB), @('i', 0x00EF), @('o', 0x00F6), @('u', 0x00FC),
  @('A', 0x00C4), @('E', 0x00CB), @('I', 0x00CF), @('O', 0x00D6), @('U', 0x00DC)
)) { Add-Accent '"' ([int]$pair[1]) ([string]$pair[0]) }

foreach ($pair in @(
  @('n', 0x00F1), @('a', 0x00E3), @('o', 0x00F5),
  @('N', 0x00D1), @('A', 0x00C3), @('O', 0x00D5)
)) { Add-Accent '~' ([int]$pair[1]) ([string]$pair[0]) }

Add-Accent 'c' 0x00E7 'c'
Add-Accent 'c' 0x00C7 'C'

function Read-Utf8 {
  param([string]$Path)
  $utf8 = New-Object System.Text.UTF8Encoding $false
  return [System.IO.File]::ReadAllText($Path, $utf8)
}

function Write-Utf8 {
  param([string]$Path, [string]$Content)
  $utf8 = New-Object System.Text.UTF8Encoding $false
  $text = $Content.Replace("`r`n", "`n").Replace("`r", "`n")
  if (-not $text.EndsWith("`n")) {
    $text += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $text, $utf8)
}

function Get-NormalizedText {
  param([string]$Text)
  if ($null -eq $Text) { return "`n" }
  $text = $Text.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd()
  return $text + "`n"
}

function Write-TextIfChanged {
  param([string]$Path, [string]$Content)
  $next = Get-NormalizedText $Content
  if (Test-Path $Path) {
    $current = Get-NormalizedText (Read-Utf8 $Path)
    if ($current -eq $next) {
      return $false
    }
  }
  Write-Utf8 $Path $next
  return $true
}

function Get-BracedContent {
  param([string]$Text, [int]$OpenIndex)
  if ($OpenIndex -lt 0 -or $OpenIndex -ge $Text.Length -or $Text[$OpenIndex] -ne '{') {
    throw "Expected '{' while reading LaTeX."
  }
  $depth = 0
  for ($j = $OpenIndex; $j -lt $Text.Length; $j++) {
    $c = $Text[$j]
    if ($c -eq '\' -and ($j + 1) -lt $Text.Length) {
      $n = $Text[$j + 1]
      if ($n -eq '{' -or $n -eq '}') {
        $j++
        continue
      }
    }
    if ($c -eq '{') {
      $depth++
    }
    elseif ($c -eq '}') {
      $depth--
      if ($depth -eq 0) {
        return @{
          Content = $Text.Substring($OpenIndex + 1, $j - $OpenIndex - 1)
          Next = $j + 1
        }
      }
    }
  }
  throw "Unbalanced '{' in LaTeX."
}

function Skip-Whitespace {
  param([string]$Text, [int]$Index)
  while ($Index -lt $Text.Length -and [char]::IsWhiteSpace($Text[$Index])) {
    $Index++
  }
  return $Index
}

function ConvertFrom-LatexText {
  param([string]$Text)
  if ([string]::IsNullOrEmpty($Text)) { return '' }
  $sb = New-Object System.Text.StringBuilder
  $i = 0
  while ($i -lt $Text.Length) {
    if (($i + 1) -lt $Text.Length -and $Text[$i] -eq '`' -and $Text[$i + 1] -eq '`') {
      $end = $Text.IndexOf("''", $i + 2)
      if ($end -ge 0) {
        $inner = ConvertFrom-LatexText $Text.Substring($i + 2, $end - ($i + 2))
        [void]$sb.Append('"')
        [void]$sb.Append($inner)
        [void]$sb.Append('"')
        $i = $end + 2
        continue
      }
    }

    if ($Text[$i] -eq '\') {
      if (($i + 1) -ge $Text.Length) {
        [void]$sb.Append('\')
        break
      }
      $cmd = $Text[$i + 1]
      $simple = @{
        '&' = '&'
        '%' = '%'
        '$' = '$'
        '#' = '#'
        '_' = '_'
        '{' = '{'
        '}' = '}'
      }
      if ($simple.ContainsKey([string]$cmd)) {
        [void]$sb.Append($simple[[string]$cmd])
        $i += 2
        continue
      }

      $accentCommands = @("'", '`', '^', '"', '~', 'c')
      if ($accentCommands -contains [string]$cmd) {
        $j = $i + 2
        $letter = $null
        if ($j -lt $Text.Length -and $Text[$j] -eq '{') {
          if (($j + 2) -lt $Text.Length -and $Text[$j + 2] -eq '}') {
            $letter = [string]$Text[$j + 1]
            $j += 3
          }
        }
        elseif ($j -lt $Text.Length -and [char]::IsLetter($Text[$j])) {
          $letter = [string]$Text[$j]
          $j++
        }
        $key = ([string]$cmd) + $letter
        if ($null -ne $letter -and $script:AccentFromLatex.ContainsKey($key)) {
          [void]$sb.Append($script:AccentFromLatex[$key])
          $i = $j
          continue
        }
      }

      [void]$sb.Append($Text[$i])
      $i++
      continue
    }

    [void]$sb.Append($Text[$i])
    $i++
  }
  return $sb.ToString()
}

function ConvertFrom-LatexUrl {
  param([string]$Url)
  if ([string]::IsNullOrEmpty($Url)) { return '' }
  return $Url.Replace('\%', '%').Replace('\#', '#').Replace('\&', '&')
}

function ConvertFrom-LatexInline {
  param([string]$Text)
  if ([string]::IsNullOrEmpty($Text)) { return '' }
  $sb = New-Object System.Text.StringBuilder
  $token = '\href{'
  $i = 0
  while ($i -lt $Text.Length) {
    $idx = $Text.IndexOf($token, $i)
    if ($idx -lt 0) {
      [void]$sb.Append((ConvertFrom-LatexText $Text.Substring($i)))
      break
    }
    if ($idx -gt $i) {
      [void]$sb.Append((ConvertFrom-LatexText $Text.Substring($i, $idx - $i)))
    }
    $urlInfo = Get-BracedContent $Text ($idx + 5)
    $j = Skip-Whitespace $Text $urlInfo.Next
    if (-not $Text.Substring($j).StartsWith('{\underline{')) {
      throw "Expected \underline after \href."
    }
    $innerOpen = $j + '{\underline'.Length
    $textInfo = Get-BracedContent $Text $innerOpen
    $k = Skip-Whitespace $Text $textInfo.Next
    if ($k -ge $Text.Length -or $Text[$k] -ne '}') {
      throw "Expected '}' after \underline."
    }
    $url = ConvertFrom-LatexUrl $urlInfo.Content
    $label = ConvertFrom-LatexText $textInfo.Content
    [void]$sb.Append('[')
    [void]$sb.Append($label)
    [void]$sb.Append('](')
    [void]$sb.Append($url)
    [void]$sb.Append(')')
    $i = $k + 1
  }
  return $sb.ToString()
}

function ConvertTo-LatexText {
  param([string]$Text)
  if ([string]::IsNullOrEmpty($Text)) { return '' }
  $sb = New-Object System.Text.StringBuilder
  $escapes = @{
    '&' = '\&'
    '%' = '\%'
    '$' = '\$'
    '#' = '\#'
    '_' = '\_'
    '{' = '\{'
    '}' = '\}'
  }
  $i = 0
  while ($i -lt $Text.Length) {
    if ($Text[$i] -eq '"') {
      $end = $Text.IndexOf('"', $i + 1)
      if ($end -gt $i) {
        $inner = ConvertTo-LatexText $Text.Substring($i + 1, $end - $i - 1)
        [void]$sb.Append('``')
        [void]$sb.Append($inner)
        [void]$sb.Append("''")
        $i = $end + 1
        continue
      }
    }

    $ch = $Text[$i]
    if ($script:AccentToLatex.ContainsKey($ch)) {
      [void]$sb.Append($script:AccentToLatex[$ch])
      $i++
      continue
    }
    $key = [string]$ch
    if ($escapes.ContainsKey($key)) {
      [void]$sb.Append($escapes[$key])
      $i++
      continue
    }
    [void]$sb.Append($ch)
    $i++
  }
  return $sb.ToString()
}

function ConvertTo-LatexUrl {
  param([string]$Url)
  if ([string]::IsNullOrEmpty($Url)) { return '' }
  return $Url.Replace('%', '\%').Replace('#', '\#').Replace('&', '\&')
}

function Format-Href {
  param([string]$Text, [string]$Url)
  return '\href{' + (ConvertTo-LatexUrl $Url) + '}{\underline{' + (ConvertTo-LatexText $Text) + '}}'
}

function ConvertTo-LatexInline {
  param([string]$Markdown)
  if ([string]::IsNullOrEmpty($Markdown)) { return '' }
  $sb = New-Object System.Text.StringBuilder
  $i = 0
  while ($i -lt $Markdown.Length) {
    if ($Markdown[$i] -eq '[') {
      $close = $Markdown.IndexOf('](', $i)
      if ($close -gt $i) {
        $endParen = $Markdown.IndexOf(')', $close + 2)
        if ($endParen -gt $close) {
          $label = $Markdown.Substring($i + 1, $close - $i - 1)
          $url = $Markdown.Substring($close + 2, $endParen - ($close + 2))
          [void]$sb.Append((Format-Href $label $url))
          $i = $endParen + 1
          continue
        }
      }
    }
    $next = $Markdown.IndexOf('[', $i)
    if ($next -lt 0) { $next = $Markdown.Length }
    [void]$sb.Append((ConvertTo-LatexText $Markdown.Substring($i, $next - $i)))
    $i = $next
  }
  return $sb.ToString()
}

function Collapse-Inline {
  param([string]$Text)
  if ($null -eq $Text) { return '' }
  return (($Text -replace '\s*\r?\n\s*', ' ').Trim())
}

function ConvertFrom-ResumeTex {
  param([string]$Text)
  $begin = $Text.IndexOf('\begin{document}')
  $end = $Text.LastIndexOf('\end{document}')
  if ($begin -lt 0 -or $end -lt 0) {
    throw "LaTeX file is missing \begin{document} or \end{document}."
  }
  $body = $Text.Substring($begin, $end - $begin)

  if ($body -notmatch '\\textbf\{\\huge \\scshape (.+?)\}') {
    throw "LaTeX file is missing the resume heading."
  }
  $heading = $Matches[1]
  $split = $heading -split ' -- ', 2
  if ($split.Count -lt 2) {
    throw "Heading must look like Name -- Title."
  }

  $sectionMarks = New-Object System.Collections.Generic.List[object]
  $search = 0
  while ($true) {
    $idx = $body.IndexOf('\section{', $search)
    if ($idx -lt 0) { break }
    $info = Get-BracedContent $body ($idx + 8)
    [void]$sectionMarks.Add(@{
      Title = Collapse-Inline (ConvertFrom-LatexText $info.Content)
      Start = $idx
      ContentStart = $info.Next
    })
    $search = $info.Next
  }
  if ($sectionMarks.Count -eq 0) {
    throw "LaTeX file has no \section commands."
  }

  $header = $body.Substring(0, $sectionMarks[0].Start)
  $contacts = New-Object System.Collections.Generic.List[object]
  $h = 0
  while ($true) {
    $hrefAt = $header.IndexOf('\href{', $h)
    if ($hrefAt -lt 0) { break }
    $urlInfo = Get-BracedContent $header ($hrefAt + 5)
    $j = Skip-Whitespace $header $urlInfo.Next
    if (-not $header.Substring($j).StartsWith('{\underline{')) {
      throw "Expected a contact link."
    }
    $textInfo = Get-BracedContent $header ($j + '{\underline'.Length)
    $k = Skip-Whitespace $header $textInfo.Next
    [void]$contacts.Add(@{
      Text = ConvertFrom-LatexText $textInfo.Content
      Url = ConvertFrom-LatexUrl $urlInfo.Content
    })
    $h = $k + 1
  }

  $sections = New-Object System.Collections.Generic.List[object]
  for ($s = 0; $s -lt $sectionMarks.Count; $s++) {
    $mark = $sectionMarks[$s]
    $contentEnd = $body.Length
    if (($s + 1) -lt $sectionMarks.Count) {
      $contentEnd = $sectionMarks[$s + 1].Start
    }
    $content = $body.Substring($mark.ContentStart, $contentEnd - $mark.ContentStart)
    $section = @{
      Title = $mark.Title
      Skills = @()
      Entries = @()
      Note = $null
    }

    if ($mark.Title -eq 'Technical Skills') {
      $skills = New-Object System.Collections.Generic.List[object]
      $p = 0
      while ($p -lt $content.Length) {
        $a = $content.IndexOf('\resumeSkill{', $p)
        $b = $content.IndexOf('\resumeSkillLast{', $p)
        $at = -1
        if ($a -ge 0 -and ($b -lt 0 -or $a -lt $b)) {
          $at = $a
          $cmdLen = '\resumeSkill'.Length
        }
        elseif ($b -ge 0) {
          $at = $b
          $cmdLen = '\resumeSkillLast'.Length
        }
        else {
          break
        }
        $labelInfo = Get-BracedContent $content ($at + $cmdLen)
        $valueInfo = Get-BracedContent $content (Skip-Whitespace $content $labelInfo.Next)
        [void]$skills.Add(@{
          Label = Collapse-Inline (ConvertFrom-LatexText $labelInfo.Content)
          Value = Collapse-Inline (ConvertFrom-LatexText $valueInfo.Content)
        })
        $p = $valueInfo.Next
      }
      $section.Skills = @($skills.ToArray())
    }
    else {
      $entries = New-Object System.Collections.Generic.List[object]
      $p = 0
      while ($p -lt $content.Length) {
        $at = $content.IndexOf('\resumeSubheading', $p)
        if ($at -lt 0) { break }
        $after = $at + '\resumeSubheading'.Length
        if ($after -lt $content.Length -and [char]::IsLetter($content[$after])) {
          $p = $after
          continue
        }
        $after = Skip-Whitespace $content $after
        $tech = $null
        if ($after -lt $content.Length -and $content[$after] -eq '[') {
          $endBracket = $content.IndexOf(']', $after)
          if ($endBracket -lt 0) { throw "Unbalanced '[' in \resumeSubheading." }
          $tech = Collapse-Inline (ConvertFrom-LatexText $content.Substring($after + 1, $endBracket - $after - 1))
          $after = Skip-Whitespace $content ($endBracket + 1)
        }
        $groups = @()
        for ($g = 0; $g -lt 4; $g++) {
          $braceAt = $content.IndexOf('{', $after)
          $info = Get-BracedContent $content $braceAt
          $groups += ,(Collapse-Inline (ConvertFrom-LatexInline $info.Content))
          $after = $info.Next
        }
        $bullets = New-Object System.Collections.Generic.List[string]
        $itemAt = $content.IndexOf('\resumeItemListStart', $after)
        $nextHeading = $content.IndexOf('\resumeSubheading', $after)
        if ($itemAt -ge 0 -and ($nextHeading -lt 0 -or $itemAt -lt $nextHeading)) {
          $itemEnd = $content.IndexOf('\resumeItemListEnd', $itemAt)
          if ($itemEnd -lt 0) { throw "Missing \resumeItemListEnd." }
          $region = $content.Substring($itemAt, $itemEnd - $itemAt)
          $ip = 0
          while ($true) {
            $ii = $region.IndexOf('\resumeItem{', $ip)
            if ($ii -lt 0) { break }
            $binfo = Get-BracedContent $region ($ii + '\resumeItem'.Length)
            [void]$bullets.Add((Collapse-Inline (ConvertFrom-LatexInline $binfo.Content)))
            $ip = $binfo.Next
          }
          $after = $itemEnd
        }
        [void]$entries.Add(@{
          Role = $groups[0]
          Dates = $groups[1]
          Org = $groups[2]
          Location = $groups[3]
          Tech = $tech
          Bullets = @($bullets.ToArray())
        })
        $p = $after
      }

      $note = $null
      $endList = $content.LastIndexOf('\resumeSubHeadingListEnd')
      if ($endList -ge 0) {
        $tail = $content.Substring($endList + '\resumeSubHeadingListEnd'.Length)
        $smallAt = $tail.IndexOf('\small')
        if ($smallAt -ge 0) {
          $noteStart = $smallAt + 6
          $noteEnd = $tail.IndexOf('\vspace', $noteStart)
          if ($noteEnd -lt 0) { $noteEnd = $tail.Length }
          $rawNote = $tail.Substring($noteStart, $noteEnd - $noteStart)
          $note = Collapse-Inline (ConvertFrom-LatexInline $rawNote)
          if ([string]::IsNullOrWhiteSpace($note)) { $note = $null }
        }
      }

      $section.Entries = @($entries.ToArray())
      $section.Note = $note
    }

    [void]$sections.Add($section)
  }

  return @{
    Name = $split[0]
    Title = $split[1]
    Contacts = @($contacts.ToArray())
    Sections = @($sections.ToArray())
  }
}

function ConvertFrom-ResumeMarkdown {
  param([string]$Text)
  $stripped = [regex]::Replace($Text, '(?s)<!--.*?-->', '')
  $lines = $stripped -split '\r?\n', -1
  $name = $null
  $title = $null
  $contacts = New-Object System.Collections.Generic.List[object]
  $sections = New-Object System.Collections.Generic.List[object]
  $section = $null
  $entry = $null
  $mode = 'top'

  function Flush-Entry {
    if ($null -eq $script:CurrentEntry) { return }
    if ([string]::IsNullOrWhiteSpace($script:CurrentEntry.Org) -or [string]::IsNullOrWhiteSpace($script:CurrentEntry.Dates)) {
      throw ("Entry '" + $script:CurrentEntry.Role + "' needs an '*Org* | Location' line and a dates line.")
    }
    [void]$script:CurrentSectionEntries.Add($script:CurrentEntry)
    $script:CurrentEntry = $null
  }

  function Flush-Section {
    Flush-Entry
    if ($null -eq $script:CurrentSection) { return }
    $script:CurrentSection.Skills = @($script:CurrentSectionSkills.ToArray())
    $script:CurrentSection.Entries = @($script:CurrentSectionEntries.ToArray())
    if ($script:CurrentNoteLines.Count -gt 0) {
      $script:CurrentSection.Note = (($script:CurrentNoteLines.ToArray()) -join ' ').Trim()
    }
    [void]$sections.Add($script:CurrentSection)
    $script:CurrentSection = $null
  }

  $script:CurrentSection = $null
  $script:CurrentSectionSkills = $null
  $script:CurrentSectionEntries = $null
  $script:CurrentNoteLines = $null
  $script:CurrentEntry = $null

  foreach ($rawLine in $lines) {
    $trim = $rawLine.Trim()
    if ($trim.Length -eq 0) { continue }

    if ($trim.StartsWith('### ')) {
      if ($null -eq $section -or $section.Title -eq 'Technical Skills') {
        throw "Found a role heading before a non-skills section: $trim"
      }
      Flush-Entry
      $entry = @{
        Role = $trim.Substring(4).Trim()
        Dates = ''
        Org = ''
        Location = ''
        Tech = $null
        Bullets = New-Object System.Collections.Generic.List[string]
      }
      $script:CurrentEntry = $entry
      $mode = 'need-org'
      continue
    }

    if ($trim.StartsWith('## ')) {
      Flush-Section
      $section = @{
        Title = $trim.Substring(3).Trim()
        Skills = @()
        Entries = @()
        Note = $null
      }
      $script:CurrentSection = $section
      $script:CurrentSectionSkills = New-Object System.Collections.Generic.List[object]
      $script:CurrentSectionEntries = New-Object System.Collections.Generic.List[object]
      $script:CurrentNoteLines = New-Object System.Collections.Generic.List[string]
      $mode = 'section'
      continue
    }

    if ($trim.StartsWith('# ')) {
      if ($null -ne $name) { throw "Only one # heading is allowed." }
      $heading = $trim.Substring(2).Trim()
      $parts = $heading -split ' -- ', 2
      if ($parts.Count -lt 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
        throw "Heading must look like # Name -- Title."
      }
      $name = $parts[0]
      $title = $parts[1]
      $mode = 'contacts'
      continue
    }

    if ($mode -eq 'contacts') {
      if ($trim -match '^-\s+\[([^\]]+)\]\(([^)]+)\)$') {
        [void]$contacts.Add(@{ Text = $Matches[1]; Url = $Matches[2] })
        continue
      }
      throw "Contact lines must look like - [label](url). Got: $trim"
    }

    if ($null -eq $section) {
      throw "Unexpected line before the first section: $trim"
    }

    if ($section.Title -eq 'Technical Skills') {
      if ($trim -match '^\*\*(.+?):\*\*\s*(.*)$') {
        [void]$script:CurrentSectionSkills.Add(@{
          Label = $Matches[1].Trim()
          Value = $Matches[2].Trim()
        })
        continue
      }
      throw "Skill lines must look like **Label:** values. Got: $trim"
    }

    if ($mode -eq 'need-org') {
      if ($trim -match '^\*(.+)\*\s+\|\s+(.+)$' -or $trim -match '^([^#`\[\-\*].+?)\s+\|\s+(.+)$') {
        $script:CurrentEntry.Org = $Matches[1].Trim()
        $script:CurrentEntry.Location = $Matches[2].Trim()
        $mode = 'need-dates'
        continue
      }
      throw ("Entry '" + $script:CurrentEntry.Role + "' needs a line like *Organization* | Location.")
    }

    if ($mode -eq 'need-dates') {
      $script:CurrentEntry.Dates = $trim
      $mode = 'after-dates'
      continue
    }

    if ($mode -eq 'after-dates' -and $trim -match '^`([^`]*)`$') {
      $script:CurrentEntry.Tech = $Matches[1].Trim()
      continue
    }

    if (($mode -eq 'after-dates' -or $mode -eq 'bullets') -and $trim -match '^-\s+(.*)$') {
      [void]$script:CurrentEntry.Bullets.Add($Matches[1].Trim())
      $mode = 'bullets'
      continue
    }

    if ($mode -eq 'bullets' -and $rawLine.StartsWith('  ') -and -not $trim.StartsWith('- ')) {
      $last = $script:CurrentEntry.Bullets.Count - 1
      $script:CurrentEntry.Bullets[$last] = $script:CurrentEntry.Bullets[$last] + ' ' + $trim
      continue
    }

    if ($mode -eq 'after-dates' -or $mode -eq 'bullets' -or $mode -eq 'note' -or $mode -eq 'section') {
      Flush-Entry
      [void]$script:CurrentNoteLines.Add($trim)
      $mode = 'note'
      continue
    }

    throw "Could not read line: $trim"
  }

  Flush-Section
  if ([string]::IsNullOrWhiteSpace($name)) {
    throw "Markdown is missing a # Name -- Title heading."
  }

  $sectionObjects = @($sections.ToArray())
  foreach ($sec in $sectionObjects) {
    if ($null -eq $sec.Entries) { continue }
    $fixed = New-Object System.Collections.Generic.List[object]
    foreach ($en in @($sec.Entries)) {
      if ($null -eq $en) { continue }
      $bulletList = $en.Bullets
      if ($bulletList -is [System.Collections.Generic.List[string]]) {
        $en.Bullets = @($bulletList.ToArray())
      }
      [void]$fixed.Add($en)
    }
    $sec.Entries = @($fixed.ToArray())
  }

  return @{
    Name = $name
    Title = $title
    Contacts = @($contacts.ToArray())
    Sections = $sectionObjects
  }
}

function ConvertTo-ResumeMarkdown {
  param($Model)
  $lines = New-Object System.Collections.Generic.List[string]
  [void]$lines.Add('<!--')
  [void]$lines.Add('  Editable resume. With .\watch.ps1 running:')
  [void]$lines.Add('  - Saving this file rewrites prajwal_resume_2026_1page.tex and recompiles the PDF.')
  [void]$lines.Add('  - Saving the .tex file rewrites this file and recompiles the PDF.')
  [void]$lines.Add('')
  [void]$lines.Add('  Format:')
  [void]$lines.Add('  # Name -- Title')
  [void]$lines.Add('  - [label](url) for each contact link')
  [void]$lines.Add('  ## Technical Skills')
  [void]$lines.Add('  **Label:** values')
  [void]$lines.Add('  ## Any other section')
  [void]$lines.Add('  ### Role or [Role](url)')
  [void]$lines.Add('  *Organization* | Location')
  [void]$lines.Add('  Dates')
  [void]$lines.Add('  `Optional, tech, stack`')
  [void]$lines.Add('  - Bullet, with [link text](url) where you want a link')
  [void]$lines.Add('  A plain paragraph is kept under that section (no bullet).')
  [void]$lines.Add('-->')
  [void]$lines.Add('')
  [void]$lines.Add('# ' + $Model.Name + ' -- ' + $Model.Title)
  [void]$lines.Add('')
  foreach ($contact in @($Model.Contacts)) {
    [void]$lines.Add('- [' + $contact.Text + '](' + $contact.Url + ')')
  }
  foreach ($section in @($Model.Sections)) {
    [void]$lines.Add('')
    [void]$lines.Add('## ' + $section.Title)
    [void]$lines.Add('')
    if ($section.Title -eq 'Technical Skills') {
      $firstSkill = $true
      foreach ($skill in @($section.Skills)) {
        if (-not $firstSkill) { [void]$lines.Add('') }
        [void]$lines.Add('**' + $skill.Label + ':** ' + $skill.Value)
        $firstSkill = $false
      }
      continue
    }
    $firstEntry = $true
    foreach ($entry in @($section.Entries)) {
      if (-not $firstEntry) { [void]$lines.Add('') }
      $firstEntry = $false
      [void]$lines.Add('### ' + $entry.Role)
      [void]$lines.Add('*' + $entry.Org + '* | ' + $entry.Location)
      [void]$lines.Add([string]$entry.Dates)
      if (-not [string]::IsNullOrWhiteSpace($entry.Tech)) {
        [void]$lines.Add('`' + $entry.Tech + '`')
      }
      if (@($entry.Bullets).Count -gt 0) {
        [void]$lines.Add('')
      }
      foreach ($bullet in @($entry.Bullets)) {
        [void]$lines.Add('- ' + $bullet)
      }
    }
    if (-not [string]::IsNullOrWhiteSpace($section.Note)) {
      [void]$lines.Add('')
      [void]$lines.Add([string]$section.Note)
    }
  }
  return (($lines.ToArray()) -join "`n")
}

function ConvertTo-ResumeTex {
  param($Model)
  $lines = New-Object System.Collections.Generic.List[string]
  [void]$lines.Add('% ' + $Model.Name + ' -- 1-page Engineering Physics resume')
  [void]$lines.Add('% Generated from resume.md. While .\watch.ps1 is running, saving either file updates the other and recompiles the PDF.')
  [void]$lines.Add('')
  [void]$lines.Add('\documentclass[letterpaper,10pt]{article}')
  [void]$lines.Add('\input{resume-style}')
  [void]$lines.Add('')
  [void]$lines.Add('%-------------------------------------------')
  [void]$lines.Add('%%%%%%  RESUME STARTS HERE  %%%%%%%%%%%%%%%%%%%%%%%%%%%%')
  [void]$lines.Add('')
  [void]$lines.Add('\begin{document}')
  [void]$lines.Add('')
  [void]$lines.Add('%----------HEADING----------')
  [void]$lines.Add('\begin{center}')
  [void]$lines.Add('    \textbf{\huge \scshape ' + (ConvertTo-LatexText ($Model.Name + ' -- ' + $Model.Title)) + '} \\ \vspace{2pt}')
  [void]$lines.Add('    \small')
  $contactList = @($Model.Contacts)
  for ($i = 0; $i -lt $contactList.Count; $i++) {
    $href = Format-Href $contactList[$i].Text $contactList[$i].Url
    if ($i -lt ($contactList.Count - 1)) {
      [void]$lines.Add('    ' + $href + ' $|$')
    }
    else {
      [void]$lines.Add('    ' + $href + ' \\ \vspace{-6pt}')
    }
  }
  [void]$lines.Add('\end{center}')

  foreach ($section in @($Model.Sections)) {
    [void]$lines.Add('')
    $banner = $section.Title.ToUpperInvariant()
    [void]$lines.Add('%-----------' + $banner + '-----------')
    [void]$lines.Add('\section{' + (ConvertTo-LatexText $section.Title) + '}')
    [void]$lines.Add('\resumeSubHeadingListStart')

    if ($section.Title -eq 'Technical Skills') {
      [void]$lines.Add('\item[]')
      [void]$lines.Add('\small')
      [void]$lines.Add('\resumeSkillPrepare')
      $skills = @($section.Skills)
      foreach ($skill in $skills) {
        [void]$lines.Add('\resumeSkillMeasure{' + (ConvertTo-LatexText $skill.Label) + '}')
      }
      for ($i = 0; $i -lt $skills.Count; $i++) {
        $cmd = 'resumeSkill'
        if ($i -eq ($skills.Count - 1)) { $cmd = 'resumeSkillLast' }
        [void]$lines.Add('\' + $cmd + '{' + (ConvertTo-LatexText $skills[$i].Label) + '}{' + (ConvertTo-LatexText $skills[$i].Value) + '}')
      }
      [void]$lines.Add('\resumeSubHeadingListEnd')
      continue
    }

    $entries = @($section.Entries)
    if ($entries.Count -gt 0) {
      [void]$lines.Add('')
    }
    for ($e = 0; $e -lt $entries.Count; $e++) {
      $entry = $entries[$e]
      if (-not [string]::IsNullOrWhiteSpace($entry.Tech)) {
        [void]$lines.Add('\resumeSubheading[' + (ConvertTo-LatexText $entry.Tech) + ']')
      }
      else {
        [void]$lines.Add('\resumeSubheading')
      }
      [void]$lines.Add('{' + (ConvertTo-LatexInline $entry.Role) + '}{' + (ConvertTo-LatexInline $entry.Dates) + '}')
      [void]$lines.Add('{' + (ConvertTo-LatexInline $entry.Org) + '}{' + (ConvertTo-LatexInline $entry.Location) + '}')
      $bullets = @($entry.Bullets)
      if ($bullets.Count -gt 0) {
        [void]$lines.Add('\resumeItemListStart')
        foreach ($bullet in $bullets) {
          [void]$lines.Add('\resumeItem{' + (ConvertTo-LatexInline $bullet) + '}')
        }
        [void]$lines.Add('\resumeItemListEnd')
      }
      if ($e -lt ($entries.Count - 1) -or [string]::IsNullOrWhiteSpace($section.Note)) {
        [void]$lines.Add('')
      }
    }
    [void]$lines.Add('\resumeSubHeadingListEnd')
    if (-not [string]::IsNullOrWhiteSpace($section.Note)) {
      [void]$lines.Add('\vspace{-4pt}')
      [void]$lines.Add('\small ' + (ConvertTo-LatexInline $section.Note))
      [void]$lines.Add('\vspace{1pt}')
    }
  }

  [void]$lines.Add('')
  [void]$lines.Add('%-----------CO-OP FOOTER-----------')
  [void]$lines.Add('\vfill')
  [void]$lines.Add('\noindent\includegraphics[width=\textwidth]{coop_footer.png}')
  [void]$lines.Add('')
  [void]$lines.Add('%-------------------------------------------')
  [void]$lines.Add('\end{document}')
  return (($lines.ToArray()) -join "`n")
}

function Get-ResumeCounts {
  param($Model)
  $skills = 0
  $entries = 0
  $bullets = 0
  foreach ($section in @($Model.Sections)) {
    $skills += @($section.Skills).Count
    foreach ($entry in @($section.Entries)) {
      $entries++
      $bullets += @($entry.Bullets).Count
    }
  }
  return @{ Skills = $skills; Entries = $entries; Bullets = $bullets }
}

function Assert-ResumeRoundTrip {
  param([string]$Tex)
  $model = ConvertFrom-ResumeTex $Tex
  $skillCmds = [regex]::Matches($Tex, '\\resumeSkill(Last)?\{').Count
  $entryCmds = [regex]::Matches($Tex, '\\resumeSubheading(?=\[|\s|\{)').Count
  $itemCmds = [regex]::Matches($Tex, '\\resumeItem\{').Count
  $counts = Get-ResumeCounts $model
  if ($counts.Skills -ne $skillCmds) {
    throw "Skill count mismatch: parsed $($counts.Skills), commands $skillCmds."
  }
  if ($counts.Entries -ne $entryCmds) {
    throw "Entry count mismatch: parsed $($counts.Entries), commands $entryCmds."
  }
  if ($counts.Bullets -ne $itemCmds) {
    throw "Bullet count mismatch: parsed $($counts.Bullets), commands $itemCmds."
  }

  $md = ConvertTo-ResumeMarkdown $model
  foreach ($match in [regex]::Matches($Tex, '\\href\{([^{}]+)\}')) {
    $url = ConvertFrom-LatexUrl $match.Groups[1].Value
    if (-not $md.Contains($url)) {
      throw "Markdown is missing URL $url"
    }
  }

  $again = ConvertTo-ResumeMarkdown (ConvertFrom-ResumeMarkdown $md)
  if ((Get-NormalizedText $md) -ne (Get-NormalizedText $again)) {
    $left = (Get-NormalizedText $md) -split "`n"
    $right = (Get-NormalizedText $again) -split "`n"
    $n = [Math]::Max($left.Count, $right.Count)
    for ($i = 0; $i -lt $n; $i++) {
      $a = if ($i -lt $left.Count) { $left[$i] } else { '<missing>' }
      $b = if ($i -lt $right.Count) { $right[$i] } else { '<missing>' }
      if ($a -ne $b) {
        throw "Markdown round-trip changed at line $($i + 1)`n< $a`n> $b"
      }
    }
  }

  $renderedTex = ConvertTo-ResumeTex (ConvertFrom-ResumeMarkdown $md)
  $acute = '\' + "'" + '{e}'
  if ($Tex.Contains($acute) -and -not $renderedTex.Contains($acute)) {
    throw "Lowercase acute accent was not preserved."
  }
  $back = ConvertTo-ResumeMarkdown (ConvertFrom-ResumeTex $renderedTex)
  if ((Get-NormalizedText $md) -ne (Get-NormalizedText $back)) {
    $left = (Get-NormalizedText $md) -split "`n"
    $right = (Get-NormalizedText $back) -split "`n"
    $n = [Math]::Max($left.Count, $right.Count)
    for ($i = 0; $i -lt $n; $i++) {
      $a = if ($i -lt $left.Count) { $left[$i] } else { '<missing>' }
      $b = if ($i -lt $right.Count) { $right[$i] } else { '<missing>' }
      if ($a -ne $b) {
        throw "LaTeX round-trip changed markdown at line $($i + 1)`n< $a`n> $b"
      }
    }
  }
}

function Update-TexFromMarkdown {
  if (-not (Test-Path $mdPath)) { throw "Missing $mdName" }
  $model = ConvertFrom-ResumeMarkdown (Read-Utf8 $mdPath)
  $tex = ConvertTo-ResumeTex $model
  Assert-ResumeRoundTrip $tex
  if (Write-TextIfChanged $texPath $tex) {
    Write-Host "Updated $texName from $mdName"
  }
  else {
    Write-Host "$texName already matches $mdName"
  }
}

function Update-MarkdownFromTex {
  if (-not (Test-Path $texPath)) { throw "Missing $texName" }
  $tex = Read-Utf8 $texPath
  Assert-ResumeRoundTrip $tex
  $model = ConvertFrom-ResumeTex $tex
  $md = ConvertTo-ResumeMarkdown $model
  if (Write-TextIfChanged $mdPath $md) {
    Write-Host "Updated $mdName from $texName"
  }
  else {
    Write-Host "$mdName already matches $texName"
  }
}

function Sync-ResumeSources {
  $hasMd = Test-Path $mdPath
  $hasTex = Test-Path $texPath
  if (-not $hasMd -and -not $hasTex) {
    throw "Missing both $mdName and $texName."
  }
  if (-not $hasMd) {
    Update-MarkdownFromTex
    return
  }
  if (-not $hasTex) {
    Update-TexFromMarkdown
    return
  }

  $mdText = Read-Utf8 $mdPath
  $texText = Read-Utf8 $texPath
  $texFromMd = ConvertTo-ResumeTex (ConvertFrom-ResumeMarkdown $mdText)
  if ((Get-NormalizedText $texFromMd) -eq (Get-NormalizedText $texText)) {
    Write-Host "Resume markdown and LaTeX are in sync"
    return
  }
  $mdFromTex = ConvertTo-ResumeMarkdown (ConvertFrom-ResumeTex $texText)
  if ((Get-NormalizedText $mdFromTex) -eq (Get-NormalizedText $mdText)) {
    Write-Host "Resume markdown and LaTeX are in sync"
    return
  }

  $mdTime = (Get-Item $mdPath).LastWriteTimeUtc
  $texTime = (Get-Item $texPath).LastWriteTimeUtc
  if ($mdTime -ge $texTime) {
    Update-TexFromMarkdown
    return
  }
  Update-MarkdownFromTex
}

switch ($Direction) {
  'SelfTest' { Assert-ResumeRoundTrip (Read-Utf8 $texPath); Write-Host 'Round-trip OK' }
  'ToTex' { Update-TexFromMarkdown }
  'ToMd' { Update-MarkdownFromTex }
  'Reconcile' { Sync-ResumeSources }
}

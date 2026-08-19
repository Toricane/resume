# Prajwal Prashanth — Resume

One-page Engineering Physics resume (UBC). Edited and compiled locally; a versioned PDF is committed when you publish.

## Download

[**Download PDF**](Prajwal_UBC_1_Page_Resume_2026-08-18_v1.pdf)

*(Link updates when you run `.\publish.ps1`.)*

## Preview

![Resume preview](preview.png)

## Live autocompile (local)

1. Close any `autocompile.pdf` tab inside Cursor (it shows raw PDF text — Cursor is not a PDF viewer).
2. Run:

```powershell
.\watch.ps1
```

That compiles, then opens `autocompile.pdf` in Acrobat (or SumatraPDF if installed). After you stop typing for **3 seconds**, it recompiles; refresh/reload in the PDF app if needed.

Uses MiKTeX `latexmk` + pdflatex (same engine as Overleaf). **SumatraPDF** reloads automatically; Adobe Acrobat often locks the file — if compiles fail while Acrobat is open, install SumatraPDF or close the PDF before saving.
## Publish a new version

When you want a committed PDF named like `Prajwal_UBC_1_Page_Resume_YYYY-MM-DD_vN.pdf`:

```powershell
.\publish.ps1 -Message "Update Buildplate bullets"
```

Or:

```powershell
.\publish.ps1
```

This compiles on your machine, replaces any previous versioned PDF in the tree (old ones stay in git history), refreshes `preview.png` and the download link above, then commits and pushes. No GitHub Actions compile.

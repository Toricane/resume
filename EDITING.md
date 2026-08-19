# Editing & publishing this resume

Source: [`prajwal_resume_2026_1page.tex`](prajwal_resume_2026_1page.tex) (plus [`coop_footer.png`](coop_footer.png)). Build and publish happen **locally** with MiKTeX (`latexmk` + pdflatex), same engine as Overleaf.

## Live autocompile

1. Close any `autocompile.pdf` tab inside Cursor/VS Code (it shows raw PDF bytes — the editor is not a PDF viewer).
2. Run:

```powershell
.\watch.ps1
```

That compiles, then opens `autocompile.pdf` in an external viewer (SumatraPDF if installed, otherwise Acrobat). After you stop changing the `.tex` (or footer) for **3 seconds**, it recompiles.

Optional:

```powershell
.\watch.ps1 -DebounceSeconds 5
.\watch.ps1 -NoOpen
```

**SumatraPDF** reloads automatically when the file changes. Adobe Acrobat often locks the PDF and blocks recompiles — install SumatraPDF, or close the PDF before saving.

## Publish

```powershell
.\publish.ps1 -Message "Your message"
```

Or with an automatic default message:

```powershell
.\publish.ps1
```

Behavior:

- **If** `prajwal_resume_2026_1page.tex` or `coop_footer.png` changed (or there is no versioned PDF yet): compile, write `Prajwal_UBC_1_Page_Resume_YYYY-MM-DD_vN.pdf`, refresh `preview.png` + the README download link, commit, and push. Default message: `Update resume`.
- **Otherwise** (docs/scripts only): skip compile and version bump; just `git add` / commit / push. Default message: `Update project files`.

Version numbers increase only when the resume is rebuilt, not on docs-only publishes.

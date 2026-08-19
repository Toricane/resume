# Editing & publishing this resume

- **Content:** [`prajwal_resume_2026_1page.tex`](prajwal_resume_2026_1page.tex)
- **Formatting / macros:** [`resume-style.tex`](resume-style.tex)
- **Footer image:** [`coop_footer.png`](coop_footer.png)

Build and publish happen **locally** with MiKTeX (`latexmk` + pdflatex), same engine as Overleaf.

## Live autocompile

1. Close any `autocompile.pdf` tab inside Cursor/VS Code (it shows raw PDF bytes — the editor is not a PDF viewer).
2. Run:

```powershell
.\watch.ps1
```

That compiles, then opens a **pdf.js** live preview at `http://127.0.0.1:8765/` in **Zen Browser** (if installed). After you stop changing sources for **3 seconds**, it recompiles and the preview updates **without a white flash**, keeping **zoom and scroll**.

Optional:

```powershell
.\watch.ps1 -DebounceSeconds 5
.\watch.ps1 -NoOpen
.\watch.ps1 -PreviewPort 8765
```

Use **Ctrl+scroll** or the toolbar (**Fit width** / **Fit height**) to zoom. Text is selectable/copyable and links are clickable. Needs network once for the pdf.js CDN. Close any Acrobat window on `autocompile.pdf` so it cannot lock the file.

## Publish

```powershell
.\publish.ps1 -Message "your message"
```

Or with an automatic default message:

```powershell
.\publish.ps1
```

Behavior:

- **If** `prajwal_resume_2026_1page.tex`, `resume-style.tex`, or `coop_footer.png` changed (or there is no versioned PDF yet): compile, write `Prajwal_UBC_1_Page_Resume_YYYY-MM-DD_vN.pdf`, refresh `preview.png` + the README download link, commit, and push. Default message: `update resume`.
- **Otherwise** (docs/scripts only): skip compile and version bump; just `git add` / commit / push. Default message: `update project files`.

Version numbers increase only when the resume is rebuilt, not on docs-only publishes.

# Editing & publishing this resume

- **Content:** [`resume.md`](resume.md) or [`prajwal_resume_2026_1page.tex`](prajwal_resume_2026_1page.tex)
- **Formatting / macros:** [`resume-style.tex`](resume-style.tex)
- **Footer image:** [`coop_footer.png`](coop_footer.png)

Build and publish happen **locally** with MiKTeX (`latexmk` + pdflatex), same engine as Overleaf.

## Live autocompile

1. Close any `build/autocompile.pdf` tab inside Cursor/VS Code (it shows raw PDF bytes — the editor is not a PDF viewer).
2. Run:

```powershell
.\watch.ps1
```

That compiles into `build/` (aux files, logs, and `build/autocompile.pdf`), then opens a **pdf.js** live preview at `http://127.0.0.1:8765/` in **Zen Browser** (if installed). After you stop changing sources for **3 seconds**, it syncs [`resume.md`](resume.md) and [`prajwal_resume_2026_1page.tex`](prajwal_resume_2026_1page.tex), recompiles, and the preview updates **without a white flash**, keeping **zoom and scroll**.

- Saving `resume.md` rewrites the `.tex` file, then recompiles.
- Saving the `.tex` file rewrites `resume.md`, then recompiles.
- Saving `resume-style.tex` or `coop_footer.png` only recompiles.
- If both content files change before the debounce and they no longer match, the newer save wins.

Optional:

```powershell
.\watch.ps1 -DebounceSeconds 5
.\watch.ps1 -NoOpen
.\watch.ps1 -PreviewPort 8765
```

Use **Ctrl+scroll** or the toolbar (**Fit width** / **Fit height**) to zoom. Text is selectable/copyable and links are clickable. Needs network once for the pdf.js CDN. Close any Acrobat window on `build/autocompile.pdf` so it cannot lock the file.

## Markdown source

[`resume.md`](resume.md) is the editable Markdown version of the résumé. The format is noted at the top of that file:

- `# Name -- Title`, then one `- [label](url)` contact link per line
- `## Technical Skills`, with one `**Label:** values` line per row
- Other sections: `### Role` (or `### [Role](url)`), then `*Organization* | Location`, a dates line, an optional `` `tech stack` `` line, then `-` bullets
- A plain paragraph under a section is kept as-is (the hackathon “Also competed…” line)

`.\publish.ps1` reconciles `resume.md` and the `.tex` file the same way before it decides whether to build a new PDF. A change to either content file publishes a new version.

## Publish

```powershell
.\publish.ps1 -Message "your message"
```

Or with an automatic default message:

```powershell
.\publish.ps1
```

Behavior:

- **If** `resume.md`, `prajwal_resume_2026_1page.tex`, `resume-style.tex`, or `coop_footer.png` changed (or there is no versioned PDF yet): compile, write `Prajwal_Prashanth_UBC_YYYY-MM-DD_vN.pdf`, refresh `preview.png`, the README download link, and `index.html` (GitHub Pages PDF viewer used by https://prajwal.is-a.dev/resume), commit, and push. Default message: `update resume`.
- **Otherwise** (docs/scripts only): skip compile and version bump; just `git add` / commit / push. Default message: `update project files`.

`index.html` displays the current PDF using pdf.js, with selectable text, clickable links, zoom controls, and a Download button. It is generated from `preview/public.html`; edit that template for public viewer changes. The PDF uses a relative URL so it loads and downloads from the same site. GitHub Pages serves the viewer instead of this README.

The date is Pacific calendar time. `vN` is the Nth resume PDF published **that day** (first of the day is `v1`). Docs-only publishes do not bump `vN`.

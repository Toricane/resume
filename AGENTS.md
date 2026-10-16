# Agent notes

One-page résumé. Content lives in Markdown and is compiled to LaTeX. The PDF must stay **one page**.

Do not commit or run `.\publish.ps1` unless the user asks. Publish commits and pushes.

## Edit the résumé

Change [`resume.md`](resume.md) only, then sync:

```powershell
.\sync-resume.ps1 -Direction ToTex
```

That rewrites [`prajwal_resume_2026_1page.tex`](prajwal_resume_2026_1page.tex). If `.\watch.ps1` is already running, saving `resume.md` does this after the debounce; do not also hand-edit the `.tex` file. The next Markdown save overwrites the `.tex` body.

Write normal text in Markdown. The sync script escapes LaTeX (`&`, `%`, `$`), turns `"quotes"` into LaTeX quotes, and turns `é` into `\'{e}`. Use Markdown links, not `\href`.

```markdown
# Name -- Title

- [label](url)

## Technical Skills

**Label:** values, separated, by commas

## Section name

### Role
*Organization* | Location
Mon YYYY -- Mon YYYY
`Optional, tech, stack`

- Bullet with a [link](https://example.com).

### [Linked role](https://example.com)
*Organization* | Location
Mon YYYY -- Mon YYYY

- Bullet.

Plain paragraph under the section, not a bullet.
```

Rules the parser enforces:

- The heading is `# Name`, optionally followed by ` -- Title` with a space-hyphen-hyphen-space.
- Contacts are `- [label](url)`, one per line, before the first section.
- The skills heading must stay exactly `## Technical Skills`. Each row is `**Label:** value`.
- Every other `###` entry needs `*Organization* | Location`, then a dates line. A `` `tech` `` line is optional and comes before the bullets.
- Bullets are one `- ` line each. A line with no marker, after the entries, becomes the section note (the hackathon “Also competed…” line).
- Keep dates as `Jun 2026 -- Present` (ASCII `--`).

After a content edit, compile and confirm the PDF is still one page:

```powershell
latexmk -pdf -interaction=nonstopmode -file-line-error -halt-on-error "-jobname=autocompile_build" prajwal_resume_2026_1page.tex
```

`build/autocompile_build.log` should say `1 page`.

The watcher previews only the UBC version. Publishing builds both matching dated PDFs in the root, using `\ResumeNoCoopFooter` to omit the footer from the plain version; do not hand-edit generated LaTeX to remove it.

After content or layout changes, render both PDFs to images (for example, `pdftoppm -singlefile -png -r 150`) and visually inspect the complete pages. Scan every bullet for a final line containing only one to three words or occupying less than roughly one quarter of the available width. Rephrase to compact the bullet, or add useful supported context that earns the extra line. Never pad with filler, invent metrics, or shrink the font just to eliminate a short line. Check headings for overlap, section spacing, footer clearance, and legibility; recompile and inspect again after fixes.

## Edit formatting

Use [`resume-style.tex`](resume-style.tex) for layout: margins, section rules, list spacing, and the `\resumeSubheading` / `\resumeSkill*` macros. [`coop_footer.png`](coop_footer.png) is the footer image. These files are not generated. `.\watch.ps1` recompiles when they change and does not touch `resume.md`.

Do not “fix” spacing by editing `prajwal_resume_2026_1page.tex`. The next `resume.md` sync rewrites that file. The document shell, skill-measure block, and the `\vspace` around a section note are emitted by `ConvertTo-ResumeTex` in [`sync-resume.ps1`](sync-resume.ps1). Change the emitter, then run `.\sync-resume.ps1 -Direction ToTex`.

Leave the résumé wording alone when the request is formatting only. Compile afterward and check it is still one page.

## Add or change features

| Piece | File |
| --- | --- |
| Markdown ↔ LaTeX | [`sync-resume.ps1`](sync-resume.ps1) (`ToTex`, `ToMd`, `Reconcile`, `SelfTest`) |
| Live preview and debounce | [`watch.ps1`](watch.ps1), [`preview/index.html`](preview/index.html) |
| Versioned PDF, README link, public PDF viewer | [`publish.ps1`](publish.ps1) |
| Engine | [`.latexmkrc`](.latexmkrc) (`latexmk` + pdflatex, output in `build/`) |

`publish.ps1` only commits paths in `$projectFiles`. Add a new tracked file there. Add a path to `$resumeSources` only when a change to it should build new PDFs. Publishing creates matching `Prajwal_Prashanth_UBC_YYYY-MM-DD_vN.pdf` and `Prajwal_Prashanth_YYYY-MM-DD_vN.pdf` variants; the public viewer uses the UBC version. Docs and scripts outside `$resumeSources` publish without new PDFs. `index.html` is generated from `preview/public.html`, and the README download link is rewritten by publish; do not hand-edit the PDF URL. Change the public viewer template for layout or behavior updates.

If the Markdown format changes, update both directions in `sync-resume.ps1`, the comment at the top of `resume.md`, and this file. Then run:

```powershell
.\sync-resume.ps1 -Direction SelfTest
.\sync-resume.ps1 -Direction ToTex
```

`SelfTest` checks that entry, bullet, skill, and URL counts survive a round trip. `build/` is gitignored.

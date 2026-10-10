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

- The heading is `# Name -- Title` with a space-hyphen-hyphen-space.
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

`publish.ps1` only commits paths in `$projectFiles`. Add a new tracked file there. Add a path to `$resumeSources` only when a change to it should build a new `Prajwal_Prashanth_UBC_YYYY-MM-DD_vN.pdf`. Docs and script changes publish without a new PDF. `index.html` is generated from `preview/public.html`, and the README download link is rewritten by publish; do not hand-edit the PDF URL. Change the public viewer template for layout or behavior updates.

If the Markdown format changes, update both directions in `sync-resume.ps1`, the comment at the top of `resume.md`, and this file. Then run:

```powershell
.\sync-resume.ps1 -Direction SelfTest
.\sync-resume.ps1 -Direction ToTex
```

`SelfTest` checks that entry, bullet, skill, and URL counts survive a round trip. `build/` is gitignored.

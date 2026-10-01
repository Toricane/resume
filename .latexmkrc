# Match Overleaf: latexmk + pdflatex
$pdf_mode = 1;
$pdflatex = 'pdflatex -interaction=nonstopmode -file-line-error %O %S';
$continuous_mode = 0;

# Keep aux, logs, and preview PDFs out of the repo root.
$out_dir = 'build';

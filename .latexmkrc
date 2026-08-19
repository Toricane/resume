# Match Overleaf: latexmk + pdflatex
$pdf_mode = 1;
$pdflatex = 'pdflatex -interaction=nonstopmode -file-line-error %O %S';
$continuous_mode = 0;

# Keep aux next to the job (autocompile / source jobname)
$out_dir = '.';

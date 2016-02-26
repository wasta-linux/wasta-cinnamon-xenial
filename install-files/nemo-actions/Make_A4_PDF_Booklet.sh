#!/bin/bash
while (( $# )); do
    OUT="${1%.*}_bklt.pdf"
    cp "$1" "$OUT" && chmod u+w "$OUT" && pdfbklt -p 2 -b A4 "$OUT"

  shift
done

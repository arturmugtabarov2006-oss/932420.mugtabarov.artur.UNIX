#!/bin/sh
# build.sh 

set -u

#  Коды ошибок 
E_USAGE=1     # неверное использование
E_NOFILE=2    # исходника нет
E_NOOUTPUT=3  # нет комментария Output:
E_BADTYPE=4   # неизвестный тип файла
E_COMPILE=5   # ошибка компиляции
E_TMPDIR=6    # не удалось создать temp
E_OUTPUT=7    # не удалось получить/переместить результат

#  Аргументы 
usage() {
    printf 'Usage: %s <source-file>\n' "$0" >&2
    exit $E_USAGE
}
[ $# -eq 1 ] || usage
SRC=$1

[ -f "$SRC" ] || { printf 'Error: file not found: %s\n' "$SRC" >&2; exit $E_NOFILE; }

#  Абсолютный путь 
case "$SRC" in
    /*) SRC_ABS=$SRC ;;
    *)  SRC_ABS=$(cd "$(dirname "$SRC")" && pwd)/$(basename "$SRC") ;;
esac
SRC_DIR=$(dirname "$SRC_ABS")
SRC_BASE=$(basename "$SRC_ABS")

#  Поиск Output: 
OUTPUT_NAME=$(awk '
    match($0, /[Oo]utput:[ \t]*[^ \t*\/%>]+/) {
        s = substr($0, RSTART, RLENGTH)
        sub(/^[Oo]utput:[ \t]*/, "", s)
        print s
        exit
    }
' "$SRC_ABS")

[ -n "$OUTPUT_NAME" ] || { printf 'Error: no "Output:" comment found\n' >&2; exit $E_NOOUTPUT; }

case "$OUTPUT_NAME" in
    */*|-) printf 'Error: invalid output name: %s\n' "$OUTPUT_NAME" >&2
           exit $E_OUTPUT ;;
esac

#  Temp-каталог и trap 
TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/build.XXXXXXXX") || {
    printf 'Error: cannot create temp dir\n' >&2; exit $E_TMPDIR; }

cleanup() { [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ] && rm -rf "$TMPDIR"; }

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

#  Определение типа 
case "$SRC_BASE" in
    *.c)                  TYPE=c   ; CC=${CC:-cc}     ; CFLAGS=${CFLAGS:--O2 -Wall} ;;
    *.cpp|*.cc|*.cxx|*.C) TYPE=cpp ; CXX=${CXX:-c++}  ; CXXFLAGS=${CXXFLAGS:--O2 -Wall} ;;
    *.tex)                TYPE=tex ;;
    *)  printf 'Error: unsupported source type: %s\n' "$SRC_BASE" >&2
        exit $E_BADTYPE ;;
esac

#  Сборка 
case "$TYPE" in
  c)
    $CC $CFLAGS -o "$TMPDIR/$OUTPUT_NAME" "$SRC_ABS" || {
        printf 'Error: C compilation failed\n' >&2; exit $E_COMPILE; } ;;
  cpp)
    $CXX $CXXFLAGS -o "$TMPDIR/$OUTPUT_NAME" "$SRC_ABS" || {
        printf 'Error: C++ compilation failed\n' >&2; exit $E_COMPILE; } ;;
  tex)
    command -v pdflatex >/dev/null 2>&1 || {
        printf 'Error: pdflatex not found\n' >&2; exit $E_COMPILE; }
    case "$OUTPUT_NAME" in *.pdf) ;; *) OUTPUT_NAME="$OUTPUT_NAME.pdf" ;; esac
    TEX_BASE=${OUTPUT_NAME%.pdf}
    pdflatex -interaction=nonstopmode -halt-on-error \
        -jobname="$TEX_BASE" -output-directory="$TMPDIR" \
        "$SRC_ABS" >"$TMPDIR/latex.log" 2>&1 || {
            printf 'Error: LaTeX failed, log:\n' >&2
            cat "$TMPDIR/latex.log" >&2
            exit $E_COMPILE; }
    pdflatex -interaction=nonstopmode -halt-on-error \
        -jobname="$TEX_BASE" -output-directory="$TMPDIR" \
        "$SRC_ABS" >>"$TMPDIR/latex.log" 2>&1 || true ;;
esac

# Проверка и перенос результата 
[ -f "$TMPDIR/$OUTPUT_NAME" ] || {
    printf 'Error: expected output not found: %s\n' "$OUTPUT_NAME" >&2
    exit $E_OUTPUT; }

mv "$TMPDIR/$OUTPUT_NAME" "$SRC_DIR/$OUTPUT_NAME" || {
    printf 'Error: cannot move output to %s\n' "$SRC_DIR/$OUTPUT_NAME" >&2
    exit $E_OUTPUT; }

printf 'Built: %s\n' "$SRC_DIR/$OUTPUT_NAME"
exit 0

#!/bin/bash
# Запуск: ./bench.sh input.bmp output.bmp

INPUT=$1
OUTPUT=$2

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
    echo "usage: $0 input.bmp output.bmp"
    exit 1
fi

for OPT in -O0 -O1 -O2 -O3; do
    make -s clean
    make -s IMPL=c OPT=$OPT
    echo -n "C $OPT : "
    ./sobel $INPUT $OUTPUT | grep время
done

make -s clean
make -s IMPL=asm
echo -n "ASM scalar : "
./sobel $INPUT $OUTPUT | grep время

make -s clean
make -s IMPL=simd
echo -n "ASM SSE2   : "
./sobel $INPUT $OUTPUT | grep время

#!/bin/bash
#unofficial strict mode
set -euo pipefail
#set -x
IFS=$'\n\t'

cl_file=$1
cl_bin_ref=$(basename -- $cl_file).bin
cl_asm=$(basename -- $cl_file).template.asm

ioc64 -cmd=build -input="$cl_file" -ir="$cl_bin_ref" -device=gpu
mkdir -p dump
ocloc disasm -file "$cl_bin_ref" -dump dump
cp dump/*asm $cl_asm
rm -rf dump 
rm -- $cl_bin_ref

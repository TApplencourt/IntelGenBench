#!/bin/bash
#unofficial strict mode
set -euo pipefail
#set -x 
IFS=$'\n\t'

cl_kernel="mcopy"
cl_file=$(find $1 -name *.cl)
cl_asm_template=$(find $1 -name *.asm)
cl_bin_ref=tmp/$(basename -- $cl_file).ref.bin
cl_bin=tmp/$(basename -- $cl_file).bin

n=$2

mkdir -p tmp



# Create the binary. How contain the kernel and the info on how to run it
ioc64 -cmd=build -input="$cl_file" -ir="$cl_bin_ref" -device=gpu
mkdir -p tmp/dump
#Disable it to get the asm
ocloc disasm -file "$cl_bin_ref" -dump tmp/dump

# Generate new ASM
cl_asm=$(find tmp/dump -name *.asm)
./src/gen_asm.py "$cl_asm_template" $n > "$cl_asm"

# Re-assemble
ocloc asm -out "$cl_bin" -dump tmp/dump -device=gpu

# Run it
cl_platform_id=1
cl_device_id=0

# Global size
# Logal size (simd size)
let cl_global=$3
let cl_local=$4


echo "Running"
./$1/cl_launch_kernel.out "$cl_platform_id" "$cl_device_id" "$cl_bin" "$cl_kernel" "$cl_global" "$cl_local"

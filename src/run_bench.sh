#!/bin/bash
set -euo pipefail
#set -x
simd_width=$2
mmops=$3

freq=$(cat /sys/class/drm/card0/gt_act_freq_mhz)

echo "global_range(#)" "repetion(#)" "time(ns)" "BW(GB/s)"
for cl_global in "$simd_width"  "$simd_width"*24  "$simd_width"*24*7  
do
    for n in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 
    do
        ns=$(./src/run_kernel.sh $1 $n $cl_global $simd_width | grep 'OpenCl Execution time is' | awk '{print $5}')
        # Single precision (4 bytes)
        gb=$(echo "scale=2; ( ($cl_global) *  $n * 4 * $mmops)  / $ns " | bc )
        byte=$(echo "scale=2; 1000 * $gb / $freq" | bc )

        echo $cl_global $n $ns  $gb $byte
    done
done

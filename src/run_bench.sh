#!/bin/bash

echo "global_range(#)" "repetion(#)" "time(ns)" "BW(GB/s)"
for cl_global in 8 8*24  8*24*2  8*24*4  8*24*7 2*8*24*7
do
    for n in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 
    do
        ns=$(./src/run_kernel.sh $1 $n $cl_global 8 | grep 'OpenCl Execution time is' | awk '{print $5}')
        # Single precision (4 bytes)
        echo $cl_global $n $ns  $(echo "scale=2; ($cl_global *  $n * 4)  / $ns " | bc )
    done
done

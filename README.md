# Requirement
- `ruby` 
  - `opencl_ruby_ffi` (ruby opencl binding `gem install opencl_ruby_ffi`)
- `ocloc` (see <https://github.com/intel/compute-runtime>)
 
# Summary

Gen9 GT2 (1.2 GHz)
```
R      kernel: 61.71 B/clk/subslice
W      kernel: 50.89 B/clk/subslice
R+W    kernel: 61.01 B/clk/subslice
```

Gen9 GT3e (1.1 GHz)
```
R      kernel: 40.58 B/clk/subslice
W      kernel: 41.64 B/clk/subslice
R+W    kernel: 50.50 B/clk/subslice
```

# Output 

```
$./bench.rb 2
Warning OpenCL 2.1 loader detected!
Path to patch list not provided - using defaults, skipping patchokens as undefined.
Trying to disassemble icule.krn
L0:
(W)      mov (8|M0)               r2.0<1>:ud    r0.0<1;1,0>:ud
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      mul (1|M0)               r3.0<1>:d     r6.0<0;1,0>:d     r2.1<0;1,0>:d    {Compacted}
(W)      mov (8|M0)               r127.0<1>:ud  r2.0<8;8,1>:ud                   {Compacted}
         add (16|M0)              r7.0<1>:d     r3.0<0;1,0>:d     r1.0<16;16,1>:uw
         add (16|M0)              r7.0<1>:d     r7.0<8;8,1>:d     r4.0<0;1,0>:d    {Compacted}
         shl (16|M0)              r7.0<1>:d     r7.0<8;8,1>:d     4:w
         add (16|M0)              r9.0<1>:d     r7.0<8;8,1>:d     r5.5<0;1,0>:d    {Compacted}
         add (16|M0)              r7.0<1>:d     r7.0<8;8,1>:d     r5.4<0;1,0>:d    {Compacted}
         send (16|M0)             r11:w    r9      0xC         0x4805001  //    wr:2+?, rd:8, Untyped Surface Read msc:16, to #1
         sends (16|M0)            null:w   r7      r11     0x20C       0x4025000  //    wr:2+8, rd:0, Untyped Surface Write msc:16, to #0
(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10
L152:
Trying to assemble icule.asm
"After"
NArray.int(172032):
[ 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, ... ]
Number of subslice: 3
memory_footprint: 1376.256 KB
global size: 43008
local size: 64
Unroll factor:
  Read:  1
  Write: 1
  Copy:  1000
ν: 1200 mhz
Δt: 6275750 ns
bw: 219.30 GB/s
  : 182.75 B/clk
  : 60.92 B/clk/subslice
peak: 95.18 %
```

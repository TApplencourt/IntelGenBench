# Requirement
- `ruby` 
- `opencl_ruby_ffi` (ruby opencl binding `gem install opencl_ruby_ffi`)
- `ocloc` (see <https://github.com/intel/compute-runtime>)

# Output 
```
$./bench.rb store_double_16
Warning OpenCL 2.1 loader detected!
Posible argument
store_uint_16
store_float_16
store_float_32
store_double_8
store_double_16
store_double_32
load_float_16
The chosen one: store_double_16
Path to patch list not provided - using defaults, skipping patchokens as undefined.
Trying to disassemble icule.krn
L0:
(W)      mov (8|M0)               r2.0<1>:ud    r0.0<1;1,0>:ud
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      mul (1|M0)               r3.0<1>:d     r5.3<0;1,0>:d     r2.1<0;1,0>:d    {Compacted}
(W)      mov (8|M0)               r127.0<1>:ud  r2.0<8;8,1>:ud                   {Compacted}
         add (16|M0)              r6.0<1>:d     r3.0<0;1,0>:d     r1.0<16;16,1>:uw
         add (16|M0)              r6.0<1>:d     r6.0<8;8,1>:d     r4.0<0;1,0>:d    {Compacted}
         mov (8|M0)               r12.0<1>:df   r6.0<8;8,1>:d
         mov (8|M8)               r14.0<1>:df   r7.0<8;8,1>:d
         shl (16|M0)              r6.0<1>:d     r6.0<8;8,1>:d     3:w
         mov (8|M0)               r8.0<1>:d     r12.0<2;1,0>:d
         mov (8|M0)               r10.0<1>:d    r12.1<2;1,0>:d
         mov (8|M8)               r9.0<1>:d     r14.0<2;1,0>:d
         mov (8|M8)               r11.0<1>:d    r14.1<2;1,0>:d
         add (16|M0)              r6.0<1>:d     r6.0<8;8,1>:d     r5.2<0;1,0>:d    {Compacted}
         sends (16|M0)            null:w   r6      r8      0x10C       0x4025C00  //    wr:2+4, rd:0, Untyped Surface Write msc:28, to #0
(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10
L224:
Trying to assemble icule.asm
NArray.float(10752):
[ 0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, ... ]
Number of subslice: 3
memory_footprint: 86.016 KB
unroll_factor: 1000
ν: 350 mhz
Δt: 1939083 ns
bw: 44.35911201325575 GB/s
bw: 126.74032003787359 B/clk
peak: 66.01058335305916 %
```

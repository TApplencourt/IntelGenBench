L0:
(W)      mov (8|M0)               r2.0<1>:ud    r0.0<1;1,0>:ud                  
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      shl (1|M0)               r3.0<1>:d     r2.1<0;1,0>:d     4:w             
(W)      mov (8|M0)               r127.0<1>:ud  r2.0<8;8,1>:ud                   {Compacted}
         add (16|M0)              r6.0<1>:d     r3.0<0;1,0>:d     r1.0<16;16,1>:uw
         add (16|M0)              r6.0<1>:d     r6.0<8;8,1>:d     r4.0<0;1,0>:d    {Compacted}
         shl (16|M0)              r6.0<1>:d     r6.0<8;8,1>:d     2:w             
         add (16|M0)              r8.0<1>:d     r6.0<8;8,1>:d     r5.5<0;1,0>:d    {Compacted}
         add (16|M0)              r6.0<1>:d     r6.0<8;8,1>:d     r5.4<0;1,0>:d    {Compacted}
         {% for _ in range(n) %}
         send (16|M0)             r10:w    r8      0xC                 0x4205E01  
         sends (16|M0)            null:w   r6      r10     0x8C        0x4025E00 
         {%- endfor %}
(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10
L160:

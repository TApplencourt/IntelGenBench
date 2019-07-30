L0:
(W)      mov (8|M0)               r3.0<1>:ud    r0.0<1;1,0>:ud                  
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      mul (1|M0)               r6.0<1>:d     r8.3<0;1,0>:d     r3.1<0;1,0>:d    {Compacted}
         mov (16|M0)              r11.0<1>:f    1.0:f                           
         mov (16|M16)             r13.0<1>:f    1.0:f                           
(W)      mov (8|M0)               r127.0<1>:ud  r3.0<8;8,1>:ud                   {Compacted}
         add (16|M0)              r4.0<1>:d     r6.0<0;1,0>:d     r1.0<16;16,1>:uw
         add (16|M16)             r9.0<1>:d     r6.0<0;1,0>:d     r2.0<16;16,1>:uw
         add (16|M0)              r4.0<1>:d     r4.0<8;8,1>:d     r7.0<0;1,0>:d    {Compacted}
         add (16|M16)             r9.0<1>:d     r9.0<8;8,1>:d     r7.0<0;1,0>:d   
         shl (16|M0)              r4.0<1>:d     r4.0<8;8,1>:d     2:w             
         shl (16|M16)             r9.0<1>:d     r9.0<8;8,1>:d     2:w             
         add (16|M0)              r4.0<1>:d     r4.0<8;8,1>:d     r8.2<0;1,0>:d    {Compacted}
         add (16|M16)             r9.0<1>:d     r9.0<8;8,1>:d     r8.2<0;1,0>:d   

         {% for _ in range(n) %}
         sends (16|M0)            null:w   r4      r11     0x8C        0x4025E00 
         sends (16|M16)           null:w   r9      r13     0x8C        0x4025E00 
         {%- endfor %}
(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10
L240:

L0:
(W)      mov (8|M0)               r2.0<1>:ud    r0.0<1;1,0>:ud                  
(W)      or (1|M0)                cr0.0<1>:ud   cr0.0<0;1,0>:ud   0x4C0:uw         {Switch}
(W)      shl (1|M0)               r5.0<1>:d     r2.1<0;1,0>:d     3:w             
(W)      mov (8|M0)               r127.0<1>:ud  r2.0<8;8,1>:ud                   {Compacted}
         add (8|M0)               r3.0<1>:d     r5.0<0;1,0>:d     r1.0<8;8,1>:uw  
         add (8|M0)               r3.0<1>:d     r3.0<8;8,1>:d     r4.0<0;1,0>:d    {Compacted}
         shl (8|M0)               r3.0<1>:d     r3.0<8;8,1>:d     2:w             
         add (8|M0)               r3.0<1>:d     r3.0<8;8,1>:d     r5.2<0;1,0>:d    {Compacted}

        {% for _ in range(n) %}
        send (8|M0)              r6:f     r3      0xC         0x2106E00  // Load from r6 amd store in r3
        {%- endfor %}

(W)      send (8|M0)              null     r127    0x27        0x2000010  {EOT} //    wr:1+?, rd:0, fc: 0x10
L168:

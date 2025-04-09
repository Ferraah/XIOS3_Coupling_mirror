# Monodirectional coupling of a single field with restart file and accumulation

This examples follows the previous one by enabling the accumulation functionality to the coupler.\
The parameters remain the same as before:

|  | Ocean | Atmosphere|
|----------|----------|----------|
|Start date|Jan 01, 2025|Jan 01, 2025 
| Duration  |  31d       | 31d         |
|Timestep| 6h | 6h
| Send/recv frequency          | 4ts          | 4ts         |
This translates to:
| freq_op | 4ts| 4ts
| freq_offset | 0ts | 5ts|
| (Restart field) freq_op | 1y *| 1y*
| (Restart field) freq_offset | 0ts | 1ts|

\* arbitrarily large, so to load one time during the run

## Algorithm explaination

When dealing with accumulation, we have to create an auxiliary field in the sender context, and refer to it in the coupler out:
```xml 
<!-- Accumulate and average on this field --> 
<field_definition>
    <field id="field2D_accumulate" grid_ref="grid_2D"  operation="average" read_access="true" expr="@this"/>
</field_definition>

<coupler_out_definition>
    <coupler_out context="atm::atm" >
        <field id="field2D_oce_to_atm" field_ref="field2D_accumulate" freq_op="4ts"/>
        ...
        ...
```



# Output
```
   ATM: receiving restart field @ts=           1  with value 
  0.000000000000000E+000
 OCN: sending field @ts=           1  with value    1.00000000000000     
 OCN: sending field @ts=           2  with value    2.00000000000000     
 OCN: sending field @ts=           3  with value    3.00000000000000     
 OCN: sending field @ts=           4  with value    4.00000000000000     
   ATM: receiving field @ts=           5  with value    2.50000000000000     
 OCN: sending field @ts=           5  with value    5.00000000000000     
 OCN: sending field @ts=           6  with value    6.00000000000000     
 OCN: sending field @ts=           7  with value    7.00000000000000     
 OCN: sending field @ts=           8  with value    8.00000000000000     
   ATM: receiving field @ts=           9  with value    6.50000000000000     
 OCN: sending field @ts=           9  with value    9.00000000000000     
 OCN: sending field @ts=          10  with value    10.0000000000000     
 OCN: sending field @ts=          11  with value    11.0000000000000     
 OCN: sending field @ts=          12  with value    12.0000000000000     
   ATM: receiving field @ts=          13  with value    10.5000000000000     
 OCN: sending field @ts=          13  with value    13.0000000000000     
 OCN: sending field @ts=          14  with value    14.0000000000000     
 OCN: sending field @ts=          15  with value    15.0000000000000     
 OCN: sending field @ts=          16  with value    16.0000000000000     
   ATM: receiving field @ts=          17  with value    14.5000000000000     
 OCN: sending field @ts=          17  with value    17.0000000000000     
 OCN: sending field @ts=          18  with value    18.0000000000000     
 OCN: sending field @ts=          19  with value    19.0000000000000     
 OCN: sending field @ts=          20  with value    20.0000000000000     
   ATM: receiving field @ts=          21  with value    18.5000000000000     
 OCN: sending field @ts=          21  with value    21.0000000000000     
 OCN: sending field @ts=          22  with value    22.0000000000000     
 OCN: sending field @ts=          23  with value    23.0000000000000     
 OCN: sending field @ts=          24  with value    24.0000000000000     
   ATM: receiving field @ts=          25  with value    22.5000000000000     
 OCN: sending field @ts=          25  with value    25.0000000000000     
 OCN: sending field @ts=          26  with value    26.0000000000000     
 OCN: sending field @ts=          27  with value    27.0000000000000     
 OCN: sending field @ts=          28  with value    28.0000000000000     
   ATM: receiving field @ts=          29  with value    26.5000000000000     
 OCN: sending field @ts=          29  with value    29.0000000000000     
 OCN: sending field @ts=          30  with value    30.0000000000000     
 OCN: sending field @ts=          31  with value    31.0000000000000     
 OCN: sending field @ts=          32  with value    32.0000000000000     
   ATM: receiving field @ts=          33  with value    30.5000000000000     
 OCN: sending field @ts=          33  with value    33.0000000000000     
 OCN: sending field @ts=          34  with value    34.0000000000000     
 OCN: sending field @ts=          35  with value    35.0000000000000     
 OCN: sending field @ts=          36  with value    36.0000000000000     
   ATM: receiving field @ts=          37  with value    34.5000000000000     
 OCN: sending field @ts=          37  with value    37.0000000000000     
 OCN: sending field @ts=          38  with value    38.0000000000000     
 OCN: sending field @ts=          39  with value    39.0000000000000     
 OCN: sending field @ts=          40  with value    40.0000000000000     
   ATM: receiving field @ts=          41  with value    38.5000000000000     
 OCN: sending field @ts=          41  with value    41.0000000000000     
 OCN: sending field @ts=          42  with value    42.0000000000000     
 OCN: sending field @ts=          43  with value    43.0000000000000     
 OCN: sending field @ts=          44  with value    44.0000000000000     
   ATM: receiving field @ts=          45  with value    42.5000000000000     
 OCN: sending field @ts=          45  with value    45.0000000000000     
 OCN: sending field @ts=          46  with value    46.0000000000000     
 OCN: sending field @ts=          47  with value    47.0000000000000     
 OCN: sending field @ts=          48  with value    48.0000000000000     
   ATM: receiving field @ts=          49  with value    46.5000000000000     
 OCN: sending field @ts=          49  with value    49.0000000000000     
 OCN: sending field @ts=          50  with value    50.0000000000000     
 OCN: sending field @ts=          51  with value    51.0000000000000     
 OCN: sending field @ts=          52  with value    52.0000000000000     
   ATM: receiving field @ts=          53  with value    50.5000000000000     
 OCN: sending field @ts=          53  with value    53.0000000000000     
 OCN: sending field @ts=          54  with value    54.0000000000000     
 OCN: sending field @ts=          55  with value    55.0000000000000     
 OCN: sending field @ts=          56  with value    56.0000000000000     
   ATM: receiving field @ts=          57  with value    54.5000000000000     
 OCN: sending field @ts=          57  with value    57.0000000000000     
 OCN: sending field @ts=          58  with value    58.0000000000000     
 OCN: sending field @ts=          59  with value    59.0000000000000     
 OCN: sending field @ts=          60  with value    60.0000000000000     
   ATM: receiving field @ts=          61  with value    58.5000000000000     
 OCN: sending field @ts=          61  with value    61.0000000000000     
 OCN: sending field @ts=          62  with value    62.0000000000000     
 OCN: sending field @ts=          63  with value    63.0000000000000     
 OCN: sending field @ts=          64  with value    64.0000000000000     
   ATM: receiving field @ts=          65  with value    62.5000000000000     
 OCN: sending field @ts=          65  with value    65.0000000000000     
 OCN: sending field @ts=          66  with value    66.0000000000000     
 OCN: sending field @ts=          67  with value    67.0000000000000     
 OCN: sending field @ts=          68  with value    68.0000000000000     
   ATM: receiving field @ts=          69  with value    66.5000000000000     
 OCN: sending field @ts=          69  with value    69.0000000000000     
 OCN: sending field @ts=          70  with value    70.0000000000000     
 OCN: sending field @ts=          71  with value    71.0000000000000     
 OCN: sending field @ts=          72  with value    72.0000000000000     
   ATM: receiving field @ts=          73  with value    70.5000000000000     
 OCN: sending field @ts=          73  with value    73.0000000000000     
 OCN: sending field @ts=          74  with value    74.0000000000000     
 OCN: sending field @ts=          75  with value    75.0000000000000     
 OCN: sending field @ts=          76  with value    76.0000000000000     
   ATM: receiving field @ts=          77  with value    74.5000000000000     
 OCN: sending field @ts=          77  with value    77.0000000000000     
 OCN: sending field @ts=          78  with value    78.0000000000000     
 OCN: sending field @ts=          79  with value    79.0000000000000     
 OCN: sending field @ts=          80  with value    80.0000000000000     
   ATM: receiving field @ts=          81  with value    78.5000000000000     
 OCN: sending field @ts=          81  with value    81.0000000000000     
 OCN: sending field @ts=          82  with value    82.0000000000000     
 OCN: sending field @ts=          83  with value    83.0000000000000     
 OCN: sending field @ts=          84  with value    84.0000000000000     
   ATM: receiving field @ts=          85  with value    82.5000000000000     
 OCN: sending field @ts=          85  with value    85.0000000000000     
 OCN: sending field @ts=          86  with value    86.0000000000000     
 OCN: sending field @ts=          87  with value    87.0000000000000     
 OCN: sending field @ts=          88  with value    88.0000000000000     
   ATM: receiving field @ts=          89  with value    86.5000000000000     
 OCN: sending field @ts=          89  with value    89.0000000000000     
 OCN: sending field @ts=          90  with value    90.0000000000000     
 OCN: sending field @ts=          91  with value    91.0000000000000     
 OCN: sending field @ts=          92  with value    92.0000000000000     
   ATM: receiving field @ts=          93  with value    90.5000000000000     
 OCN: sending field @ts=          93  with value    93.0000000000000     
 OCN: sending field @ts=          94  with value    94.0000000000000     
 OCN: sending field @ts=          95  with value    95.0000000000000     
 OCN: sending field @ts=          96  with value    96.0000000000000     
   ATM: receiving field @ts=          97  with value    94.5000000000000     
 OCN: sending field @ts=          97  with value    97.0000000000000     
 OCN: sending field @ts=          98  with value    98.0000000000000     
 OCN: sending field @ts=          99  with value    99.0000000000000     
 OCN: sending field @ts=         100  with value    100.000000000000     
   ATM: receiving field @ts=         101  with value    98.5000000000000     
 OCN: sending field @ts=         101  with value    101.000000000000     
 OCN: sending field @ts=         102  with value    102.000000000000     
 OCN: sending field @ts=         103  with value    103.000000000000     
 OCN: sending field @ts=         104  with value    104.000000000000     
   ATM: receiving field @ts=         105  with value    102.500000000000     
 OCN: sending field @ts=         105  with value    105.000000000000     
 OCN: sending field @ts=         106  with value    106.000000000000     
 OCN: sending field @ts=         107  with value    107.000000000000     
 OCN: sending field @ts=         108  with value    108.000000000000     
   ATM: receiving field @ts=         109  with value    106.500000000000     
 OCN: sending field @ts=         109  with value    109.000000000000     
 OCN: sending field @ts=         110  with value    110.000000000000     
 OCN: sending field @ts=         111  with value    111.000000000000     
 OCN: sending field @ts=         112  with value    112.000000000000     
   ATM: receiving field @ts=         113  with value    110.500000000000     
 OCN: sending field @ts=         113  with value    113.000000000000     
 OCN: sending field @ts=         114  with value    114.000000000000     
 OCN: sending field @ts=         115  with value    115.000000000000     
 OCN: sending field @ts=         116  with value    116.000000000000     
   ATM: receiving field @ts=         117  with value    114.500000000000     
 OCN: sending field @ts=         117  with value    117.000000000000     
 OCN: sending field @ts=         118  with value    118.000000000000     
 OCN: sending field @ts=         119  with value    119.000000000000     
 OCN: sending field @ts=         120  with value    120.000000000000     
   ATM: receiving field @ts=         121  with value    118.500000000000     
 OCN: sending field @ts=         121  with value    121.000000000000     
 OCN: sending field @ts=         122  with value    122.000000000000     
 OCN: sending field @ts=         123  with value    123.000000000000     
 OCN: sending field @ts=         124  with value    124.000000000000     
Server Context destructor
Server Context destructor
Server Context destructor
Server Context destructor
```


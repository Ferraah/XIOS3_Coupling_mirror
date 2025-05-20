# Monodirectional coupling of a single field with restart file and integration

This example showcases an coupling scheme that includes a time integration on sampled elements over the coupling period.  
The simulation is done over 5 days with exchanges every day (1d = 4ts) of a field that is the result of an operation applied to the sampled element over a day. Sampled elements refer to the elements that we choose between the one sent by the model for doing an operation with a certain frequency defined in `field2D_send` tag.

|  | Ocean | Atmosphere|
|----------|----------|----------|
|Start date|Jan 01, 2025|Jan 01, 2025 
| Duration  |  5d       | 5d         |
|Timestep| 6h | 6h
| Send/recv frequency          | 4ts          | 4ts         |
This translates to:
| field2D_send.freq_op (sampling) | 2ts | |
| field2D_send.freq_offset (sampling) | 1ts | |
| field2D_oce_to_atm.freq_op | 4ts| 4ts
| field2D_oce_to_atm.freq_offset |  | 5ts|
| field2D_restart.freq_op | 1y *| 1y*


\* arbitrarily large, so to load one time during the run

![Visualization](./3_integration.png)
## Algorithm explaination

With this particular configuration, we set as before a field reference for `xios_send_field` named `field2D_send`. Here we are setting three attributes with the following purposes:
- `field2D_send`.`operation`: The operation to apply over an integration period, which is defined in field `field2D_oce_to_atm`
- `field2D_send`.`freq_op`: It is the frequency of **sampling**, to define the elements onto which xios will do the integration
- `field2D_send`.`freq_offset`: The offset to add to `@ts=1` for starting the **sampling** of elements

A so called time filter is triggered when the new flux `field2D_oce_to_atm`, that also acts as an interface for the coupler, defines the following atributes:
- `field2D_oce_to_atm`.`field_ref`: the reference field from which attributes such as the grid are inherited.
- `field2D_oce_to_atm`.`expr`: We refer to `@this_ref` as the the field onto which make the integration operation. The reference is what we have set in `field_ref` 
- `field2D_oce_to_atm`.`freq_op`: It is the frequency at which the operation is applied and at which the result is made available. In the copuler_out, it means that the value is calculated and made available for the coupler in in the receiving context.
- `field2D_oce_to_atm`.`freq_offset`: As discussed before, it refers to offsetting the first timestep at which the operation is applied.

We should set this freq_op and freq_offset parameters as "put" operations described in `0_xios_intro`.   
```xml 
<field_definition>
    <!-- sampling frequency, sampling offset and operation to perform here-->
    <field id="field2D_send" grid_ref="grid_2D" freq_op="2ts" freq_offset="1ts" operation="average"/>
</field_definition>

<coupler_out_definition>
    <coupler_out context="atm::atm" >
        <!-- Define the interface for the outgoing field to be received in atmosphere -->
        <!-- sending frequency/operation applied frequency -->
        <field id="field2D_oce_to_atm" field_ref="field2D_send" freq_op="4ts" expr="@this_ref" />
        <!-- Define the interface for the outgoing field loaded from file to be received in atmosphere -->
        <field id="field2D_restart" field_ref="field2D_read"/>
    </coupler_out>
</coupler_out_definition>
```

## Detail on saving the last field
As we see in the file definitions:
```xml

<!-- Save field on file after 5d (The last send, corresponding to the run duration)-->
<!-- Remember to set operation="instant", otherwise it would inherit operation average and perform it over 5 days. Like this, we only pick the last sent value -->
<file id="restart_next" name="restart_next" output_freq="5d" type="one_file" enabled="true" append="false">
    <field field_ref="field2D_oce_to_atm" operation="instant" />
</file>
```
We refer to `field2D_oce_to_atm` to save the last field. `output_freq` behaves like the `freq_offset` attribute in the `coupler_out` by performing the instant operation after 5 days on our already integrated field  and save it to file. 


# Output
```
   ATM: receiving restart field @ts=           1  with value 
  0.000000000000000E+000
 OCN: sending field @ts=           1  with value    1.00000000000000     
 OCN: sending field @ts=           2  with value    2.00000000000000     
 OCN: sending field @ts=           3  with value    3.00000000000000     
 OCN: sending field @ts=           4  with value    4.00000000000000     
   ATM: receiving field @ts=           5  with value    3.00000000000000     
 OCN: sending field @ts=           5  with value    5.00000000000000     
 OCN: sending field @ts=           6  with value    6.00000000000000     
 OCN: sending field @ts=           7  with value    7.00000000000000     
 OCN: sending field @ts=           8  with value    8.00000000000000     
   ATM: receiving field @ts=           9  with value    7.00000000000000     
 OCN: sending field @ts=           9  with value    9.00000000000000     
 OCN: sending field @ts=          10  with value    10.0000000000000     
 OCN: sending field @ts=          11  with value    11.0000000000000     
 OCN: sending field @ts=          12  with value    12.0000000000000     
   ATM: receiving field @ts=          13  with value    11.0000000000000     
 OCN: sending field @ts=          13  with value    13.0000000000000     
 OCN: sending field @ts=          14  with value    14.0000000000000     
 OCN: sending field @ts=          15  with value    15.0000000000000     
 OCN: sending field @ts=          16  with value    16.0000000000000     
   ATM: receiving field @ts=          17  with value    15.0000000000000     
 OCN: sending field @ts=          17  with value    17.0000000000000     
 OCN: sending field @ts=          18  with value    18.0000000000000     
 OCN: sending field @ts=          19  with value    19.0000000000000     
 OCN: sending field @ts=          20  with value    20.0000000000000     
Server Context destructor
Server Context destructor
Server Context destructor
Server Context destructor
```
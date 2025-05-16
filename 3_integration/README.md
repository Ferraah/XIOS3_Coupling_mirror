# Monodirectional coupling of a single field with restart file and integration

This example showcases an coupling scheme that includes a time integration over the coupling period.  
The parameters are the following: 5 days and 4 exchanges every day, with restarting and save file.

|  | Ocean | Atmosphere|
|----------|----------|----------|
|Start date|Jan 01, 2025|Jan 01, 2025 
| Duration  |  5d       | 5d         |
|Timestep| 6h | 6h
| Send/recv frequency          | 4ts          | 4ts         |
This translates to:
| freq_op | 4ts| 4ts
| freq_offset | 0ts | 5ts|
| (Restart field) freq_op | 1y *| 1y*
| (Restart field) freq_offset | 0ts | 1ts|

\* arbitrarily large, so to load one time during the run

![Visualization](./3_singlefield_integrate.png)
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
    <field id="field2D_send" grid_ref="grid_2D" freq_op="2ts" freq_offset="1ts" operation="average" build_workflow_graph="true"/>
</field_definition>

<coupler_out_definition>
    <coupler_out context="atm::atm" >
        <!-- Define the interface for the outgoing field to be received in atmosphere -->
        <field id="field2D_oce_to_atm" field_ref="field2D_send" freq_op="4ts" freq_offset="3ts" expr="@this_ref" />
        <!-- Define the interface for the outgoing field loaded from file to be received in atmosphere -->
        <field id="field2D_restart" field_ref="field2D_read"/>
    </coupler_out>
</coupler_out_definition>
```

## Detail on saving the last field
As we see in the file definitions:
```xml
<!-- Save field on file after 5d (The last send, corresponding to the run duration)-->
<file id="restart_next" name="restart_next" output_freq="5d" type="one_file" enabled="true" append="false">
    <field field_ref="field2D_oce_to_atm" operation="instant"/>
</file>
```
We refer to `field2D_oce_to_atm` to save the last field. `output_freq` behaves like the `freq_offset` attribute in the `coupler_out` by performing the instant operation after 5 days on our already integrated field  and save it to file. We could also move the `operator` tag in the coupling field because we would inherit it by reference. 


# Output

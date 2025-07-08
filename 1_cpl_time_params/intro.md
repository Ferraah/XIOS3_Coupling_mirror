# Coupling schemes time parameters
Run with:
```
./runIntro.sh
```
## Monodirectional coupling of a single field with restart file

This example demonstrates the coupling functionality between two model contexts: `ocn` (ocean) and `atm` (atmosphere). In this setup, the ocean model is responsible for sending a field to the atmosphere model, which receives it. The first field received by the atmosphere is loaded from a restart file, ensuring continuity from a previous run. Subsequently, the ocean model sends the field every 5 days; however, the final send is not received but instead saved to a file for use in the next simulation. While the time parameters used here are not realistic (one exchange every 5 days), they are chosen to clearly illustrate the coupling scheme involving a restart file. We begin with this example because using a restart file is the most used scheme. 


|  | Ocean | Atmosphere|
|----------|----------|----------|
|Start date|Apr 01, 2025|Apr 01, 2025 
| Duration  |  30d       | 30d         |
|Timestep| 1d | 1d
| Coupling freq          | 5ts          | 5ts         |

This Translates into the following time parameters in coupler in and out (no sampling):

## Non restarting field attributes
| Ocean field attribute | Value |
|----------|----------|
| Sampling freq_op | 1ts (default)| 
| Sampling freq_offset | 0ts| 
| Coupler_out  freq_op | 5ts |

| Atmosphere field attribute | Value |
|----------|----------|
| Coupler_in  freq_op | 5ts |
| Coupler_in  freq_offset | 6ts |

## Restarting field attributes
| Ocean field attribute | Value |
|----------|----------|
| file output_freq | 1y (arbitrarily large, so to load one time during the run)|
| freq_offset | 0ts (default in read mode from file)|
| Coupler_out freq_op | 1y (arbitrarily large, so to send one time during the run)|

| Atmosphere field attribute | Value |
|----------|----------|
| Coupler_in freq_op | 1y |
| Coupler_in freq_offset | 1ts (to maket it available at @ts=1 instead of @ts=0)|

You can find these attribute in iodef.xml.

![plot](1_cpl_time_parameters.png)  

## Algorithm explaination

As with OASIS, we set the simulation duration to be a multiple of the coupling frequency (`30d`). Timesteps are indexed starting from 1, consistent with the convention of XIOS. To replicate the lag behavior seen in Oasis—where the first field is obtained from the restart file—we ensure that the field sent at `@ts=5` by the ocean is received by the atmosphere at `@ts=6`, and so forth. Thus, at `@ts=1`, the atmosphere receives the field from the restart file, and after one coupling interval (at `@ts=6`), it receives the next field sent by the ocean model.


### xios_send_field & xios_recv_field
`xios_send_field` put logic is unchanged from OASIS.\
As opposed to what happens with oasis GET, a restarting field with a different symbolic name should be set explicitly when calling the first `xios_recv_field`:

```fortran
!!! First reception is done explicitly on the restart field from the related file
IF (curr_timestep == 1) THEN
    CALL xios_recv_field("field2D_restart", field_recv)
    print *, "Model ", model_id, " received " , field_recv(1,1), " @ts = ", curr_timestep

ELSE IF (modulo(curr_timestep-1, freq_op) == 0) THEN
    CALL xios_recv_field("field2D_recv", field_recv)
    print *, "Model ", model_id, " received " , field_recv(1,1), " @ts = ", curr_timestep
END IF
```
In XIOS, the `ocn` context is responsible for providing the restart field to the `atm` context. Therefore, the reference to the restart file must be defined within the `ocn` context, ensuring that the ocean model manages both the sending of the coupling field and the initialization of the restart data for the atmosphere.
```xml
<file_definition>
    ...
<!-- Restart file to READ -->
<!-- output_freq refers to the reading frequency. mode is set up on "read" -->
<file id="restart_zerofield" name="restart_zerofield" enabled="true" type="one_file" output_freq="1y" mode="read">
    <!-- name attribute should be the same of the field in the nc file -->
    <field id="field2D_read" name="field2D_oce_to_atm" grid_ref="grid_2D" operation="instant" read_access="true"  />
</file> 

</file_definition>
```
The coupler out will contain two interface fields, one referring to the restart field sent only one time during the simulation, and the field sent by the model every time period:
```xml
<!-- OCEAN CONTEXT -->
<coupler_out_definition>
    <coupler_out context="atm::atm" >
        <field id="field2D_oce_to_atm" grid_ref="grid_2D" freq_op="5ts"/>
        <!-- Restart field-->
        <field id="field2D_restart" field_ref="field2D_read" freq_op="1y"/>
    </coupler_out>
</coupler_out_definition>
```
```xml
<!-- ATM CONTEXT -->
<coupler_in_definition>
    <coupler_in context="ocn::ocn" >
        <field id="field2D_oce_to_atm" grid_ref="grid_2D" freq_op="5ts" freq_offset="6ts" operation="instant" read_access="true"/>
        <!-- Restart field for atm is provided by ocean - freq_op big so to execute it only one time, offset to run it @ts=1 instead of @ts=0-->
        <field id="field2D_restart" grid_ref="grid_2D_restart" freq_op="1y" freq_offset="1ts" operation="instant" read_access="true"/>
    </coupler_in>
</coupler_in_definition>
```
To save the last send, we can tell XIOS to save the field in a file with a frequency that is the same as the duration of the run, so to execute it one time at the end of the run:
```xml
<!-- Save field on file after 30d (The last send, corresponding to the run duration)-->
<!-- It will create a new file called restart_next with the field and its timestemp-->
<file id="restart_next" name="restart_next" output_freq="30d" type="one_file" enabled="true">
    <field field_ref="field2D_oce_to_atm"  />
</file>
```
# Output
The toy model is made to send a value which corresponds to the current timestep that is traversing with respect to January 1. The value received @ts=1 is the one in the restart file, which corresponds to a field generated in a previous run (2025-03-31 18:00:00, the value is loaded is 0). Note how we are effectively sending the data with a lag. 
```
   ATM: receiving restart field @ts=           1  with value 
  0.000000000000000E+000
 OCN: sending field @ts=           1  with value    91.0000000000000     
 OCN: sending field @ts=           2  with value    92.0000000000000     
 OCN: sending field @ts=           3  with value    93.0000000000000     
 OCN: sending field @ts=           4  with value    94.0000000000000     
 OCN: sending field @ts=           5  with value    95.0000000000000     
   ATM: receiving field @ts=           6  with value    95.0000000000000     
 OCN: sending field @ts=           6  with value    96.0000000000000     
 OCN: sending field @ts=           7  with value    97.0000000000000     
 OCN: sending field @ts=           8  with value    98.0000000000000     
 OCN: sending field @ts=           9  with value    99.0000000000000     
 OCN: sending field @ts=          10  with value    100.000000000000     
   ATM: receiving field @ts=          11  with value    100.000000000000     
 OCN: sending field @ts=          11  with value    101.000000000000     
 OCN: sending field @ts=          12  with value    102.000000000000     
 OCN: sending field @ts=          13  with value    103.000000000000     
 OCN: sending field @ts=          14  with value    104.000000000000     
 OCN: sending field @ts=          15  with value    105.000000000000     
   ATM: receiving field @ts=          16  with value    105.000000000000     
 OCN: sending field @ts=          16  with value    106.000000000000     
 OCN: sending field @ts=          17  with value    107.000000000000     
 OCN: sending field @ts=          18  with value    108.000000000000     
 OCN: sending field @ts=          19  with value    109.000000000000     
 OCN: sending field @ts=          20  with value    110.000000000000     
   ATM: receiving field @ts=          21  with value    110.000000000000     
 OCN: sending field @ts=          21  with value    111.000000000000     
 OCN: sending field @ts=          22  with value    112.000000000000     
 OCN: sending field @ts=          23  with value    113.000000000000     
 OCN: sending field @ts=          24  with value    114.000000000000     
 OCN: sending field @ts=          25  with value    115.000000000000     
   ATM: receiving field @ts=          26  with value    115.000000000000     
 OCN: sending field @ts=          26  with value    116.000000000000     
 OCN: sending field @ts=          27  with value    117.000000000000     
 OCN: sending field @ts=          28  with value    118.000000000000     
 OCN: sending field @ts=          29  with value    119.000000000000     
 OCN: sending field @ts=          30  with value    120.000000000000 
```
Using the command `ncdump restart_next.nc`, we should see our 10x10 field of 120's corresponding to the field on `2025-04-30 00:00:00`

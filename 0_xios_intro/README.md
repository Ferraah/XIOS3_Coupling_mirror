# Brief introduction to XIOS basic functionalities

Before exploring the coupling functionality, it is essential to first understand how XIOS operates for its original purpose. Refer to the XIOS documentation and hands on tutorials. 

Explainations for this example can be found in the toymodel source file and iodef.xml.

The iodef.xml file contains the parameters and the definitions of the fields that we are going to manipulate with XIOS. In this example we will just send a field every timestep from a client to the server, which will then save it on a file. At the same time, fields for each timestep will be loaded from file and sent to the client.  

# First timing notions
XIOS handles the concept of time in the model through the routine `xios_update_calendar(timestep)`, by which the user can set the current timestep, before performing a `xios_send_field` `xios_recv_field`. It is strongly reccomended to start counting the timesteps from `@ts=1` due to a mismatch of loading/writing timing logic that we will cover later on, and that will affect the implementation of our coupling scheme. Indeed, this is the standard in XIOS, but in coupler softwares such as OASIS, we are usually used to index time from 0 instead. 

**Time filters** are activated when a field is included into a `<file>` for writing or reading, or it is reused by another field after performing an operation on it (for example the coupled one in the next examples).
To access a field content at a specific timestep, we have to make that available in XIOS. 

The timing parameters are defined with a set of attributes, which leads to different behaviours depending onto which functionalities are defined. These are:
- output_freq: With this attribute we can define the frequency at which the reading or writing operation is performed when dealing with files, and it is defined only on `<file>` tags.
- freq_op: It is the attribute to define the frequency of the so called "operations" that can be performed on fields using time filters, and it has been extended to coupling functionalities. We found this in `<field>` tags. It can also be used as the "sampling frequency" for integration in a coupling period, but we will se that later. 
- freq_offset: It is the number of timesteps to define a shift from the default starting timestep for the operation and sampling. We found this in `<field>` tags.

Let's directly see how it works in a coupler, but the concepts are the same as if we were writing to file the result:
```fortran
xios_set_calendar(i) 
xios_send_field("field2D_send", field) ! Send field to xios at i-th timestep
```
```xml
<field_definition>
    <!-- sampling frequency, sampling offset and operation to perform here-->
    <field id="field2D_send" grid_ref="grid_2D" freq_op="xxx ts" freq_offset="xxx ts" operation="average"/>
</field_definition>

<coupler_out_definition>
    <coupler_out context="atm::atm" >
        <!-- Define the interface for the outgoing field to be received in atmosphere -->
        <!-- sending frequency/operation applied frequency -->
        <field id="field2D_oce_to_atm" field_ref="field2D_send" freq_op="xxx ts" expr="@this_ref" />
    </coupler_out>
</coupler_out_definition>
```
```xml
<field_definition>
    <field id="field2D_recv" field_ref="field2D_oce_to_atm" />
</field_definition>

<!-- Fields coming from ocean -->
<coupler_in_definition>
    <coupler_in context="ocn::ocn" >
        <!-- Like this we make available the field from the second coupling period -->
        <field id="field2D_oce_to_atm" grid_ref="grid_2D" freq_op="xxx ts" freq_offset="xxx ts" operation="instant" read_access="true"/>
        <!-- Restart field for atm is provided by ocean - freq_op big so to execute it only one time, offset to run it @ts=1 instead of @ts=0-->
        <field id="field2D_restart" grid_ref="grid_2D" freq_op="1y" freq_offset="1ts" operation="instant" read_access="true"/>
    </coupler_in>
</coupler_in_definition>
```

```fortran
xios_set_calendar(i) 
if (mod(i-1, cpl_freq) == 0) then
    xios_recv_field("field2D_recv", field) ! Receive field from xios at i-th timestep. Has to be called at the "rigth" timestep
end if
```

Legend for the following plots:
- Blue arrows refer to the model sending a field at a certain timestep.
- The larger light blue rectangles represent the "integration" periods, that in XIOS are also the coupling periods.
- The small blue rectangles are the elements in the integration period onto which the operation will be applied. 

# 
![No offset](./0.png)

sampling_offset = 0ts $\implies$  It means we will start sampling from 1 \
sampling_freq = 2ts $\implies$ Sample element with this freq starting from $1 + sampling\_ offset$ \
send_freq = 4ts $\implies$ The frequency at which the selected integration operation will be executed onto the sampled elements. The result is available to be coupled or saved to file. Here is done at 4 with the content sent @1 and @3, and so on.

#
![No offset](./1.png)

sampling_offset = 2ts $\implies$  It means we will start sampling from 1+2=3 \
sampling_freq = 2ts $\implies$ Sample element with this freq starting from $1 + sampling\_ offset$ \
send_freq = 4ts $\implies$ The frequency at which the selected integration operation will be executed onto the sampled elements, starting from $1 + sampling\_ offset$. The result is available to be coupled or saved to file. Here is done at 6 with the content sent @1 and @3, and so on.
#

Together:

![Receiving](./2.png)

The red arrow represents the `xios_recv_field` at the relative timestep, and the yellow line the first field loaded from file.  \
sampling_offset = 0ts \
sampling_freq = 2ts \
send_freq = 4ts 

Parameters for the receiving context (red arrows) \
recv_offset = 5ts  
recv_freq = 4ts $\implies$ In order of field arrival from the source model, it makes them available for the receiving model every 4ts starting from $0 + recv\_ offset$. 

### Note there is an asymmetry between offsetting the "puts" vs the "gets" (start from 1 vs 0)

### xios_send_field & xios_recv_field
The routine `xios_send_field` will send a field to xios and that will be stored in a buffer. Periodically, and defined with the time attributes discussed before, XIOS will perform an opertation on these buffered values. 

The routine `xios_recv_field` will retrieve a field that has been made available at a certain timestep, for example a field that has been read from file or one that is the result of an operation. Keep in mind that when calling `xios_recv_field` when no field has been made available will result in a deadlock. 
**For this reason, `xios_recv_field` should be called only on the "right" timesteps that are coherent with the time attributes of the time filters.**
The elements are extracted in order of arrival (FIFO) at the receiving context, and are made available for the model with the time parameters in the coupler in; xios assign a timestamp to these fields as they arrive. This is true both for file and coupled exchanges. 

```fortran
! Receive field starting from 1 with a certain frequency
IF (modulo(curr_timestep-1, freq_op) == 0) THEN
    CALL xios_recv_field("field2D_recv", field_recv)
    print *, "Model ", model_id, " received " , field_recv(1,1), " @ts = ", curr_timestep
END IF
```

<!--
In the next examples we would like to enable client2client exchanges by exploiting XIOS recent experimental coupling routines together with some adaptations to match (some) of OASIS functionalities. In the XIOS implementation, coupling is based on the same concepts (and source code classes) of the "filters" from client to server, modified for model to model communications. 
-->

## Running
```bash
make && ./0_xios_intro
```



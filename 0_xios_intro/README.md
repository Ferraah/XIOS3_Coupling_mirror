# Brief introduction to XIOS basic functionalities

Before exploring the coupling functionality, it is essential to first understand how XIOS operates for its original purpose. Refer to the XIOS documentation and hands on tutorials. 

Explainations can be found in the toymodel source file and iodef.xml.

The iodef.xml file contains the parameters and the definitions of the fields that we are going to manipulate with XIOS. In this example we will just send a field every timestep from a client to the server, which will then save it on a file. At the same time, fields for each timestep will be loaded from file and sent to the client.  

# First timing notions
XIOS handles the concept of time through the usage of the routine `xios_update_calendar(timestep)`, by which the user can set the current timestep before performing a `xios_send_field` `xios_recv_field`. It is strongly reccomended to start counting the timesteps from `@ts=1` due to a mismatch of loading/writing timing logic that we will cover later on, and that will affect the implementation of our coupling scheme. 

**Time filters** are activated when a field is included into a `<file>` for writing or reading, or it is reused by another field after performing an operation on it.
To access a field content at a specific timestep, we have to make that available in XIOS. 

 The timing parameters are defined with a set of attributes, which leads to different behaviours depending onto which functionalities are defined. These are:
- output_freq: With this attribute we can define the frequency at which the reading or writing operation is performed when dealing with files, and it is defined only on `<file>` tags.
- freq_op: It is the attribute to define the frequency of the so called "operations" that can be performed on fields using time filters, and it has been extended to coupling functionalities. We found this in `<field>` tags. 
- freq_offset: It is the number of timesteps to define a shift from the default starting timestep for the operation. We found this in `<field>` tags.

Usage of these attributes can be found in XIOS tutorial.
## Expected first timestep 
When setting the timing attributes we have to pay attention to some details. The first timestep to be subject to any action depends on the type of it, "put" or "get" in a broader sense. More specifically:
### Put actions (Write to file / Performing an operation on the field)
$$ first\_ ts\_ expected = 1 + freq\_ offset$$
if freq_offset is not defined:
$$ freq\_ offset^{default} = freq\_ op-1 $$
### Get actions (Read from file)
$$ first\_ ts\_ expected = 0 + freq\_ offset$$
if freq_offset is not defined:
$$ freq\_ offset^{default} = 0 $$
For these reason, in the iodef.xml the first reading from file is offsetted by one ts to be then read from the model `@ts=1`. There is no need to offset the writing to file because the first value sent will be already done at `@ts=1` by not specifying any freq_offset.
### xios_send_field & xios_recv_field
The routine `xios_send_field` will send a field to xios and that will be stored in a buffer. Periodically, and defined with the time attributes discussed before, XIOS will perform an opertation on these buffered values. How this operations are applied is described on later examples.

The routine `xios_recv_field` will retrieve a field that has been made available at a certain timestep, for example a field that has been read from file or one that is the result of an operation. Keep in mind that when calling `xios_recv_field` when no field has been made available will result in a deadlock. 
**For this reason, `xios_recv_field` should be called only on the "right" timesteps that are coherent with the time attributes of the time filters.**
Furthermore, it should be clear that values are retrieved in order without skipping them: when reading from a file with a frequency of 4ts starting from 1ts, we will get the the first value of the file when calling recv `@ts=1`, but we will receive the second value of the file (not the fourth) `@ts=5`. 

```fortran
! Receive field starting from 1 with a certain frequency
IF (modulo(curr_timestep-1, freq_op) == 0) THEN
    CALL xios_recv_field("field2D_recv", field_recv)
    print *, "Model ", model_id, " received " , field_recv(1,1), " @ts = ", curr_timestep
END IF
```


In the next examples we would like to enable client2client exchanges by exploiting XIOS recent experimental coupling routines together with some adaptations to match (some) of OASIS functionalities.

## Running
```bash
make && ./0_xios_intro
```



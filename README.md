# XIOS3 Coupling
The following repository contains a testuite aimed to the evaluation of XIOS3 as a stand-alone coupling software for numerical models, starting from OASIS3 functionalities and explicitly compare the two for an easier transition between the two.
## Toy models
The toy models will generally be contained in a single FORTRAN file in which we implement the behaviour based on the MPI rank who runs them, and generally we have called them `ocn` and `atm`, with the first being the one performing the `put` operations and the latter performing the `get` operations.

In the examples in which we want to highlight the time settings parameters, we have set the sender toymodel field as single valued matrices, in which the value corresponds to the timestep that the toymodel is traversing.

Again, in other examples, the coupled field has been assigned to highlight the domain decomposition between multiple sender toymodels.

## namcouple vs. iodef.xml
A file called iodef.xml is mandatory to init and run XIOS programs. In this file, different parameters are defined to be read at run-time and provide flexibility to the user that can avoid recompiling the code.

In a coupling setting, we could see this file as the equivalent of the namcouple; however, being XIOS not a dedicated coupler software, it will contain many other parameters regarding XIOS behaviour and some adaptations for emulating an interface to set up the coupling functionalities. 


## Current limitations & important notes
1. The routine `xios_recv_field("....", field_recv)`, equivalent to an `oasis_get`, should be called only on the "right" timestep to ensure the expected results:
    ```fortran
    ! curr_timestep-1 because we associate the starting date to @ts=1 in XIOS
    if (mod(curr_timestep-1, coupling_frequency) == 0) then
        call xios_recv_field("field2D_recv", field_recv)
    end if
    ```
2. Mismatch of the behaviour of the attribute `freq_op` & `freq_offset` between put and get operations, which requires additional considerations when setting time parameters in `iodef.xml`
3. The save to file and the loading of the restarting file have to be explicitly set up in XIOS. To emulate the creation of the starting file at the end of the run, so on the last send, we set up the following lines on the iodef.xml file:
    ```fortran
    <!-- Save field on file after 30d (The last send, corresponding to the run duration)-->
    <file id="restart_next" name="restart_next" output_freq="30d" type="one_file" enabled="true" append="true">
        <field field_ref="field2D_oce_to_atm"  />
    </file>
    ```
    This means that XIOS will save the content of `field2D_oce_to_atm` after 30d, and it will append it to the existing file if it does exists with the name `restart_next.nc`. Unfortunally we cannot refere to the same file we used for loading the restarting field, because it is already opened in XIOS (here `restart.nc`):
    ```fortran
    <!-- Restart file to READ (No output is done on this file). output_freq referes to the reading freq in this mode -->
    <file id="restart" name="restart" enabled="true" type="one_file" output_freq="1y" record_offset="-1" mode="read">
        <field id="field2D_read" name="field2D_oce_to_atm" grid_ref="grid_2D" operation="instant" read_access="true" />
    </file> 
    ``` 
    A solution to this is, indeed:
    1. Copy the original restart file into another one, here `restart.nc` into `restart_next.nc`
    2. Load the restarting field from `restart.nc`, loading the last timestep available from the previous run*
    3. After a run, append the new last field to `restart_next.nc`
    4. Copy `restart_next.nc` into `restart.nc` and proceed with another runs

4. It is not possible to access a field given a specific date from a nc file. It would be very handy to select a restarting field given a date. Up to now we can only access the nth timestep related field in the file with record_offset="n" where n is a pure number. 
Hence, we should manually set in `iodef.xml` the record offset to the index of the last one. (record_offset="-1" to retrieve the last one automatically is not supported yet).
# Monodirectional exchange with interpolation 
The following example shows how we can enable interpolation on XIOS, also in the contex of coupling.
The coupling scheme adopted is the same, temporally speaking. 

|  | Ocean | Atmosphere|
|----------|----------|----------|
|Start date|Apr 01, 2025|Apr 01, 2025 
| Duration  |  30d       | 30d         |
|Timestep| 1d | 1d
| Coupling freq          | 5ts          | 5ts         |
This translates to:
| freq_op | 5ts| 5ts
| freq_offset | 0ts | 6ts|
| (Restart field) freq_op |  | 1y*
| (Restart field) freq_offset |  | 1ts|
| (Save field) output_freq | 30d | | 

![plot](8_interpolate.png)
@TODO: change ocn atm labels

\* arbitrarily large, so to load one time during the run

## Interpolation 
In XIOS, only **conservative remappings** of order 1 & 2 are currently supported. 
In XIOS, we would trigger a spatial interpolation when trying to access a field that is referencing another one, but to whom another grid has been assigned. With 2D fields, for example, this translates to:

```xml
<grid_definition>

    <!-- Original grid -->
    <grid id="grid_2D">
        <domain id="domain" ...attributes of original domain... />
    </grid>

    <!-- Target grid -->
    <grid id="grid_2D_interp">
        <domain id="domain_interp" ...attributes of target domain... >
            <interpolate_domain 
                order="1" 
                renormalize="true" 
                use_area="true" 
                weight_filename="points_files/nogt_bggd.nc"  
                mode="read_or_compute" 
                write_weight="true"/>
        </domain>
    </grid>

</grid_definition>

<field_definition>
    <field id="field_original" grid_ref="grid_2D"/>
    <field id="field_interp" field_ref="field_original" grid_ref="grid_2D_interp"> <!-- Note the different grid -->
</field_definition>

```
The field will be interpolated using the weights already calculated during the initialization phase of XIOS, i.e. after the routine `xios_close_context_definition`. These weights can be saved to file and loaded afterwards. Refer to the documentation for all options available. 

In our coupled code, we will find in the destination context the following, to handle interpolation also on the incoming restart file:
```xml
<field_definition default_value="0" grid_ref="grid_2D_interp" >
    <!-- Endpoint to retrieve interpolated field on toymodel -->
    <field id="field2D_recv" field_ref="field2D_cpl" />
    <field id="field2D_recv_restart" field_ref="field2D_cpl_restart"/>
</field_definition>
```
We additionally added a default_value to handle the missing spots caused by the fact that the incoming field is masked.

# About the toymodels
The toymodels used in this example are more complex because we have to handle the loading of grids and the initializations of the field to send. Particularly:
- `8_inteprolate.f90` contains the usual routines to couple the models. Additionally, we call `init_domain` from `grid_utils.f90` to load the source and target grid from file and then set them in xios at runtime. Then we initialize the fields with some functions defined in`field_initializer.f90`, for example `init_field2d_gulfstream`

- `grid_utils.f90` contains the routines to read grids, masks and area data from nc files, and then calculate the local partitions dimensions to communicate to xios during the context definition.

- `field_initializer.f90` contains some functions to define the field with interesting paterns. 

At the current version of this example, we implement an exchange from a `nogt` grid (ORCA 1 degree, curvilinear) to a `bggd` grid (LMDZ, rectangular).

![plot](interpolated_field_in_interpolated_field.png)
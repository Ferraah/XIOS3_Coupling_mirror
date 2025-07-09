# One sender, multiple receivers

We now try to enable the exchange of a field from one model to multiple ones receiving the same field. Here we will send one from the toymodel `atm` to `ocn` and `ice`.  The temporal coupling scheme is the usual one.

|  | Ocean | Atmosphere|
|----------|----------|----------|
|Start date|Jan 01, 2025|Jan 01, 2025 
| Duration  |  5d       | 5d         |
|Timestep| 6h | 6h
| Coupling freq          | 4ts          | 4ts         |


In iodef:
## Non restarting field attributes

| Ocean field attribute | Value |
|----------|----------|
| Sampling freq_op | 1ts (default)| 
| Sampling freq_offset | 0ts| 
| Coupler_out  freq_op | 4ts |

| Atmosphere field attribute | Value |
|----------|----------|
| Coupler_in  freq_op | 4ts |
| Coupler_in  freq_offset | 5ts |

| Ice field attribute | Value |
|----------|----------|
| Coupler_in  freq_op | 4ts |
| Coupler_in  freq_offset | 5ts |


## Restarting field attributes

| Ocean field attribute | Value |
|----------|----------|
| file output_freq | 1y (arbitrarily large, so to load one time during the run)|
| freq_offset | 0ts (default in read mode from file)|
| Coupler_out freq_op | 1y (arbitrarily large, so to send one time during the run)|

| Atmosphere field attribute | Value |
|----------|----------|
| Coupler_in freq_op | 1y |
| Coupler_in freq_offset | 1ts (to make it it available at @ts=1 instead of @ts=0)|

| Ice field attribute | Value |
|----------|----------|
| Coupler_in freq_op | 1y |
| Coupler_in freq_offset | 1ts (to make it it available at @ts=1 instead of @ts=0)|


\* arbitrarily large, so to load one time during the run

# Implementation 
The key difference is that we have to specify two `coupler_out` interfaces in the source context. The field ids should be unique for the endpoints (we can't have two fields with the same id in the same context):
```xml
<context id="atm">
  ...

  <coupler_out_definition>

      <coupler_out context="ocn::ocn" >
          <field id="field2D_atm_to_oce" field_ref="field2D_send" freq_op="4ts" expr="@this" />
          <field id="field2D_restart_oce" field_ref="field2D_read" freq_op="1y" />
      </coupler_out>

      <coupler_out context="ice::ice" >
          <field id="field2D_atm_to_ice" field_ref="field2D_send" freq_op="4ts" expr="@this" />
          <field id="field2D_restart_ice" field_ref="field2D_read" freq_op="1y" />
      </coupler_out>

  </coupler_out_definition>

  ...
</context>

<context id="oce">
  ...
  <!-- Fields coming from atmosphere -->
  <coupler_in_definition>
      <coupler_in context="atm::atm" >
          <field id="field2D_atm_to_oce" grid_ref="grid_2D" freq_op="4ts" freq_offset="5ts" operation="instant" read_access="true"/>
          <field id="field2D_restart_oce" grid_ref="grid_2D" freq_op="1y" freq_offset="1ts" operation="instant" read_access="true"/>
      </coupler_in>
  </coupler_in_definition>
   ...
</context>

<context id="ice">

  ...
  <!-- Fields coming from atmosphere -->
  <coupler_in_definition>
      <coupler_in context="atm::atm" >
          <field id="field2D_atm_to_ice" grid_ref="grid_2D" freq_op="4ts" freq_offset="5ts" operation="instant" read_access="true"/>
          <field id="field2D_restart_ice" grid_ref="grid_2D" freq_op="1y" freq_offset="1ts" operation="instant" read_access="true"/>
      </coupler_in>
  </coupler_in_definition>
  ...
</context>
```

# Note 
Users on kraken nodes could experience the program to be hanging when the context closing routine is called. This was solved by adding MPI_Barriers in xios source code at client.cpp and server.cpp. 
The issue does not appear in other systems with the same Intel compiler and MPI versions in the environment, so this remains an open question for why it happens in the kraken clusters.
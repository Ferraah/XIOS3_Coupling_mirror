# Running April and May in one run

Use:
```
./runSingle.sh
```
to perfom a first run of 61 days starting from `2025-04-01`, effectively running the months of April and May. The script will run the usual executable while setting the right `iodef.xml` for this example, and duplicating the old restart file. In fact, even if XIOS cannot append directly to the restart file our last field because it has already opened it, we can open another copy of it and append the new value. Then, we can use this new file as the restart file.

|  | Ocean | Atmosphere|
|----------|----------|----------|
|Start date|Apr 01, 2025|Apr 01, 2025 
| Duration  |  61d       | 61d         |
|Timestep| 6h | 6h
| Coupling freq          | 4ts          | 4ts         |


In iodef_3.xml:
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


### Field values
We have set the values of the field at a certain ts as the number of timesteps between the date at which the field has been sent and the date origin, so that we can make comparison after. 

## Output 
You should check that the target model will receive a field of value `600`, and that the restart file will contain the not yet received value `604` corresponding to the timestep at date interval `2025-05-31 18:00`-`2025-06-01 00:00`
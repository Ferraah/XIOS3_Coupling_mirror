# Running April and May in one run

Use:
```
./runSingle.sh
```
to perfom a first run of 61 days starting from `2025-04-01`, effectively running the months of April and May. The script will run the usual executable while setting the right `iodef.xml` for this example, and duplicating the old restart file. In fact, even if XIOS cannot append directly to the restart file our last field because it has already opened it, we can open another copy of it and append the new value. Then, we can use this new file as the restart file.

iodef_3.xml:
|  | Ocean | Atmosphere|
|----------|----------|----------|
|Start date|Apr 01, 2025|Apr 01, 2025 
| Duration  |  61d       | 61d         |
|Timestep| 6h | 6h
| Coupling freq          | 4ts          | 4ts         |
This translates to:
| freq_op | 4ts| 4ts
| freq_offset | 0ts | 5ts|
| (Restart field) freq_op |  | 1y*
| (Restart field) freq_offset |  | 1ts|
| (Save field) output_freq | 61d | | 

\* arbitrarily large, so to load one time during the run

### Field values
We have set the values of the field at a certain ts as the number of timesteps between the date at which the field has been sent and the date origin, so that we can make comparison after. 
# Running April and May in two runs

Use:
```
./runSingle.sh
```
to perfom a first run of a 61 days starting from `2025-04-01`, effectively running the months of April and May. The script will run the usual executable while setting `iodef.xml` and duplicating the old restart file. In fact, even if XIOS cannot append directly to the restart file our last field because it has already opened it, we can open another copy of it and append the new value. Then, we can use this new file as the restart file. 

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

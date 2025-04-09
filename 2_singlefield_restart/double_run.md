# Running April and May in two runs

Use:
```
./runDouble.sh
```
to perfom a first run of a 30d simulation of the month of April generating a restart file, and use it for running 31d of May. The script will run the usual executable while setting `iodef.xml` and duplicating the old restart file. In fact, even if XIOS cannot append directly to the restart file our last field because it has already opened it, we can open another copy of it and append the new value. Then, we can use this new file as the restart file. 

iodef_1.xml:
|  | Ocean | Atmosphere|
|----------|----------|----------|
|Start date|Apr 01, 2025|Apr 01, 2025 
| Duration  |  30d       | 30d         |
|Timestep| 6h | 6h
| Coupling freq          | 4ts          | 4ts         |
This translates to:
| freq_op | 4ts| 4ts
| freq_offset | 0ts | 5ts|
| (Restart field) freq_op |  | 1y*
| (Restart field) freq_offset |  | 1ts|
| (Save field) output_freq | 30d | | 

\* arbitrarily large, so to load one time during the run

iodef_2.xml:
|  | Ocean | Atmosphere|
|----------|----------|----------|
|Start date|May 01, 2025|May 01, 2025 
| Duration  |  31d       | 31d         |
|Timestep| 6h | 6h
| Coupling freq          | 4ts          | 4ts         |
This translates to:
| freq_op | 4ts| 4ts
| freq_offset | 0ts | 5ts|
| (Restart field) freq_op |  | 1y*
| (Restart field) freq_offset |  | 1ts|
| (Save field) output_freq | 31d | | 

## Comparison
Through `ncdump`, we can see that in the updated restart file the field has been saved at the expected timesteps, i.e. `@ts=0` (the field coming from the retsart file), `@ts=120` the last send of the fisrt run, `@ts=124`(`@ts=224` in absolute time from the first run). After the single run we would see 0 and 224 because we do not save the intermediate restarting value. In conclusion, XIOS can implement a coupling algorithm that is "date" based and for which it can append different field timesteps to an existing restart file.\
@TODO: The timestep between a run and another one should be the same for a restarting file?\
@TODO: On restart XIOS will load the field from the last timestep in the restart file, without performing any "checks" on dates or time informations? 

After `61 days` `./runSingle.sh`, our final restart file will contain the original restaring field and the new one.
```
 field2D_oce_to_atm =
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604 ;
```
After `./runDouble.sh`, our final restart file will contain the original restaring field, the field after `30d`, and finally after `31d`.
```
 field2D_oce_to_atm =
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  480, 480, 480, 480, 480, 480, 480, 480, 480, 480,
  480, 480, 480, 480, 480, 480, 480, 480, 480, 480,
  480, 480, 480, 480, 480, 480, 480, 480, 480, 480,
  480, 480, 480, 480, 480, 480, 480, 480, 480, 480,
  480, 480, 480, 480, 480, 480, 480, 480, 480, 480,
  480, 480, 480, 480, 480, 480, 480, 480, 480, 480,
  480, 480, 480, 480, 480, 480, 480, 480, 480, 480,
  480, 480, 480, 480, 480, 480, 480, 480, 480, 480,
  480, 480, 480, 480, 480, 480, 480, 480, 480, 480,
  480, 480, 480, 480, 480, 480, 480, 480, 480, 480,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604,
  604, 604, 604, 604, 604, 604, 604, 604, 604, 604 ;
```


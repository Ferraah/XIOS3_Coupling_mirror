# Running April and May in two runs

Use:
```
./runDouble.sh
```
to perfom a first run of a 30 days for the month of April, generate a restart file, and use it for running 31 days of May. The script will run the usual executable while setting the `iodef.xml` for each run. 

In iodef_1.xml:
|  | Ocean | Atmosphere|
|----------|----------|----------|
|Start date|Apr 01, 2025|Apr 01, 2025 
| Duration  |  30d       | 30d         |
|Timestep| 6h | 6h
| Coupling freq          | 4ts          | 4ts         |

In iodef_2.xml:
|  | Ocean | Atmosphere|
|----------|----------|----------|
|Start date|May 01, 2025|May 01, 2025 
| Duration  |  31d       | 31d         |
|Timestep| 6h | 6h
| Coupling freq          | 4ts          | 4ts         |




## Comparison
Through `ncdump` we can see that in the updated restart file, the field has been saved and loaded by the `atm` model at the expected timesteps. 
- The first field corresponds to the field in the original restarting file, loaded by the receiver `@ts=1` during the first run. 
- The second field, valued `480`, corresponds to the last send done `@ts=120` during the first run, and loaded `@ts=1` during the second run. 
- The third field, valued `604` corresponds to the last field sent `@ts=124` during the second run.

After `61 days` with `./runSingle.sh`, our final restart file will contain the original restaring field and the new one after 61 days.
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
Note that the second run picks up the value from the restarting file:
```
   ATM: receiving restart field @ts=           1  with value 
   480.000000000000
```
# Important Notes
This example would like to highlight how it would be possible to create a mechanism for stacking up restarting fields in an unique file, indexed by timestamps, so that we can decide which to pick for our next run. In our example we have decided to use the last added field in the nc file, as it was the one corresponding to the previous month.

For this purpose, when loading a field in XIOS, we can specify an offset to individuate the field at a certain timestep. `record_offset`:
```xml
<file id="restart" name="restart" record_offset="1"  enabled="true" type="one_file" output_freq="1y" mode="read">

``` 
### ❌ Indexing by date when loading from file
`record_offset` specifies to load the nth field present in the nc file temporally speaking. 
**Note that there is no functionality to target an explicit date or timestep**. This would be a valuable addition, given the existing date mechanism in XIOS, and it has already been considered for future developments.
### ❌  Picking last field in the file
Another feature would be to be able to pick the last field without knowing the number of fields a priori, as it is the most common task. We have set `record_offset=1` because we knew in advance that there was two fields in the restarting file, but in general it would be better to have something like `record_offset=-1`. This feature was implemented personally in a local XIOS version and showed to be working properly.  

Obviously these problem do not appear if we overwrite the restarting file, as we have only one field from the previous run.

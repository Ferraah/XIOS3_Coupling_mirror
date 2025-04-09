# Monodirectional coupling of a single field with restart file

The folder of this example is composed of a source file of the coupled toy models and 3 `iodef` files corresponding to 3 different available runs. 
## a. Algorithm with restart file introduction
A general introduction to how the restarting algorithm can be implemented in XIOS.
- [intro.md](intro.md)

## b. Single run of April and May 
Using a restart file, we run 61 days of coupling from `2025-04-01 00:00:00` exchanging data every `6h`, and creating a new restart file. 
- [single_run.md](single_run.md)

## c. Double run of April and May
Using a restart file, we firstly run 30 days of coupling from `2025-04-01 00:00:00`, and secondly a run 31 days from `2025-05-01 00:00:00` exchanging data every `6h`, creating (updating, actually) a restart file. 

- [double_run.md](double_run.md)

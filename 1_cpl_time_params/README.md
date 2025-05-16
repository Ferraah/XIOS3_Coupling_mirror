# Monodirectional coupling of a single field with restart file

This folder contains a single source file (representing the two coupled models as always), and four iodef files. These iodef files correspond to four different run configurations, demonstrating the restart coupling scheme and the interoperability between a single continuous run and two consecutive runs.
## a. Algorithm with restart file introduction
A general introduction to the implementation of a coupling algorithm with restarting files in XIOS.
- [intro.md](intro.md)

## b. Single run of April and May 
Using a restart file, we run 61 days of coupling from `2025-04-01 00:00:00` exchanging data every `6h`, and creating a new restart file. 
- [single_run.md](single_run.md)

## c. Double run of April and May
Using a restart file, we firstly run 30 days of coupling from `2025-04-01 00:00:00`, and secondly a run 31 days from `2025-05-01 00:00:00` exchanging data every `6h`, creating (updating, actually) a restart file. 

- [double_run.md](double_run.md)

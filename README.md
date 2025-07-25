# XIOS3 Coupling
The following repository contains a testuite aimed to the evaluation of XIOS3 as a stand-alone coupling software for numerical models, starting from OASIS3 functionalities and explicitly compare the two for an easier transition between the two.
## Toy models
The toy models will generally be contained in a single FORTRAN file in which we implement the behaviour based on the MPI rank who runs them, and generally we have called them `ocn` and `atm`, with the first being the one performing the `put` operations and the latter performing the `get` operations.

In the examples in which we want to highlight the time settings parameters, we have set the sender toymodel field as single valued matrices, in which the value corresponds to the timestep that the toymodel is traversing.

Again, in other examples, the coupled field has been assigned to highlight the domain decomposition between multiple sender toymodels.

## namcouple vs. iodef.xml
A file called iodef.xml is mandatory to init and run XIOS programs. In this file, different parameters are defined to be read at run-time and provide flexibility to the user that can avoid recompiling the code.

In a coupling setting, we could see this file as the equivalent of the namcouple; however, being XIOS not a dedicated coupler software, it will contain many other parameters regarding XIOS behaviour and some adaptations for emulating an interface to set up the coupling functionalities. 

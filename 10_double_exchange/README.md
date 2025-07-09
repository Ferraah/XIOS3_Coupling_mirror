# Bi-directional coupling
In this example, both `ocn` and `atm` are exchanging informations at a certain rate, following the OASIS example:

![bidirectional](./10_double_exchange.png)

The resulting coupling code, in the toymodels and iodef.xml files, turns out to be very "symmetric" between the two contextes, although syntatically heavy. 

Temporally speaking, the behaviour is just like OASIS. The "Oasis date" corresponds to the starting date of the timestep. The "lag" is specified implicitly by offsetting the arrival of the field on the receiving model. 
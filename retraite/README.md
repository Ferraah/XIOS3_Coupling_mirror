Toy model illustrating the difference between using OASIS3-MCT or XIOS as coupler for a very simple copling of one field FSENDOCN sent from ocn and received as FRECVATM by atm.
OASIS3-MCT and XIOS have to be installed somewhere. The makefile_OASIS/makefile_XIOS have to be adapted to use the local OASIS3-MCT/XIOS installation.
To compile and run the toy coupled model with either OASIS3-MCT or XIOS, use runIntro.sh specifying either "OASIS" or "XIOS" for coupler variable, e.g "coupler=OASIS".

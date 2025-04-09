# Monodirectional coupling of a single field with no restart file (Parallel send)

Same scenario as `1_singlefield`, but each process of `ocn` handles irregular patterns of data for which we cannot use `Box` or the `Apple` paradigm. The following approach corresponds to Oasis `Points partition` approach, which can be also generalized to the `Orange` approach. For this example, the data is spread out on two processes as a 4x4 checkboard.

# Modifications
For more details on the attributes `data_*`, refer to the XIOS training slides. We will use this attribute to define how the data that we send to XIOS from both of `ocn` process should be mapped on the local domain. 

```fortran
data_dim = 1 ! Source data is 1D
data_ni = 8 ! Length of data 
data_ibegin = 0 ! Offset of data wrt ibegin
ni = ni_glo ! Local partition size
nj = nj_glo ! Local partition size
ibegin = 0 ! Offset of the local partition wrt the global grid
jbegin = 0 ! Offset of the local partition wrt the global grid

ALLOCATE(data_i_index(data_ni)) ! Indices ao
ALLOCATE(field_send(data_ni))
ALLOCATE(field_recv(4,4))

! Checkboard distribution on two processes, 1D data source
IF (rank==0) THEN
    data_i_index = [(i, i=0, 14, 2)]
    field_send = [(0, i=0, 14, 2)]
ELSE
    data_i_index = [(i, i=1, 15, 2)]
    field_send = [(1, i=1, 15, 2)]
END IF

IF (model_id == "ocn") THEN
    ! Add the local sizes and begin indices to the domain referred in the xml
    CALL xios_set_domain_attr("domain", ni=ni, nj=nj, ibegin=ibegin, jbegin=jbegin, data_ni=data_ni, data_i_index=data_i_index, data_ibegin=data_ibegin, data_dim=1)
    print * , "Model ", model_id, " ni_glo = ", ni_glo, " nj_glo = ", nj_glo, " ni = ", ni, " nj = ", nj, " ibegin = ", ibegin, " jbegin = ", jbegin
END IF 
```
Each process will send a portion of the field, hence we allocate the field as:
```fortran
ALLOCATE(field_send(ni, nj))
```
which will be sent by the process and gathered by XIOS:
```fortran 
CALL xios_send_field("field2D_send", field_send)
```

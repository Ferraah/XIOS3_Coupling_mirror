# Monodirectional coupling of a single field with no restart file (Parallel send)

Same scenario as `1_singlefield`, but the sending of the field is parallelized on multiple instances of `ocn` following the "Apple" paradigm 

# Modifications

During the initialization, we retrieve the size of the field domain defined in the xml file:
```fortran
CALL xios_get_domain_attr("domain", ni_glo=ni_glo, nj_glo=nj_glo)
```
We will use this information to calculate the local size of the field to send by each process. 
```fortran
ni = ni_glo/(size-2) ! Divide by number of ocean processes
nj = nj_glo
ibegin = (rank)*ni
jbegin = 0

IF (model_id == "ocn") THEN
    ! Add the local sizes and begin indices to the domain referred in the xml
    CALL xios_set_domain_attr("domain", ni=ni, nj=nj, ibegin=ibegin, jbegin=jbegin)
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

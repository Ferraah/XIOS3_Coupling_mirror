# Monodirectional coupling of a single field with no restart file (Parallel send)

Same scenario as `1_singlefield`, but the sending of the field is parallelized on multiple instances of `ocn` following the "Box" paradigm. 

# Modifications

Each `ocn` process wil set the right starting point and local sizes of its subfield. In XIOS, OASIS `global_offset` is replaced by `ibegin` & `jbegin`, while `local_extend_x`/`local_extent_y` with `ni`/`nj`

```fortran
! Toymodel field split !!!!!!!!!
INTEGER :: nij(4, 2), begin_points(4, 2)
begin_points(1, :) = [0, 0]
begin_points(2, :) = [24, 0]
begin_points(3, :) = [0, 10]
begin_points(4, :) = [36, 10]

nij(1, :) = [24, 10]
nij(2, :) = [36, 10]
nij(3, :) = [36, 10]
nij(4, :) = [24, 10]
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

ni = nij(rank+1, 1)
nj = nij(rank+1, 2)
ibegin = begin_points(rank+1, 1)
jbegin = begin_points(rank+1, 2)

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

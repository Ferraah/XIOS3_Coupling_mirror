module def_parallel_decomposition
!
! For LR grids, the global grid is split in npes rectangle partitions with local extent in x = global extent
! For U or D grids, the first dimension is split in npes segments
!
contains
   SUBROUTINE def_local_partition (nlon, nlat, npes, mype, cl_type_src, &
  	     		 il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset)
  IMPLICIT NONE
  INTEGER, INTENT(in)  :: nlon, nlat, npes, mype
  CHARACTER(len=2), INTENT(in)   :: cl_type_src
  INTEGER, INTENT(out) :: il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset
  !
  if (cl_type_src == 'LR') then
     il_extentx = nlon
     il_extenty = nlat/npes ; IF (mype == npes-1)  il_extenty = nlat - (nlat/npes * mype)
     il_size = il_extentx * il_extenty
     il_offsetx = 0
     il_offsety = (nlat/npes * mype)
     il_offset = nlon * il_offsety
  else if (cl_type_src == 'U' .or. cl_type_src == 'D') then
     il_extentx = nlon/npes ; IF (mype == npes-1)  il_extentx = nlon - (nlon/npes * mype)
     il_extenty = nlat
     il_size = il_extentx * il_extenty
     il_offsetx = (nlon/npes * mype)
     il_offsety = 0
     il_offset = nlat * il_offsetx
  endif
  ! 
END SUBROUTINE def_local_partition
!

SUBROUTINE def_paral_size (il_paral_size)
  IMPLICIT NONE
  INTEGER, INTENT(out) :: il_paral_size  
  il_paral_size = 3
  ! 
END SUBROUTINE def_paral_size

!
SUBROUTINE def_paral(il_offset, il_size, il_extentx, il_extenty, nlon, il_paral_size, il_paral)
  IMPLICIT NONE
  INTEGER, INTENT(IN) :: il_offset, il_size, il_extentx, il_extenty, nlon, il_paral_size
  INTEGER, INTENT(OUT) :: il_paral(il_paral_size) 
  il_paral(1) = 1
  il_paral(2) = il_offset
  il_paral(3) = il_size
  ! 
END SUBROUTINE def_paral

end module def_parallel_decomposition 

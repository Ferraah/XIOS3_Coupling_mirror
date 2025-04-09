PROGRAM field_generator

  USE XIOS
  IMPLICIT NONE
  INCLUDE "mpif.h"
  INTEGER :: rank
  INTEGER :: size
  INTEGER :: ierr

  INTEGER :: comm
  TYPE(xios_duration) :: dtime

  TYPE(xios_date) :: dorigin
  CHARACTER(len=20) :: dorigin_str

  TYPE(xios_date) :: dstart
  CHARACTER(len=20) :: dstart_str


  CHARACTER(len=20) :: domain_type
  INTEGER :: ni_glo, nj_glo
  
  INTEGER :: i, j
  
  DOUBLE PRECISION, ALLOCATABLE :: field_A(:,:)
 
  INTEGER :: ts
 
  CALL MPI_INIT(ierr)

  CALL xios_initialize("client",return_comm=comm)

  CALL MPI_COMM_RANK(comm,rank,ierr)
  CALL MPI_COMM_SIZE(comm,size,ierr)
  
  print*, "Hello XIOS from proc", rank
  
  CALL xios_context_initialize("test",comm)

  !CALL xios_define_calendar(type="Gregorian") 
  !We define the calendar type in xml

  CALL xios_get_time_origin(dorigin)
  CALL xios_date_convert_to_string(dorigin, dorigin_str)
  if (rank .EQ. 0) print*, "calendar time_origin = ", dorigin_str

  CALL xios_get_start_date(dstart)
  CALL xios_date_convert_to_string(dstart, dstart_str)
  if (rank .EQ. 0) print*, "calendar start_date = ", dstart_str

  dtime%hour = 6
  CALL xios_set_timestep(dtime)

  CALL xios_get_domain_attr("domain", type = domain_type)
  CALL xios_get_domain_attr("domain", ni_glo = ni_glo, nj_glo=nj_glo)
  if(rank.EQ.0) print*, "domain type = ", domain_type
  if(rank.EQ.0) print*, "domain size = ", ni_glo, "*", nj_glo


  CALL xios_close_context_definition()

  ALLOCATE(field_A(ni_glo, nj_glo))

  DO ts=1,1
    field_A = 0
    CALL xios_update_calendar(ts)
    CALL xios_send_field("field_A", field_A)
  ENDDO

  CALL xios_context_finalize()

  DEALLOCATE(field_A)

  !CALL MPI_COMM_FREE(comm, ierr)

  CALL xios_finalize()

  CALL MPI_FINALIZE(ierr)

END PROGRAM field_generator


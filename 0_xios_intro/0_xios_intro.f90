program intro

  use xios
  implicit none
  include "mpif.h"
  integer :: rank
  integer :: size
  integer :: ierr

  integer :: comm

  type(xios_duration) :: dtime ! xios duration object
  type(xios_date) :: dstart, dorigin ! xios date object
  character(len=20) :: dstart_str, dorigin_str ! string representation of the calendar origin and start date
  character(len=20) :: domain_type ! type of the domain (rectangular, curvilinear, etc.)
  integer :: ni_glo, nj_glo ! global size of the domain

  double precision, allocatable :: field_2d_send(:,:) ! model sending field
  double precision, allocatable :: field_2d_recv(:,:) ! model receiving field
 
  integer :: curr_ts, duration_ts, read_freq_ts ! current time step and duration in time steps
  type(xios_duration) :: read_freq ! xios duration object for the read frequency
  character(len=20) :: tmp 

  ! Classic xios initialization

  call mpi_init(ierr)
  call xios_initialize("client",return_comm=comm)
  ! We can get the local rank and size of the model comunicator
  call mpi_comm_rank(comm,rank,ierr)
  call mpi_comm_size(comm,size,ierr)

  ! Initialize the xios context, symbolic name of the context is "test" in iodef
  call xios_context_initialize("test",comm)

  ! Either we define the calendar, origin and start date in the xml file or we do at runtime. 
  ! call xios_define_calendar(type="gregorian") 
  ! ...
  ! ...

  ! Here we do it in iodef, so we extract the values at runtime
  call xios_get_time_origin(dorigin)
  call xios_date_convert_to_string(dorigin, dorigin_str)

  print*, "Calendar time_origin = ", dorigin_str

  call xios_get_start_date(dstart)
  call xios_date_convert_to_string(dstart, dstart_str)
  print*, "calendar start_date = ", dstart_str

  ! Setting the duration of the time step through the xios duration object
  dtime%hour = 6
  call xios_set_timestep(dtime)

  ! We can also get the domain type and size at runtime, or set them at runtime
  call xios_get_domain_attr("domain", type = domain_type)
  call xios_get_domain_attr("domain", ni_glo = ni_glo, nj_glo=nj_glo)

  print*, "domain type = ", domain_type
  print*, "domain size = ", ni_glo, "*", nj_glo

  ! We can retrieve attributes from the xml tags with tha appositte xios_get_*_attr routines.
  call xios_get_file_attr("loaded_file", output_freq = read_freq)
  read_freq_ts = read_freq%timestep ! get the output frequency in time steps  
  print*, "read_freq_ts = ", read_freq_ts

  ! We can also get user defined variables in the xml file. 
  ! with xios_getvar("var_name", var) we can retrieve these values.
  ierr =  xios_getvar("duration_in_ts", duration_ts)
  print*, "duration_in_ts = ", duration_ts

  ! At the end of the context definition, we need to close it.  
  call xios_close_context_definition()
 
  ! This is the field to send to the server to be saved on file.
  ! Sizes should be consistent with the domain size setted before.
  allocate(field_2d_send(ni_glo, nj_glo))
  allocate(field_2d_recv(ni_glo, nj_glo))

  ! RUn the simulation for the duration defined in the xml file
  do curr_ts=1,duration_ts

    field_2d_send = curr_ts ! for example, we can set the field to the current time step
    call xios_update_calendar(curr_ts) ! We set the current time step in the xios calendar 

    call xios_send_field("field_2d_send", field_2d_send) ! We send the field to the server every time step
    print *, "Field sent to server at time step ", curr_ts

    ! Receive the field from the server every read_freq_ts timestep
    if (mod(curr_ts, read_freq_ts) == 1) then
      call xios_recv_field("field_2d_recv", field_2d_recv) ! We send the field to the server
      print *, "Field recv to server at time step ", curr_ts, field_2d_recv(1,1)
    end if

  enddo
  
  ! Close the context and finalize the xios library
  call xios_context_finalize()
  call xios_finalize()
  call mpi_finalize(ierr)

  if(allocated(field_2d_send)) deallocate(field_2d_send)
  if(allocated(field_2d_recv)) deallocate(field_2d_recv)

end program intro 


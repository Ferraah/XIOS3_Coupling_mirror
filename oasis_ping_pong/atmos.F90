program atmos
  use netcdf
  use def_parallel_decomposition
  use mod_oasis
  implicit none
  include 'mpif.h'

  integer :: mype, npes, local_comm, ierror, w_unit, compid
  character(len=128) :: comp_out_atmos
  character(len=3)   :: chout
  integer :: nlon_atmos, nlat_atmos, nc_atmos
  integer :: il_extentx, il_extenty, il_offsetx, il_offsety
  integer :: il_size, il_offset, ig_paral_size, il_part_id, flag
  integer, allocatable :: ig_paral(:)
  double precision, pointer :: grid_lon_atmos(:,:), grid_lat_atmos(:,:)
  double precision, pointer :: grid_clo_atmos(:,:,:), grid_cla_atmos(:,:,:)
  double precision, pointer :: grid_srf_atmos(:,:)
  integer, pointer :: grid_msk_atmos(:,:)
  integer :: ib, il_nb_time_steps, delta_t, itap_sec
  double precision, pointer :: field_recv_atmos(:,:), field_send_atmos(:,:)
  integer :: var_id(2), var_nodims(2), var_actual_shape(1), var_type, info

  ! Parameters
  nlon_atmos = 96
  nlat_atmos = 72
  nc_atmos = 4
  il_nb_time_steps = 8
  delta_t = 1800

  call mpi_init(ierror)
  local_comm = mpi_comm_world

  call oasis_init_comp(compid, 'atmos_component', ierror)
  call oasis_get_localcomm(local_comm, ierror)
  call mpi_comm_size(local_comm, npes, ierror)
  call mpi_comm_rank(local_comm, mype, ierror)

  w_unit = 100 + mype
  write(chout, '(i3)') w_unit
  comp_out_atmos = 'atmos.out_' // chout
  open(w_unit, file=trim(comp_out_atmos), form='formatted')

  print *, '-----------------------------------------------------------'
  print *, 'i am atmos process with rank :', mype
  print *, 'in my local communicator gathering ', npes, 'processes'
  print *, '----------------------------------------------------------'

  ! Partition definition
  call def_local_partition(nlon_atmos, nlat_atmos, npes, mype, &
       il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset)
  print *, 'local partition definition'
  print *, 'il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset = ', &
           il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset

  call def_paral_size(ig_paral_size)
  allocate(ig_paral(ig_paral_size))
  call def_paral(il_offset, il_size, il_extentx, il_extenty, nlon_atmos, ig_paral_size, ig_paral)
  print *, 'ig_paral=', ig_paral(:)
  call oasis_def_partition(il_part_id, ig_paral, ierror)
  deallocate(ig_paral)

  ! Grid definition
  allocate(grid_lon_atmos(il_extentx, il_extenty), stat=ierror)
  allocate(grid_lat_atmos(il_extentx, il_extenty), stat=ierror)
  allocate(grid_clo_atmos(il_extentx, il_extenty, nc_atmos), stat=ierror)
  allocate(grid_cla_atmos(il_extentx, il_extenty, nc_atmos), stat=ierror)
  allocate(grid_srf_atmos(il_extentx, il_extenty), stat=ierror)
  allocate(grid_msk_atmos(il_extentx, il_extenty), stat=ierror)

  ! Local fields
  allocate(field_send_atmos(il_extentx, il_extenty), stat=ierror)
  allocate(field_recv_atmos(il_extentx, il_extenty), stat=ierror)

  var_nodims = 1
  var_actual_shape = 1
  var_type = oasis_real
  call oasis_def_var(var_id(1), 'OCE_TO_ATM_RECV', il_part_id, var_nodims, oasis_in, var_actual_shape, var_type, ierror)
  call oasis_def_var(var_id(2), 'ATM_TO_OCE_SEND', il_part_id, var_nodims, oasis_out, var_actual_shape, var_type, ierror)
  print *, 'var_id frecvatm, var_id fsendatm', var_id(1), var_id(2)

  print *, 'end of initialisation phase'
  call oasis_enddef(ierror)

  print *, 'timestep, field min and max value'
  do ib = 1, il_nb_time_steps
    itap_sec = delta_t * (ib-1)
    field_recv_atmos = -1.0
    call oasis_get(var_id(1), itap_sec, field_recv_atmos, info)
    !print *, itap_sec, minval(field_recv_atmos), maxval(field_recv_atmos)
    field_send_atmos = field_recv_atmos
    call oasis_put(var_id(2), itap_sec, field_send_atmos, info)
  end do

  call oasis_terminate(ierror)
  print *, 'end of the program'
  close(w_unit)
  call mpi_finalize(ierror)
end program atmos

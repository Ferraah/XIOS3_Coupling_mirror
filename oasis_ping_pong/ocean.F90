program ocean
  use netcdf
  use def_parallel_decomposition
  use mod_oasis
  implicit none
  include 'mpif.h'

  integer :: mype, npes
  integer :: local_comm
  character(len=128) :: comp_out_ocean
  character(len=3)   :: chout
  integer :: ierror, w_unit
  integer :: compid

  ! character(len=128), parameter :: grid_file_name = 'grid_all.nc'
  ! character(len=4) :: grid_name = 't12e' 
  ! integer, parameter :: nlon_ocean = 4332, nlat_ocean = 3147
  ! integer, parameter :: nc_ocean = 4


  character(len=128), parameter :: grid_file_name = 'ocean_mesh.nc'
  character(len=4) :: grid_name = 'torc' 
  integer, parameter :: nlon_ocean = 182, nlat_ocean = 149
  integer, parameter :: nc_ocean = 4

  integer :: il_extentx, il_extenty, il_offsetx, il_offsety
  integer :: il_size, il_offset
  integer :: ig_paral_size, il_part_id
  integer :: flag
  integer, dimension(:),allocatable             :: ig_paral
  double precision, dimension(:,:),   pointer   :: grid_lon_ocean, grid_lat_ocean
  double precision, dimension(:,:,:), pointer   :: grid_clo_ocean, grid_cla_ocean
  double precision, dimension(:,:),   pointer   :: grid_srf_ocean
  integer, dimension(:,:),            pointer   :: grid_msk_ocean

  integer               ::  ib
  integer, parameter    ::  il_nb_time_steps = 4
  integer, parameter    ::  delta_t = 3600
  integer               ::  itap_sec

  double precision, pointer :: field_recv_ocean(:,:)
  double precision, pointer :: field_send_ocean(:,:)

  integer :: var_id(2)
  integer :: var_nodims(2)
  integer :: var_actual_shape(1)
  integer :: var_type
  integer :: info

  double precision :: start_time, end_time

  call mpi_init(ierror)
  if (ierror /= mpi_success) then
    print *, 'Error: mpi_init failed with error code', ierror
    call mpi_abort(mpi_comm_world, ierror, ierror)
  endif

  local_comm =  mpi_comm_world

  call oasis_init_comp(compid, 'ocean_component',ierror)
  call oasis_get_localcomm(local_comm, ierror)
  call mpi_comm_size ( local_comm, npes, ierror )
  call mpi_comm_rank ( local_comm, mype, ierror )

  w_unit = 100 + mype
  write(chout,'(i3)') w_unit
  comp_out_ocean='ocean.out_'//chout

  print *, '-----------------------------------------------------------'
  print *, 'I am ocean process with rank :',mype
  print *, 'in my local communicator gathering ', npes, 'processes'
  print *, '----------------------------------------------------------'

  call def_local_partition(nlon_ocean, nlat_ocean, npes, mype, &
            il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset)
  print *, 'Local partition definition'
  print *, 'il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset = ', &
                   il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset

  call def_paral_size(ig_paral_size)
  allocate(ig_paral(ig_paral_size))
  call def_paral(il_offset,il_size,il_extentx, il_extenty,nlon_ocean,ig_paral_size,ig_paral)
  print *, 'ig_paral = ',ig_paral(:)
  call oasis_def_partition (il_part_id,ig_paral,ierror)
  deallocate (ig_paral)

  allocate(grid_lon_ocean(il_extentx, il_extenty), stat=ierror )
  allocate(grid_lat_ocean(il_extentx, il_extenty), stat=ierror )
  allocate(grid_clo_ocean(il_extentx, il_extenty, nc_ocean), stat=ierror )
  allocate(grid_cla_ocean(il_extentx, il_extenty, nc_ocean), stat=ierror )
  allocate(grid_srf_ocean(il_extentx, il_extenty), stat=ierror )
  allocate(grid_msk_ocean(il_extentx, il_extenty), stat=ierror )

  call read_grid(nlon_ocean, nlat_ocean, nc_ocean, il_offsetx+1, il_offsety+1, il_extentx, il_extenty, &
                grid_file_name, w_unit, grid_lon_ocean, grid_lat_ocean, grid_clo_ocean, &
                grid_cla_ocean, grid_srf_ocean, grid_msk_ocean)

  call oasis_start_grids_writing(flag)
  call oasis_write_grid(grid_name,nlon_ocean,nlat_ocean,grid_lon_ocean,grid_lat_ocean,il_part_id)
  call oasis_write_corner(grid_name,nlon_ocean, nlat_ocean,4, grid_clo_ocean,grid_cla_ocean,il_part_id)
  call oasis_write_mask(grid_name,nlon_ocean,nlat_ocean,grid_msk_ocean(:,:),il_part_id)
  call oasis_terminate_grids_writing()
  print *, 'grid_lat ocean max and min',maxval(grid_lat_ocean),minval(grid_lat_ocean)

  allocate(field_send_ocean(il_extentx, il_extenty), stat=ierror )
  allocate(field_recv_ocean(il_extentx, il_extenty), stat=ierror )

  var_nodims(1)=1
  var_nodims(2)=1
  var_actual_shape(1)=1
  var_type=oasis_real

  call oasis_def_var(var_id(1), 'ATM_TO_OCE_RECV', il_part_id,var_nodims, oasis_in, var_actual_shape, var_type,ierror)
  call oasis_def_var(var_id(2), 'OCE_TO_ATM_SEND', il_part_id,var_nodims, oasis_out, var_actual_shape, var_type,ierror)
  print *, 'var_id FRECVOCN, var_id FSENDOCN', var_id(1), var_id(2)

  print *, 'End of initialisation phase'

  call oasis_enddef(ierror)

  print *, 'Timestep, field min and max value'
  do ib = 1,il_nb_time_steps
    itap_sec = delta_t * (ib-1)
    field_recv_ocean=-1.0
    field_send_ocean(:,:) =  100 
    start_time = mpi_wtime()
    call oasis_put(var_id(2),itap_sec,field_send_ocean,info)
    call oasis_get(var_id(1),itap_sec,field_recv_ocean,info)
    end_time = mpi_wtime()
    print *, itap_sec, minval(field_recv_ocean), maxval(field_recv_ocean), &
           'Time taken for put/get operation:', end_time - start_time
  enddo

  call oasis_terminate(ierror)

  print *, 'End of the program'
  call mpi_finalize(ierror)
end program ocean

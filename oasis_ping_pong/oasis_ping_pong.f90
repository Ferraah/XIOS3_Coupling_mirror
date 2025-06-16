program ocean
    use netcdf
    use def_parallel_decomposition
    use mod_oasis
    implicit none
    include 'mpif.h'

    integer :: rank, size, local_rank, local_size
    integer :: local_comm
    character(len=128) :: comp_out_ocean
    character(len=255) :: model_id
    character(len=255) :: mesh_file
    character(len=4) :: grid_name 
    character(len=3)   :: chout
    integer :: ierror, w_unit
    integer :: compid

    integer :: nlon, nlat 
    integer :: nc 

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
    double precision, parameter    :: pi=3.14159265359
    double precision, parameter    :: dp_length= 1.2*pi

    double precision, pointer :: field_recv(:,:)
    double precision, pointer :: field_send(:,:)

    integer :: var_id(2)
    integer :: var_nodims(2)
    integer :: var_actual_shape(1)
    integer :: var_type
    integer :: info

    call mpi_init(ierror)
    if (ierror /= mpi_success) then
        print *, 'Error: mpi_init failed with error code', ierror
        call mpi_abort(mpi_comm_world, ierror, ierror)
    endif

    local_comm =  mpi_comm_world

    call oasis_init_comp(compid, 'ocean_component',ierror)
    call oasis_get_localcomm(local_comm, ierror)
    call mpi_comm_size ( mpi_comm_world, size, ierror )
    call mpi_comm_rank ( mpi_comm_world, rank, ierror )
    local_rank = 0
    local_size = 1

    if (rank == 0) then
        model_id = "ocn"
        mesh_file = 'ocean_mesh.nc'
        grid_name = 'torc'
        nlon = 182
        nlat = 149
        nc = 4
    else
        model_id = "atm"
        mesh_file = 'atmos_mesh.nc'
        grid_name = 'lmdz'
        nlon = 96
        nlat = 72
        nc = 4
    end if 

    print *, '-----------------------------------------------------------'
    print *, 'I am ocean process with rank :',rank
    print *, '----------------------------------------------------------'

    call def_local_partition(nlon, nlat, local_size, local_rank, &
                il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset)
    print *, 'Local partition definition'
    print *, 'il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset = ', &
                    il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset

    call def_paral_size(ig_paral_size)
    allocate(ig_paral(ig_paral_size))
    call def_paral(il_offset,il_size,il_extentx, il_extenty,nlon,ig_paral_size,ig_paral)
    print *, 'ig_paral = ',ig_paral(:)
    call oasis_def_partition (il_part_id,ig_paral,ierror)
    deallocate (ig_paral)

    allocate(grid_lon_ocean(il_extentx, il_extenty), stat=ierror )
    allocate(grid_lat_ocean(il_extentx, il_extenty), stat=ierror )
    allocate(grid_clo_ocean(il_extentx, il_extenty, nc), stat=ierror )
    allocate(grid_cla_ocean(il_extentx, il_extenty, nc), stat=ierror )
    allocate(grid_srf_ocean(il_extentx, il_extenty), stat=ierror )
    allocate(grid_msk_ocean(il_extentx, il_extenty), stat=ierror )

    call read_grid(nlon, nlat, nc, il_offsetx+1, il_offsety+1, il_extentx, il_extenty, &
                    TRIM(mesh_file), w_unit, grid_lon_ocean, grid_lat_ocean, grid_clo_ocean, &
                    grid_cla_ocean, grid_srf_ocean, grid_msk_ocean)

    call oasis_start_grids_writing(flag)
    call oasis_write_grid(grid_name,nlon,nlat,grid_lon_ocean,grid_lat_ocean,il_part_id)
    call oasis_write_corner(grid_name,nlon, nlat,4, grid_clo_ocean,grid_cla_ocean,il_part_id)
    call oasis_write_mask(grid_name,nlon,nlat,grid_msk_ocean(:,:),il_part_id)
    call oasis_terminate_grids_writing()
    print *, 'grid_lat ocean max and min',maxval(grid_lat_ocean),minval(grid_lat_ocean)

    allocate(field_send(il_extentx, il_extenty), stat=ierror )
    allocate(field_recv(il_extentx, il_extenty), stat=ierror )

    var_nodims(1)=1
    var_nodims(2)=1
    var_actual_shape(1)=1
    var_type=oasis_real
    
    if (model_id == "ocn") then
        call oasis_def_var(var_id(1), 'ATM_TO_OCE_RECV', il_part_id,var_nodims, oasis_in, var_actual_shape, var_type,ierror)
        call oasis_def_var(var_id(2), 'OCE_TO_ATM_SEND', il_part_id,var_nodims, oasis_out, var_actual_shape, var_type,ierror)
        print *, 'var_id FRECVOCN, var_id FSENDOCN', var_id(1), var_id(2)
    else if (model_id == "atm") then
        call oasis_def_var(var_id(1), 'OCE_TO_ATM_RECV', il_part_id, var_nodims, oasis_in, var_actual_shape, var_type, ierror)
        call oasis_def_var(var_id(2), 'ATM_TO_OCE_SEND', il_part_id, var_nodims, oasis_out, var_actual_shape, var_type, ierror)
        print *, 'var_id frecvatm, var_id fsendatm', var_id(1), var_id(2)
    end if


    call oasis_enddef(ierror)
    print *, 'End of initialisation phase'


    print *, 'Timestep, field min and max value'

    do ib = 1,il_nb_time_steps
        itap_sec = delta_t * (ib-1)
        field_recv=-1.0
        field_send(:,:) =  100 
        if (model_id == "ocn") then 
            call oasis_put(var_id(2),itap_sec,field_send,info)
            call oasis_get(var_id(1),itap_sec,field_recv,info)
            print *, itap_sec, minval(field_recv),maxval(field_recv)
            print *, 'ocean: Value ping-pong field_recv at time ', itap_sec, ' is ', field_recv(100,100)
        else if (model_id == "atm") then
            call oasis_get(var_id(1), itap_sec, field_recv, info)
            print *, itap_sec, minval(field_recv), maxval(field_recv)
            print *, 'atmos: value recv at time ', itap_sec, ' is ', field_recv(1, 6)
            field_send = field_recv
            call oasis_put(var_id(2), itap_sec, field_send, info)
        end if 
    enddo

    call oasis_terminate(ierror)
    print *, 'End of the program'
    call mpi_finalize(ierror)
end program ocean

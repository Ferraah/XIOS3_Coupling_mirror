program oasis_ping_pong 
    use netcdf
    use def_parallel_decomposition
    use mod_oasis
    implicit none
    include 'mpif.h'

    integer :: mpi_rank, mpi_size, local_comm, ierror, w_unit, compid
    character(len=128) :: comp_out
    character(len=3)   :: chout
    integer :: nlon, nlat, nc
    integer :: il_extentx, il_extenty, il_offsetx, il_offsety
    integer :: il_size, il_offset, ig_paral_size, il_part_id, flag
    integer, allocatable :: ig_paral(:)
    double precision, pointer :: grid_lon(:,:), grid_lat(:,:)
    double precision, pointer :: grid_clo(:,:,:), grid_cla(:,:,:)
    double precision, pointer :: grid_srf(:,:)
    integer, pointer :: grid_msk(:,:)
    integer :: ib, il_nb_time_steps, delta_t, itap_sec
    double precision, pointer :: field_recv(:,:), field_send(:,:)
    integer :: var_id(2), var_nodims(2), var_actual_shape(1), var_type, info
    character(len=128) :: model_id 

    double precision :: start_time, end_time

    character(len=128) :: grid_file_name = 'grids.nc'
    character(len=128) :: grid_name 
    character(len=2) :: grid_type
    integer :: argc
    character(len=128) :: arg

    il_nb_time_steps = 100
    delta_t = 1

    ! Get model_id, grid_name, and grid_type from command line arguments if provided
    argc = command_argument_count()
    if (argc >= 1) then
        call get_command_argument(1, arg)
        model_id = trim(arg)
        if (model_id /= "ocean_component" .and. model_id /= "atmos_component") then
            print *, "Error: model_id must be either 'ocean_component' or 'atmos_component'."
            call MPI_FINALIZE(ierror)
            stop
        end if
    end if


    if (model_id == 'ocean_component') then
        grid_name = 't12e'
        grid_type = 'LR'
    else if (model_id == 'atmos_component') then
        grid_name = 'icoh'
        grid_type = 'U'
    end if

    ! Overwrite defaults high res grids with argv
    if (argc >= 2) then
        call get_command_argument(2, arg)
        grid_name = trim(arg)
    end if

    if (argc >= 3) then
        call get_command_argument(3, arg)
        grid_type = trim(arg)
    end if




    call mpi_init(ierror)
    local_comm = mpi_comm_world
    call oasis_init_comp(compid, model_id, ierror)
    call oasis_get_localcomm(local_comm, ierror)
    call mpi_comm_size(local_comm, mpi_size, ierror)
    call mpi_comm_rank(local_comm, mpi_rank, ierror)

    print *, '-----------------------------------------------------------'
    print *, 'i am atmos process with rank :', mpi_rank
    print *, 'in my local communicator gathering ', mpi_size, 'processes'
    print *, '----------------------------------------------------------'

    if (mpi_rank == 0) then
        write(*,*) 'Grid name:', grid_name
        write(*,*) 'Grid type:', grid_type
    end if


    call read_xy_dimensions(grid_file_name, grid_name, nlon, nlat, nc)

    ! Partition definition
    call def_local_partition(nlon, nlat, mpi_size, mpi_rank, grid_type, &
        il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset)
    print *, 'local partition definition'
    print *, 'il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset = ', &
            il_extentx, il_extenty, il_size, il_offsetx, il_offsety, il_offset

    call def_paral_size(ig_paral_size)
    allocate(ig_paral(ig_paral_size))
    call def_paral(il_offset, il_size, il_extentx, il_extenty, nlon, ig_paral_size, ig_paral)
    print *, 'ig_paral=', ig_paral(:)
    call oasis_def_partition(il_part_id, ig_paral, ierror)
    deallocate(ig_paral)

    ! Grid definition
    allocate(grid_lon(il_extentx, il_extenty), stat=ierror)
    allocate(grid_lat(il_extentx, il_extenty), stat=ierror)
    allocate(grid_clo(il_extentx, il_extenty, nc), stat=ierror)
    allocate(grid_cla(il_extentx, il_extenty, nc), stat=ierror)
    allocate(grid_srf(il_extentx, il_extenty), stat=ierror)
    allocate(grid_msk(il_extentx, il_extenty), stat=ierror)

    ! Local fields
    allocate(field_send(il_extentx, il_extenty), stat=ierror)
    allocate(field_recv(il_extentx, il_extenty), stat=ierror)

    var_nodims = 1
    var_actual_shape = 1
    var_type = oasis_real

    if (model_id == 'ocean_component') then
        call oasis_def_var(var_id(1), 'ATM_TO_OCE_RECV', il_part_id, var_nodims, oasis_in, var_actual_shape, var_type, ierror)
        call oasis_def_var(var_id(2), 'OCE_TO_ATM_SEND', il_part_id, var_nodims, oasis_out, var_actual_shape, var_type, ierror)
    else if (model_id == 'atmos_component') then
        call oasis_def_var(var_id(1), 'OCE_TO_ATM_RECV', il_part_id, var_nodims, oasis_in, var_actual_shape, var_type, ierror)
        call oasis_def_var(var_id(2), 'ATM_TO_OCE_SEND', il_part_id, var_nodims, oasis_out, var_actual_shape, var_type, ierror)
    end if

    print *, 'var_id frecvatm, var_id fsendatm', var_id(1), var_id(2)

    print *, 'end of initialisation phase'
    call oasis_enddef(ierror)

    print *, 'timestep, field min and max value'
    do ib = 1, il_nb_time_steps
        itap_sec = delta_t * (ib-1)
        if (model_id == 'ocean_component') then
            field_send = mpi_rank + 1.0
            call MPI_Barrier(local_comm, ierror)
            start_time = mpi_wtime()
            call oasis_put(var_id(2), itap_sec, field_send, info)
            call oasis_get(var_id(1), itap_sec, field_recv, info)
            call MPI_Barrier(local_comm, ierror)
            end_time = mpi_wtime()
            if (mpi_rank == 0) print *, 'TIMING:', end_time - start_time

        else if (model_id == 'atmos_component') then
            call oasis_get(var_id(1), itap_sec, field_recv, info)
            field_send = field_recv
            call oasis_put(var_id(2), itap_sec, field_send, info)
        end if
    end do

    call oasis_terminate(ierror)
    print *, 'end of the program'
    close(w_unit)
    call mpi_finalize(ierror)
end program oasis_ping_pong 

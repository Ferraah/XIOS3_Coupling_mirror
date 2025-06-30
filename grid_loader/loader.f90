program loader
    use xios
    use netcdf
    use grids_utils

    implicit none
    integer :: ierr, rank, size, local_comm
    type(xios_context) :: ctx
    type(field_description) :: field_desc_orig, field_desc_interp
    type(coupling_config) :: config_orig, config_interp

    double precision, allocatable :: field_send(:,:)

    character(len=255) :: model_id = "grid_loader_tests"

    call mpi_init(ierr)
    call mpi_comm_size(MPI_COMM_WORLD, size, ierr)
    call mpi_comm_rank(MPI_COMM_WORLD, rank, ierr)

    ! Standard XIOS initialization
    call xios_initialize(model_id, return_comm = local_comm)
    call xios_context_initialize(model_id, local_comm)
    call xios_get_handle(model_id, ctx)
    call xios_set_current_context(ctx)
    call xios_set_timestep(xios_duration_convert_from_string("1h"))
    ! --------------------------------------------

    ! Files names for retrieving grids, masks and areas
    ierr = xios_getvar("grids_filename", config_orig%grids_filename)
    call handle_xioserr(ierr, "Error in xios_getvar for grids_filename")
    print *, "Grids filename: ", TRIM(config_orig%grids_filename)


    ierr = xios_getvar("masks_filename", config_orig%masks_filename)
    call handle_xioserr(ierr, "Error in xios_getvar for masks_filename")
    print *, "Masks filename: ", TRIM(config_orig%masks_filename) 

    ! Same file for now
    config_interp = config_orig

    
    ierr = xios_getvar("domain_orig", config_orig%domain)
    call handle_xioserr(ierr, "Error in xios_getvar for domain_name")
    print *, "Domain name: ", TRIM(config_orig%domain)

    ierr = xios_getvar("domain_interp", config_interp%domain)
    call handle_xioserr(ierr, "Error in xios_getvar for domain_name")
    print *, "Domain name: ", TRIM(config_interp%domain)


    call init_domain(local_comm, "domain_orig", config_orig, config_orig%domain, field_desc_orig)
    call init_domain(local_comm, "domain_interp", config_interp, config_interp%domain, field_desc_interp)

    call xios_close_context_definition()

    call xios_update_calendar(1)

    allocate(field_send(field_desc_orig%ni, field_desc_orig%nj))
    if(rank == 0) print *, "Rank and orig size: ", rank, field_desc_orig%ni, field_desc_orig%nj
    if(rank == 0) print *, "Rank and interp size: ", rank, field_desc_interp%ni, field_desc_interp%nj

    field_send = rank + 1
    call xios_send_field("field_send", field_send)

    if (allocated(field_send)) deallocate(field_send)

    call xios_context_finalize()
    call xios_finalize()


end program loader
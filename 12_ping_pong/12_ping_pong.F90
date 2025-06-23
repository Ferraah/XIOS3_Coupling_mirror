program basic_couple
    use xios
    use netcdf
    use grids_utils
    use field_initializer    

    implicit none


    integer :: ierr, provided
    integer :: rank, size
    character(len=255) :: model_id

        ! Mpi initialization
    call MPI_INIT_THREAD(MPI_THREAD_MULTIPLE, provided, ierr)
    if (provided < MPI_THREAD_MULTIPLE) then
        print *, "The MPI library does not provide the required level of thread support."
        call MPI_FINALIZE(ierr)
        stop
    end if
    call MPI_COMM_SIZE(MPI_COMM_WORLD, size, ierr)
    call MPI_COMM_RANK(MPI_COMM_WORLD, rank, ierr)

    ! if (size < 3) then
    !     print *, "This program must be run with at least 3 processes. Currently, there are ", size, " processes."
    !     call MPI_FINALIZE(ierr)
    !     stop
    ! end if 
    ! -------------------------------

    if (rank==0) then
        model_id = "oce"
        call run_toymodel()
    else if (rank==1) then
        model_id = "atm"
        call run_toymodel()
    else
        call xios_init_server()
    endif

    call MPI_FINALIZE(ierr)

contains

    subroutine run_toymodel()
    implicit none
        integer :: local_comm
        type(xios_context) :: ctx
        type(coupling_config) :: conf
        type(field_description) :: field_desc
        integer :: size2, ierr2

        ! Standard XIOS initialization
        call xios_initialize(model_id, return_comm = local_comm)
        call xios_context_initialize(model_id, local_comm)
        call xios_get_handle(model_id, ctx)
        call xios_set_current_context(ctx)
        ! --------------------------------------------

        ! Loading the configuration of the toy model
        call load_coupling_conf(conf) 

        ! Set the data coming from the model in XIOS
        call configure_xios_from_model(local_comm, conf, field_desc)

        ! Run the coupling
        call run_coupling(conf, field_desc)

        ! --------------------------------------------
        call xios_context_finalize()
        call xios_finalize()


    end subroutine run_toymodel

    
    subroutine load_coupling_conf(config)
        implicit none
        type(coupling_config), intent(out) :: config
        character(len=255) :: tmp = ""
        type(xios_duration) :: tmp2

        ierr = xios_getvar("toymodel_duration", tmp)
        print *, "Duration: ", TRIM(tmp)
        config%duration = xios_duration_convert_from_string(TRIM(tmp))
        tmp = ""

        ierr = xios_getvar("toymodel_timestep_duration", tmp)
        print *, "Timestep duration: ", TRIM(tmp)
        config%timestep = xios_duration_convert_from_string(TRIM(tmp))
        tmp = ""

        ! Files names for retrieving grids, masks and areas
        ierr = xios_getvar("toymodel_grids_filename", config%grids_filename)
        call handle_xioserr(ierr, "Error in xios_getvar for grids_filename")
        print *, "Grids filename: ", TRIM(config%grids_filename)

        ierr = xios_getvar("toymodel_domain_name", config%domain)
        call handle_xioserr(ierr, "Error in xios_getvar for domain_name")
        print *, "Domain name: ", TRIM(config%domain)

        ierr = xios_getvar("toymodel_masks_filename", config%masks_filename)
        call handle_xioserr(ierr, "Error in xios_getvar for masks_filename")
        print *, "Masks filename: ", TRIM(config%masks_filename)

        ierr = xios_getvar("toymodel_areas_filename", config%areas_filename)
        call handle_xioserr(ierr, "Error in xios_getvar for areas_filename")
        print *, "Areas filename: ", TRIM(config%areas_filename)

        ! Getting the frequency of the operation
        CALL xios_get_field_attr("atm_to_oce", freq_op=tmp2)
        CALL xios_duration_convert_to_string(tmp2, tmp)
        ! Remove the last two characters from the string to retrieve the pure number "(xx)ts"
        tmp = tmp(1:LEN_TRIM(tmp)-2)
        ! Convert to integer
        READ(tmp, *) config%freq_op_in_ts
        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        call xios_get_start_date(config%start_date)
    end subroutine load_coupling_conf

    subroutine configure_xios_from_model(local_comm, config, field_desc)
    implicit none
        integer, intent(in) :: local_comm
        type(coupling_config), intent(in) :: config
        type(field_description), intent(out) :: field_desc

        call xios_set_timestep(config%timestep)

        if (model_id=="oce") then
            call init_domain(local_comm, "domain_oce", config, config%domain, field_desc)
        else if ( model_id=="atm")then
            call init_domain(local_comm, "domain_atm", config, config%domain, field_desc)
        end if
        
        call xios_close_context_definition()

    end subroutine configure_xios_from_model

    subroutine run_coupling(config, field_desc)
    implicit none 
        type(coupling_config), intent(inout):: config 
        type(field_description), intent(in) :: field_desc
        double precision, allocatable:: field_send_original(:,:), field_send(:,:), field_recv(:,:)
        integer :: curr_timestep

        allocate(field_send(field_desc%ni, field_desc%nj))
        allocate(field_recv(field_desc%ni, field_desc%nj))

        ! if(model_id == "oce") call init_field2d_gulfstream(field_desc%ni_glo, field_desc%nj_glo, field_desc%lon, field_desc%lat, field_desc%mask, field_send_original)
        field_send = 1.0d0

        config%end_date = config%start_date + config%duration
        config%curr_date = config%start_date
        curr_timestep = 1

        print *, "Start date: ", config%start_date
        print *, "End date: ", config%end_date

        do while (config%curr_date < config%end_date)

            call xios_update_calendar(curr_timestep)

            if (model_id=="oce") then
                field_send = curr_timestep * field_send_original
                call xios_send_field("field2D_send", field_send)
                print *, "SRC: sending field @ts=", curr_timestep, " with value ", field_send(1,1)
            else if (model_id=="atm") then
                call xios_recv_field("field2D_recv", field_recv)
                print *, "  DST: receiving field @ts=", curr_timestep, " with value ", field_recv(1,1)
            end if

            config%curr_date = config%curr_date + config%timestep
            curr_timestep = curr_timestep + 1
        end do

        if(allocated(field_send)) deallocate(field_send)
        if(allocated(field_recv)) deallocate(field_recv)
    end subroutine  run_coupling 
end program
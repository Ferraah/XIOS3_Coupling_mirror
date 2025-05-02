program basic_couple
    use xios
    use netcdf
    use grids_utils
    
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

    if (size < 3) then
        print *, "This program must be run with at least 3 processes. Currently, there are ", size, " processes."
        call MPI_FINALIZE(ierr)
        stop
    end if 
    ! -------------------------------

    if(rank==0) then
        call xios_init_server()
    else if (rank==1) then
        model_id = "atm"
        call run_toymodel()
    else if (rank==2) then
        model_id = "ocn"
        call run_toymodel()
    end if

    call MPI_FINALIZE(ierr)

contains

    subroutine run_toymodel()
    implicit none
        integer :: local_comm
        type(xios_context) :: ctx
        type(coupling_config) :: conf
        type(field_description) :: src_fd, dst_fd
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
        call configure_xios_from_model(local_comm, conf, src_fd, dst_fd)

        ! Run the coupling
        call run_coupling(conf, src_fd, dst_fd)

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

        ierr = xios_getvar("toymodel_src_domain_name", config%src_domain)
        call handle_xioserr(ierr, "Error in xios_getvar for domain_name")
        print *, "Domain name: ", TRIM(config%src_domain)

        ierr = xios_getvar("toymodel_dst_domain_name", config%dst_domain)
        call handle_xioserr(ierr, "Error in xios_getvar for domain_name")
        print *, "Domain name: ", TRIM(config%dst_domain)

        ierr = xios_getvar("toymodel_masks_filename", config%masks_filename)
        call handle_xioserr(ierr, "Error in xios_getvar for masks_filename")
        print *, "Masks filename: ", TRIM(config%masks_filename)

        ierr = xios_getvar("toymodel_areas_filename", config%areas_filename)
        call handle_xioserr(ierr, "Error in xios_getvar for areas_filename")
        print *, "Areas filename: ", TRIM(config%areas_filename)

        ! Getting the frequency of the operation
        CALL xios_get_field_attr("field2D_oce_to_atm", freq_op=tmp2)
        CALL xios_duration_convert_to_string(tmp2, tmp)
        ! Remove the last two characters from the string to retrieve the pure number "(xx)ts"
        tmp = tmp(1:LEN_TRIM(tmp)-2)
        ! Convert to integer
        READ(tmp, *) config%freq_op_in_ts
        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        call xios_get_start_date(config%start_date)
    end subroutine load_coupling_conf

    subroutine configure_xios_from_model(local_comm, config, src_fd, dst_fd)
    implicit none
        integer, intent(in) :: local_comm
        type(coupling_config), intent(in) :: config
        type(field_description), intent(out) :: src_fd
        type(field_description), intent(out) :: dst_fd
        call xios_set_timestep(config%timestep)

        if (model_id=="ocn") then
            call init_domain_src(local_comm, "domain_oce_src", config, src_fd)
        else if (model_id=="atm") then
            call init_domain_src(local_comm, "domain_oce_dst", config, src_fd)
            call init_domain_dst(local_comm, "domain_interp", config, dst_fd)
        end if

        
        if (model_id=="atm") then
            print *, "Source field for model_id: ", model_id, " and rank: ", rank
            print *, "ni_glo: ", src_fd%ni_glo
            print *, "nj_glo: ", src_fd%nj_glo
            print *, "ni: ", src_fd%ni
            print *, "nj: ", src_fd%nj
            print *, "ibegin: ", src_fd%ibegin
            print *, "jbegin: ", src_fd%jbegin

            print *, "Dest field for model_id: ", model_id, " and rank: ", rank
            print *, "ni_glo: ", dst_fd%ni_glo
            print *, "nj_glo: ", dst_fd%nj_glo
            print *, "ni: ", dst_fd%ni
            print *, "nj: ", dst_fd%nj
            print *, "ibegin: ", dst_fd%ibegin
            print *, "jbegin: ", dst_fd%jbegin
        end if
        
        call xios_close_context_definition()

    end subroutine configure_xios_from_model

    subroutine run_coupling(config, src_fd, dst_fd)
    implicit none 
        type(coupling_config) :: config 
        type(field_description) :: src_fd, dst_fd 
        double precision, pointer:: field_send(:,:), field_recv(:,:)
        integer :: curr_timestep
        double precision :: error

        if(model_id=="ocn") allocate(field_send(src_fd%ni, src_fd%nj))
        if(model_id=="atm") allocate(field_recv(dst_fd%ni_glo, dst_fd%nj_glo), field_send(src_fd%ni_glo, src_fd%nj_glo))

        config%end_date = config%start_date + config%duration
        config%curr_date = config%start_date
        curr_timestep = 1

        print *, "Start date: ", config%start_date
        print *, "End date: ", config%end_date

        do while (config%curr_date < config%end_date)

            call xios_update_calendar(curr_timestep)

            field_send = curr_timestep

            if (model_id=="ocn") then
                call xios_send_field("field2D_send", field_send)
                print *, "OCN: sending field @ts=", curr_timestep, " with value ", field_send(1,1)
            else if (model_id=="atm") then
                if (mod(curr_timestep-1, config%freq_op_in_ts) == 0) then
                    call xios_recv_field("field2D_recv", field_recv)
                    error = abs(field_recv(1,1) - field_send(1,1))
                    print *, "  ATM: absolute difference @ts=", curr_timestep, " is " , error
                    print *, "  ATM: receiving field @ts=", curr_timestep, " with value ", field_recv(1,1)
                end if
            end if

            config%curr_date = config%curr_date + config%timestep
            curr_timestep = curr_timestep + 1
        end do

        if(associated(field_send)) deallocate(field_send)
        if(associated(field_recv)) deallocate(field_recv)
        
    end subroutine  run_coupling 
end program
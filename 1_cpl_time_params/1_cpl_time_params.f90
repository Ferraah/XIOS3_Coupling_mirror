program basic_couple
    use xios
    implicit none
    include "mpif.h"

    integer :: ierr, provided
    integer :: rank, size
    character(len=255) :: model_id

    type :: toymodel_config
        type(xios_date) :: start_date, end_date, curr_date
        type(xios_duration) :: timestep, duration
        integer :: freq_op_in_ts
        integer :: ni_glo, nj_glo
        character(len=255) :: field_type
    end type toymodel_config

    ! Mpi initialization
    call MPI_INIT_THREAD(MPI_THREAD_MULTIPLE, provided, ierr)
    if (provided < MPI_THREAD_MULTIPLE) then
        print *, "The MPI library does not provide the required level of thread support."
        call MPI_FINALIZE(ierr)
        stop
    end if
    call MPI_COMM_SIZE(MPI_COMM_WORLD, size, ierr)
    call MPI_COMM_RANK(MPI_COMM_WORLD, rank, ierr)

    if (size /= 3) then
        print *, "This program must be run with 3 processes. Currently, there are ", size, " processes."
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
        type(toymodel_config) :: config
        
        ! Standard XIOS initialization
        call xios_initialize(model_id, return_comm = local_comm)
        call xios_context_initialize(model_id, local_comm)
        call xios_get_handle(model_id, ctx)
        call xios_set_current_context(ctx)

        ! --------------------------------------------

        ! Loading the configuration of the toy model
        call load_toymodel_data(config) 

        ! Set the data coming from the model in XIOS
        call configure_xios_from_model(config)

        ! Run the coupling
        call run_coupling(config)

        ! --------------------------------------------
        call xios_context_finalize()
        call xios_finalize()


    end subroutine run_toymodel

    
    subroutine load_toymodel_data(config)
        implicit none
        type(toymodel_config), intent(out) :: config
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

        ierr = xios_getvar("toymodel_ni_glo", tmp)
        read (tmp, *) config%ni_glo
        tmp = ""

        ierr = xios_getvar("toymodel_nj_glo", tmp)
        read (tmp, *) config%nj_glo
        tmp = ""

        ierr = xios_getvar("toymodel_type", tmp)
        config%field_type = TRIM(tmp)
        tmp = ""
        print *, "Field type: ", config%field_type

        ! Getting the frequency of the operation
        CALL xios_get_field_attr("field2D_oce_to_atm", freq_op=tmp2)
        CALL xios_duration_convert_to_string(tmp2, tmp)
        ! Remove the last two characters from the string to retrieve the pure number "(xx)ts"
        tmp = tmp(1:LEN_TRIM(tmp)-2)
        ! Convert to integer
        READ(tmp, *) config%freq_op_in_ts
        print *, "Frequency of operation: ", config%freq_op_in_ts
        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        call xios_get_start_date(config%start_date)


    end subroutine load_toymodel_data

    subroutine configure_xios_from_model(config)
    implicit none
        type(toymodel_config), intent(in) :: config

        call xios_set_timestep(config%timestep)
        call xios_set_domain_attr("domain", ni_glo=config%ni_glo, nj_glo=config%nj_glo, type=config%field_type)
        call xios_close_context_definition()

    end subroutine configure_xios_from_model
 
    ! This subroutine calculates the elapsed timesteps between the time origin and the current date
    ! Used by the sender toymodel
    subroutine calulate_absolute_curr_timestep(curr_date, timestep, elapsed_timesteps) 
        implicit none
        type(xios_date), intent(in) :: curr_date
        type(xios_date) :: tmp_date, start_date 
        type(xios_duration), intent(in) :: timestep
        integer, intent(out):: elapsed_timesteps
        integer :: start_date_sec, curr_date_sec, tmp_date_sec, elapsed_duration_sec
        type(xios_duration) :: elapsed_duration
        
        CALL xios_get_time_origin(start_date)
        ! Some bad code because there is no xios_duration_convert_to_seconds
        start_date_sec = xios_date_convert_to_seconds(start_date)
        curr_date_sec = xios_date_convert_to_seconds(curr_date)
        elapsed_duration_sec = curr_date_sec - start_date_sec
        tmp_date = start_date + timestep
        tmp_date_sec = xios_date_convert_to_seconds(tmp_date)
        tmp_date_sec = tmp_date_sec - start_date_sec
        
        elapsed_timesteps = elapsed_duration_sec / tmp_date_sec + 1 !t=0 is ts=1

    end subroutine calulate_absolute_curr_timestep

    subroutine run_coupling(conf)
    implicit none 
        type(toymodel_config) :: conf 
        double precision, pointer:: field_send(:,:), field_recv(:,:)
        integer :: curr_timestep, absolute_timestep
        allocate(field_send(conf%ni_glo, conf%nj_glo))
        allocate(field_recv(conf%ni_glo, conf%nj_glo))

        conf%end_date = conf%start_date + conf%duration
        conf%curr_date = conf%start_date
        curr_timestep = 1

        print *, "Start date: ", conf%start_date
        print *, "End date: ", conf%end_date

        do while (conf%curr_date < conf%end_date)

            call xios_update_calendar(curr_timestep)

            if (model_id=="ocn") then
                call calulate_absolute_curr_timestep(conf%curr_date, conf%timestep, absolute_timestep)     
                
                field_send = absolute_timestep
                print *, "OCN: sending field @ts=", curr_timestep, " with value ", field_send(1,1)
                call xios_send_field("field2D_send", field_send)

            else if (model_id=="atm") then

                if(curr_timestep==1) then
                    call xios_recv_field("field2D_restart", field_recv)
                    print *, "  ATM: receiving restart field @ts=", curr_timestep, " with value ", field_recv(1,1)
                else if (mod(curr_timestep-1, conf%freq_op_in_ts) == 0) then
                    call xios_recv_field("field2D_recv", field_recv)
                    print *, "  ATM: receiving field @ts=", curr_timestep, " with value ", field_recv(1,1)
                end if

            end if

            conf%curr_date = conf%curr_date + conf%timestep
            curr_timestep = curr_timestep + 1
        end do

        if(model_id=="ocn") deallocate(field_send)
        deallocate(field_recv)
        
    end subroutine  run_coupling 


end program
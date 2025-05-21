program basic_couple
    use xios
    implicit none
    include "mpif.h"

    integer :: ierr, provided
    integer :: rank, size
    character(len=3) :: model_id
    logical :: is_server = .false.
    logical :: is_client_atm = .false.
    logical :: is_client_ocn = .false.
    

    type :: toymodel_config
        type(xios_date) :: start_date, end_date, curr_date
        type(xios_duration) :: timestep, duration
        integer :: freq_op_in_ts
        integer :: ni_glo, nj_glo, ni, nj, ibegin, jbegin
        integer :: data_dim, data_ni, data_nj, data_ibegin, data_jbegin
        integer, allocatable :: data_i_index(:)
        character(len=255) :: field_type
    end type toymodel_config

    ! Mpi initialization
    print *, "Initializing MPI..."
    call MPI_INIT_THREAD(MPI_THREAD_MULTIPLE, provided, ierr)
    if (provided < MPI_THREAD_MULTIPLE) then
        print *, "The MPI library does not provide the required level of thread support."
        call MPI_FINALIZE(ierr)
        stop
    end if
    call MPI_COMM_SIZE(MPI_COMM_WORLD, size, ierr)
    call MPI_COMM_RANK(MPI_COMM_WORLD, rank, ierr)

    print *, "MPI initialized. Rank: ", rank, " Size: ", size

    if (size /= 4) then
        print *, "This program must be run with 4 processes. Currently, there are ", size, " processes."
        call MPI_FINALIZE(ierr)
        stop
    end if 
    ! -------------------------------

    if(rank==(size-1)) then
        print *, "Rank 0: Initializing XIOS server..."
        call xios_init_server()
    else if (rank== (size-2)) then
        model_id = "atm"
        print *, "Rank 1: Running toy model with model_id = ", model_id
        call run_toymodel()
    else 
        model_id = "ocn"
        print *, "Rank ", rank, ": Running toy model with model_id = ", model_id
        call run_toymodel()
    end if

    call MPI_FINALIZE(ierr)
contains


    subroutine run_toymodel()
    implicit none
        integer :: local_comm
        type(xios_context) :: ctx
        type(toymodel_config) :: config

        call xios_initialize(trim(model_id), return_comm = local_comm)
        call xios_context_initialize(trim(model_id), local_comm)
        call xios_get_handle(trim(model_id), ctx)
        call xios_set_current_context(ctx)
        

        ! Loading the configuration of the toy model
        call load_toymodel_data(config) 

        ! Set the data coming from the model in XIOS
        call configure_xios_from_model(config)

        ! Run the coupling
        call run_coupling(config)

        ! Finalize XIOS
        call xios_context_finalize()
        call xios_finalize()
    end subroutine run_toymodel

    
    subroutine load_toymodel_data(config)
        implicit none
        type(toymodel_config), intent(out) :: config
        character(len=255) :: tmp = ""
        type(xios_duration) :: tmp2
        integer :: i

        print *, "Loading toy model configuration..."
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
        print *, "Global ni: ", config%ni_glo
        tmp = ""

        ierr = xios_getvar("toymodel_nj_glo", tmp)
        read (tmp, *) config%nj_glo
        print *, "Global nj: ", config%nj_glo
        tmp = ""

        ierr = xios_getvar("toymodel_type", tmp)
        config%field_type = TRIM(tmp)
        print *, "Field type: ", config%field_type
        tmp = ""

        ! Getting the frequency of the operation
        CALL xios_get_field_attr("field2D_oce_to_atm", freq_op=tmp2)
        CALL xios_duration_convert_to_string(tmp2, tmp)
        tmp = tmp(1:LEN_TRIM(tmp)-2)
        READ(tmp, *) config%freq_op_in_ts
        print *, "Frequency of operation in timesteps: ", config%freq_op_in_ts

        call xios_get_start_date(config%start_date)
        print *, "Start date: ", config%start_date

        if(model_id == "ocn") then

            if(config%ni_glo /=4 .or. config%nj_glo /=4) THEN
                print *, "This example is only for 4x4 grid"
                STOP
            end if

            config%data_dim = 1 ! Source data is 1D
            config%data_ni = 8 ! Length of data 
            config%data_ibegin = 0 ! Offset of data wrt ibegin
            config%ni = config%ni_glo ! Local partition size
            config%nj = config%nj_glo ! Local partition size
            config%ibegin = 0 ! Offset of the local partition wrt the global grid
            config%jbegin = 0 ! Offset of the local partition wrt the global grid

            allocate(config%data_i_index(config%data_ni))

            ! Checkboard distribution on two processes, 1D data source
            IF (rank==0) THEN
                config%data_i_index = [0, 2, 5, 7, 8, 10, 11, 13]
            ELSE
                config%data_i_index = [1, 3, 4, 6, 9, 12, 14, 15]
            END IF

 
        end if 
    end subroutine load_toymodel_data

    subroutine configure_xios_from_model(config)
    implicit none
        type(toymodel_config), intent(in) :: config

        print *, "Configuring XIOS with model data..."
        call xios_set_timestep(config%timestep)
        call xios_set_domain_attr("domain", ni_glo=config%ni_glo, nj_glo=config%nj_glo, type=config%field_type, ni=config%ni, nj=config%nj, ibegin=config%ibegin, jbegin=config%jbegin)
        if (model_id=="ocn") call xios_set_domain_attr("domain", data_dim=config%data_dim, data_ni=config%data_ni, data_ibegin=config%data_ibegin, data_i_index=config%data_i_index)
        call xios_close_context_definition()
        print *, "XIOS configuration completed."

    end subroutine configure_xios_from_model
 

    subroutine run_coupling(conf)
    implicit none 
        type(toymodel_config) :: conf 
        double precision, allocatable :: field_send(:), field_recv(:,:)
        integer :: curr_timestep, i 

        if (model_id=="ocn") allocate(field_send(conf%data_ni))
        if (model_id=="atm") allocate(field_recv(conf%ni_glo, conf%nj_glo))

        ! Checkboard distribution on two processes, 1D data source
        IF (rank==0) THEN
            field_send = 0
        ELSE IF(rank==1) THEN
            field_send = 1
        END IF

        conf%end_date = conf%start_date + conf%duration
        conf%curr_date = conf%start_date
        curr_timestep = 1

        print *, "Start dete: ", conf%start_date
        print *, "End date: ", conf%end_date

        do while (conf%curr_date < conf%end_date)

            call xios_update_calendar(curr_timestep)

            if (model_id=="ocn") then
                call xios_send_field("field2D_send", field_send)
                print *, "OCN: sending field @ts=", curr_timestep, " with value ", field_send(1)
            else if (model_id=="atm") then
                if (mod(curr_timestep-1, conf%freq_op_in_ts) == 0) then
                    call xios_recv_field("field2D_recv", field_recv)
                    print *, "ATM: receiving field @ts=", curr_timestep, " with value ", field_recv(1,1)
                end if
            end if

            conf%curr_date = conf%curr_date + conf%timestep
            curr_timestep = curr_timestep + 1
        end do

        print *, "Coupling loop completed."

        if (allocated(field_send)) deallocate(field_send)
        if (allocated(field_recv)) deallocate(field_recv)
    end subroutine  run_coupling 
end program
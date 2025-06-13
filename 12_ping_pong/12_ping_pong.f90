program basic_couple
    use xios
    implicit none
    include "mpif.h"

    integer :: ierr, provided
    integer :: rank, size
    character(len=3) :: model_id
    integer :: ocn_mpi_processes, atm_mpi_processes

    type :: toymodel_config
        type(xios_date) :: start_date, end_date, curr_date
        type(xios_duration) :: timestep, duration
        integer :: freq_op_in_ts
        integer :: ni_glo, nj_glo, ni, nj, ibegin, jbegin
        integer :: data_dim, data_ni, data_nj, data_ibegin, data_jbegin
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

    if (modulo(size, 2) /= 0) then
        ! @TODO 
        print *, "This program must be run with an even size of processes. Currently, there are ", size, " processes."
        call MPI_FINALIZE(ierr)
        stop
    end if 
 
    atm_mpi_processes = size / 2
    ocn_mpi_processes = size / 2
    print *, "Number of processes for ATM: ", atm_mpi_processes
    print *, "Number of processes for OCN: ", ocn_mpi_processes
   ! -------------------------------

    if (rank < ocn_mpi_processes) then
        model_id = "ocn"
        print *, "Rank ", rank, ": Running toy model with model_id = ", model_id
        call run_toymodel()
    else 
        model_id = "atm"
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

        call create_toymodel_distribution(config)

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
        print *, "Field type: ", TRIM(config%field_type)
        tmp = ""

        ! if(model_id=="atm") then
        !     CALL xios_get_field_attr("ocn_to_atm", freq_op=tmp2)
        ! else if (model_id=="ocn") then
        !     CALL xios_get_field_attr("atm_to_ocn", freq_op=tmp2)
        ! end if

        ! CALL xios_duration_convert_to_string(tmp2, tmp)
        ! tmp = tmp(1:LEN_TRIM(tmp)-2)
        ! READ(tmp, *) config%freq_op_in_ts
        config%freq_op_in_ts = 1 ! Ping-pong every ts, not used in this example
        print *, "Frequency of operation in timesteps: ", config%freq_op_in_ts

        call xios_get_start_date(config%start_date)
        print *, "Start date: ", config%start_date

    end subroutine load_toymodel_data
 
    subroutine create_toymodel_distribution(config) 
        implicit none
        type(toymodel_config), intent(inout) :: config
        integer :: model_rank
        
        ! We will use data_ attribute that are more flexible for non-box partitioning 
        ! The local domains are overlapped ands equivalent to the global domain.
        config%ni = config%ni_glo 
        config%nj = config%nj_glo
        config%ibegin = 0
        config%jbegin = 0
        ! -----------------------------------------------------------------------------
        
        ! The distribution of the data is done in the model.
        config%data_dim = 1 ! How we want to pass the data to XIOS
        if (model_id == "atm") then
            config%data_ni = (config%ni_glo / (atm_mpi_processes))*config%nj_glo ! For example, split latitudes over the processes
        else if (model_id == "ocn") then
            config%data_ni = (config%ni_glo / (ocn_mpi_processes))*config%nj_glo ! For example, split latitudes over the processes
        end if 

        ! First processes are dedicated to the ocean model
        if (model_id == "atm") then
            model_rank = model_rank - ocn_mpi_processes
        else if (model_id == "ocn") then
            model_rank = rank
        end if

        config%data_ibegin = (model_rank) * config%data_ni 
        

        ! -------------------------------------------------------------------------------
 
   end subroutine create_toymodel_distribution

    subroutine configure_xios_from_model(config)
    implicit none
        type(toymodel_config), intent(in) :: config

        logical, allocatable :: mask(:)
        character(len=255) :: domain_name

        allocate(mask(config%ni_glo*config%nj_glo))
        mask = .true. ! Initialize mask to true

        print *, "Configuring XIOS with model data..."
        call xios_set_timestep(config%timestep)

        if (model_id == "ocn") then
            domain_name = "domain_ocn"
        else if (model_id == "atm") then
            domain_name = "domain_atm"
        end if

        ! Setting distribution (which is the same for both models) on own domains
        ! Leaving the other's model original domain untouched
        call xios_set_domain_attr(domain_name, ni_glo=config%ni_glo, nj_glo=config%nj_glo, type=config%field_type, ni=config%ni, nj=config%nj, ibegin=config%ibegin, &
                jbegin=config%jbegin, data_dim=config%data_dim, data_ni=config%data_ni, data_ibegin=config%data_ibegin)
        
                
        call xios_close_context_definition()
        print *, "XIOS configuration completed."

    end subroutine configure_xios_from_model
 

    subroutine run_coupling(conf)
    implicit none
    type(toymodel_config) :: conf
    double precision, allocatable :: field_send(:), field_recv(:)
    integer :: curr_timestep
    real :: start_time, end_time

    allocate(field_send(conf%data_ni))
    allocate(field_recv(conf%data_ni))

    conf%end_date = conf%start_date + conf%duration
    conf%curr_date = conf%start_date
    curr_timestep = 1

    print *, "Start date: ", conf%start_date
    print *, "End date: ", conf%end_date

    do while (conf%curr_date < conf%end_date)

        call xios_update_calendar(curr_timestep)

        ! Ocean send -> Atmos recv -> Atmos send -> Ocean recv in same timestep

        if (model_id=="ocn") then
            
            field_send = curr_timestep * rank
            print *, "OCN: sending field @ts=", curr_timestep, " with value ", field_send(1)
            call cpu_time(start_time)
            call xios_send_field("field2D_send_ocn", field_send)
            call xios_recv_field("field2D_recv_ocn", field_recv)
            call cpu_time(end_time)
            print *, "OCN: ping/pong time (s): ", end_time - start_time
            print *, "OCN: receiving field @ts=", curr_timestep, " with value ", field_recv(1)

        else if (model_id=="atm") then

            call xios_recv_field("field2D_recv_atm", field_recv)
            print *, "  ATM: receiving field @ts=", curr_timestep, " with value ", field_recv(1)
            ! Ping-pong mechanism
            call xios_send_field("field2D_send_atm", field_recv)
            print *, "ATM: sending field @ts=", curr_timestep, " with value ", field_recv(1)

        end if

        conf%curr_date = conf%curr_date + conf%timestep
        curr_timestep = curr_timestep + 1
    end do

    if (allocated(field_send)) deallocate(field_send)
    if (allocated(field_recv)) deallocate(field_recv)
end subroutine run_coupling 
end program
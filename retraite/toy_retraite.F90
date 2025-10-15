program toy_retraite

#ifdef WITH_XIOS
    use xios
#elif WITH_OASIS
    use mod_oasis
#endif
    implicit none
    include "mpif.h"
    integer :: ierr, provided
    integer :: rank, size
    character(len=255) :: model_name
#ifdef WITH_XIOS
    type :: toymodel_config
        type(xios_date) :: start_date, end_date, curr_date
        type(xios_duration) :: timestep, duration
        integer :: ni_glo, nj_glo
        character(len=255) :: grid_type
    end type toymodel_config
#elif WITH_OASIS
    type :: toymodel_config
        integer :: timestep, duration
        integer :: ni_glo, nj_glo
    end type toymodel_config
#endif

    ! Mpi initialization
    call MPI_Init(ierr)
    call MPI_COMM_SIZE(MPI_COMM_WORLD, size, ierr)
    call MPI_COMM_RANK(MPI_COMM_WORLD, rank, ierr)

    if (rank==0) then
        model_name = "atm"
        call run_toymodel()
    else if (rank==1) then
        model_name = "ocn"
        call run_toymodel()
    end if

    call MPI_FINALIZE(ierr)

contains
    
    subroutine run_toymodel()
    implicit none
        integer :: local_comm
        type(toymodel_config) :: conf
        character(len=8) :: var_name ! name of field, 8 char for OASIS
        integer :: coupling_freq
        double precision, allocatable :: field_send(:,:), field_recv(:,:)
        integer :: curr_timestep
#ifdef WITH_XIOS
        type(xios_context) :: ctx
        character(len=255) :: tmp = ""
        type(xios_duration) :: tmp2
#elif WITH_OASIS
        integer :: model_id, part_id, var_id
        integer :: il_paral(3)
        integer :: var_nodims(2)
        integer :: var_actual_shape(2)
        integer :: var_type
        integer :: cpl_freq(1)
        integer :: il_curr_time
#endif
        
#ifdef WITH_XIOS
        ! Standard XIOS initialization
        call xios_initialize(model_name, return_comm = local_comm)
        call xios_context_initialize(model_name, local_comm)
        call xios_get_handle(model_name, ctx)
        call xios_set_current_context(ctx)
#elif WITH_OASIS
        ! Standard OASIS initialization
        CALL oasis_init_comp (model_id, model_name, ierr)
        CALL oasis_get_localcomm (local_comm, ierr)
#endif
        ! --------------------------------------------
        ! Loading the configuration of the toy model 
        ! (timestep length, run duration, global dimension, coupling frequency).
        ! In this toymodel with XIOS, those variables are arbitrarily defined in iodef.xml
        ! In this toymodel with OASIS, those variables are hard coded 
#ifdef WITH_XIOS
        ierr = xios_getvar("toymodel_duration", tmp)
        conf%duration = xios_duration_convert_from_string(TRIM(tmp))
        tmp = ""
        ierr = xios_getvar("toymodel_timestep_duration", tmp)
        conf%timestep = xios_duration_convert_from_string(TRIM(tmp))
        tmp = ""
        ierr = xios_getvar("toymodel_ni_glo", tmp)
        read (tmp, *) conf%ni_glo
        tmp = ""
        ierr = xios_getvar("toymodel_nj_glo", tmp)
        read (tmp, *) conf%nj_glo
        tmp = ""
        ierr = xios_getvar("toymodel_type", tmp)
        conf%grid_type = TRIM(tmp)
        tmp = ""
        !
#elif WITH_OASIS
        ! Defining some model parameters directly here
        conf%duration = 86400
        conf%timestep = 900
        conf%ni_glo = 10
        conf%nj_glo = 10
#endif
       ! Other initialization calls
        if (model_name=="ocn") then
                var_name = 'FSENDOCN'
        else if (model_name=="atm") then
                var_name = 'FRECVATM'
        endif

#ifdef WITH_XIOS
        call xios_set_timestep(conf%timestep)
        call xios_set_domain_attr("domain", ni_glo=conf%ni_glo, nj_glo=conf%nj_glo, type=conf%grid_type)
        ! Getting the start date
        call xios_get_start_date(conf%start_date)
        ! Getting the coupling frequency of the operation
        CALL xios_get_field_attr("field2D_oce_to_atm", freq_op=tmp2)
        coupling_freq = tmp2%timestep
        !
#elif WITH_OASIS
        ! Declare a serial partition of size ni_glo*nj_glo
        il_paral(1)=0
        il_paral(2)=0
        il_paral(3)=conf%ni_glo*conf%nj_glo
        CALL oasis_def_partition(part_id, il_paral, ierr)
        var_nodims(1) = 2    ! Rank of the field array is 2
        var_nodims(2) = 1    ! Bundles always 1 for OASIS3
        var_actual_shape(:) = 1
        if (model_name=="ocn") then
                var_type = OASIS_Out
        else if (model_name=="atm") then
                var_type = OASIS_In
        endif
        CALL oasis_def_var (var_id, var_name, part_id, var_nodims, var_type, var_actual_shape, OASIS_Real, ierr) 
        !XXXXXX CALL oasis_get_freqs(var_id, var_type, 1, cpl_freq(1), ierr)
        coupling_freq = 3600
#endif
        !
        ! Finalize the definition phase
#ifdef WITH_XIOS
        call xios_close_context_definition()
#elif WITH_OASIS
        call oasis_enddef()
#endif
        !
        ! Run the coupling
        allocate(field_send(conf%ni_glo, conf%nj_glo))
        allocate(field_recv(conf%ni_glo, conf%nj_glo))
        !
        curr_timestep = 1
#ifdef WITH_XIOS
        conf%end_date = conf%start_date + conf%duration
        conf%curr_date = conf%start_date
        print *, "Start date: ", conf%start_date, "End date: ", conf%end_date
        !
        do while (conf%curr_date < conf%end_date)
            call xios_update_calendar(curr_timestep)
#elif WITH_OASIS
        il_curr_time = 0
        do while (il_curr_time < conf%duration)
#endif
            if (model_name=="ocn") then  ! Send FSENDOCN
                field_send = curr_timestep
                print *, "OCN: sending field @ts=", curr_timestep, " with value ", field_send(1,1)
#ifdef WITH_XIOS
                call xios_send_field(var_name, field_send)
#elif WITH_OASIS
                call oasis_put(var_id, il_curr_time, field_send, ierr)
#endif

            else if (model_name=="atm") then ! Receive FRECVATM 
#ifdef WITH_XIOS
                if(curr_timestep==1) then
                    call xios_recv_field("field2D_restart", field_recv)
                    print *, "  ATM: receiving restart field @ts=", curr_timestep, " with value ", field_recv(1,1)
                else if (mod(curr_timestep-1, coupling_freq) == 0) then
                    call xios_recv_field(var_name, field_recv)
                    print *, "  ATM: receiving field @ts=", curr_timestep, " with value ", field_recv(1,1)
                end if
#elif WITH_OASIS
                call oasis_get(var_id, il_curr_time, field_recv, ierr)

#endif
            end if
            curr_timestep = curr_timestep + 1
#ifdef WITH_XIOS
            conf%curr_date = conf%curr_date + conf%timestep
#elif WITH_OASIS
            il_curr_time = il_curr_time + conf%timestep
#endif
        end do

        if(allocated(field_send)) deallocate(field_send)
        if(allocated(field_recv)) deallocate(field_recv)

        ! --------------------------------------------
#ifdef WITH_XIOS
        call xios_context_finalize()
        call xios_finalize()
#elif WITH_OASIS
        call oasis_terminate(ierr)
#endif
    end subroutine run_toymodel
end program

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
        integer :: recv_freq_ts
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

    if (rank==0) then
        model_id = "arpege-surfex"
        call run_toymodel()
    else if (rank==1) then
        model_id = "nemo-gelato"
        call run_toymodel()
    else if (rank == 2) then
        model_id = "trip"
        call run_toymodel()
    else if (rank == 3) then
        model_id = "gelato"
        call run_toymodel()
    else
        call xios_init_server()
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

        ! ! Getting the frequency of the operation
        ! if (model_id == "atm") then 
        !     CALL xios_get_field_attr("ocn_to_atm1", freq_op=tmp2)
        ! else if(model_id == "ocn") then
        !     CALL xios_get_field_attr("atm_to_ocn1", freq_op=tmp2)
        ! end if

        ! CALL xios_duration_convert_to_string(tmp2, tmp)
        ! ! Remove the last two characters from the string to retrieve the pure number "(xx)ts"
        ! tmp = tmp(1:LEN_TRIM(tmp)-2)
        ! ! Convert to integer
        ! READ(tmp, *) config%recv_freq_ts
        ! print *, "Frequency of operation: ", config%recv_freq_ts
        ! !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        config%recv_freq_ts = 1 ! Get from the XML file @todo

        call xios_get_start_date(config%start_date)


    end subroutine load_toymodel_data

    subroutine configure_xios_from_model(config)
    implicit none
        type(toymodel_config), intent(in) :: config

        call xios_set_timestep(config%timestep)
        call xios_set_domain_attr("domain_"//trim(model_id), ni_glo=config%ni_glo, nj_glo=config%nj_glo, type=config%field_type)
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
        double precision, allocatable :: field_send(:,:), field_recv(:,:)
        integer :: curr_timestep, time
        integer :: nfields_send, nfields_recv
        character(len=32), allocatable :: send_labels(:)
        character(len=32), allocatable :: recv_labels(:)
        integer :: i

        allocate(field_send(conf%ni_glo, conf%nj_glo))
        allocate(field_recv(conf%ni_glo, conf%nj_glo))

        if (model_id == "nemo-gelato") then
            nfields_send = 3
            nfields_recv = 12
            send_labels = ['O_SSTSST', 'O_OCurx1', 'O_OCury1']
            recv_labels = ['O_OTaux1', 'O_OTauy1', 'O_TauMod', 'O_Wind10', 'OTotSnow', 'OTotRain', 'OTotEvap', 'O_QnsMIx', 'O_QsrMix', 'O_Runoff', 'Ocalvigr', 'Ocalvian']

        else if (model_id == "arpege-surfex") then
            nfields_send = 17
            nfields_recv = 11
            send_labels = ['COZOTAUX', 'COMETAUY', 'COTAUMOD', 'COWINMOD', 'COSUBLIM', 'CONSFICE', 'COSHFICE', 'COTOSOPR', 'COTOLIPR', 'COTHSHSU', 'CONSFTOT', 'COSHFTOT', 'SXRUNOFF', 'SXDRAIN', 'SXCALV', 'SXSRCFLD', 'LKWATBUD']
            recv_labels =  ['SISUTESU', 'SIICECOV', 'SIALBEDO', 'SIICETEM', 'SIUOCEAN', 'SIVOCEAN', 'SXTWS', 'SXWTD', 'SXFWTD', 'SXFFLD', 'SXPIFLD']

        else if (model_id == "trip") then 
            nfields_send = 8
            nfields_recv = 5
            send_labels = ['TRTWS', 'TRWTD', 'TRFWTD', 'TRFFLD', 'TRPIFLD', 'TRRIVDIS', 'TRCALVGR', 'TRCALVAN']
            recv_labels = ['TRRUNOFF', 'TRDRAIN', 'TRCALV', 'TRSRCFLD', 'OLakeWat']
            
        else if (model_id == "gelato") then
            nfields_send = 3
            nfields_recv = 3
            send_labels = ['OIceFrc', 'O_AlbIce', 'O_TepIce']
            recv_labels = ['OlceEvap', 'O_QnsIce', 'O_QsrIce']
        end if

        conf%end_date = conf%start_date + conf%duration
        conf%curr_date = conf%start_date
        curr_timestep = 1

        print *, "Start date: ", conf%start_date
        print *, "End date: ", conf%end_date

        do while (conf%curr_date < conf%end_date)

            call xios_update_calendar(curr_timestep)
            time = xios_date_convert_to_seconds(conf%curr_date) - xios_date_convert_to_seconds(conf%start_date)
            field_send = time

            if (model_id == "nemo-gelato") then
                print *, "OCN: sending fields @interval_start_time", time, " with value ", field_send(1,1)
                do i = 1, nfields_send
                    call xios_send_field(trim(send_labels(i)), field_send)
                end do

                if (curr_timestep == 1) then
                    do i = 1, nfields_recv
                        call xios_recv_field(trim(recv_labels(i)) // "_restart", field_recv)
                        print *, "  OCN: receiving restart field ", trim(recv_labels(i)), " @interval_start_time", time, " with value ", field_recv(1,1)
                    end do
                else if (mod(curr_timestep-1, conf%recv_freq_ts) == 0) then
                    do i = 1, nfields_recv
                        call xios_recv_field(trim(recv_labels(i)), field_recv)
                        print *, "  OCN: receiving field ", trim(recv_labels(i)), " @interval_start_time", time , " with value ", field_recv(1,1)
                    end do
                end if

            else if (model_id == "arpege-surfex") then
                print *, "ATM: sending fields @interval_start_time", time, " with value ", field_send(1,1)
                do i = 1, nfields_send
                    call xios_send_field(trim(send_labels(i)), field_send)
                end do

                if (curr_timestep == 1) then
                    do i = 1, nfields_recv
                        call xios_recv_field(trim(recv_labels(i)) // "_restart", field_recv)
                        print *, "  ATM: receiving restart field ", trim(recv_labels(i)), " @interval_start_time", time, " with value ", field_recv(1,1)
                    end do
                else if (mod(curr_timestep-1, conf%recv_freq_ts) == 0) then
                    do i = 1, nfields_recv
                        call xios_recv_field(trim(recv_labels(i)), field_recv)
                        print *, "  ATM: receiving field ", trim(recv_labels(i)), " @interval_start_time", time , " with value ", field_recv(1,1)
                    end do
                end if

            else if (model_id == "trip") then
                print *, "LND: sending fields @interval_start_time", time, " with value ", field_send(1,1)
                do i = 1, nfields_send
                    call xios_send_field(trim(send_labels(i)), field_send)
                end do

                if (curr_timestep == 1) then
                    do i = 1, nfields_recv
                        call xios_recv_field(trim(recv_labels(i)) // "_restart", field_recv)
                        print *, "  LND: receiving restart field ", trim(recv_labels(i)), " @interval_start_time", time, " with value ", field_recv(1,1)
                    end do
                else if (mod(curr_timestep-1, conf%recv_freq_ts) == 0) then
                    do i = 1, nfields_recv
                        call xios_recv_field(trim(recv_labels(i)), field_recv)
                        print *, "  LND: receiving field ", trim(recv_labels(i)), " @interval_start_time", time , " with value ", field_recv(1,1)
                    end do
                end if

            else if (model_id == "gelato") then
                print *, "ICE: sending fields @interval_start_time", time, " with value ", field_send(1,1)
                do i = 1, nfields_send
                    call xios_send_field(trim(send_labels(i)), field_send)
                end do

                if (curr_timestep == 1) then
                    do i = 1, nfields_recv
                        call xios_recv_field(trim(recv_labels(i)) // "_restart", field_recv)
                        print *, "  ICE: receiving restart field ", trim(recv_labels(i)), " @interval_start_time", time, " with value ", field_recv(1,1)
                    end do
                else if (mod(curr_timestep-1, conf%recv_freq_ts) == 0) then
                    do i = 1, nfields_recv
                        call xios_recv_field(trim(recv_labels(i)), field_recv)
                        print *, "  ICE: receiving field ", trim(recv_labels(i)), " @interval_start_time", time , " with value ", field_recv(1,1)
                    end do
                end if

            end if

            conf%curr_date = conf%curr_date + conf%timestep
            curr_timestep = curr_timestep + 1
        end do
    
        if(allocated(field_send)) deallocate(field_send)
        if(allocated(field_recv)) deallocate(field_recv)
        
    end subroutine  run_coupling 


end program
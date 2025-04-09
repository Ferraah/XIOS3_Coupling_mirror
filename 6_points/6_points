PROGRAM basic_couple
    USE mod_wait
    USE xios
    IMPLICIT NONE
    INCLUDE "mpif.h"

    INTEGER :: ierr
    INTEGER :: rank, size

    ! Map the process rank to the role
    LOGICAL :: is_server = .FALSE.
    LOGICAL :: is_client_atm = .FALSE.
    LOGICAL :: is_client_ocn = .FALSE.

    INTEGER :: provided


    CALL MPI_INIT_THREAD(MPI_THREAD_MULTIPLE, provided, ierr)
    IF (provided < MPI_THREAD_MULTIPLE) THEN
        PRINT *, "The MPI library does not provide the required level of thread support."
        CALL MPI_FINALIZE(ierr)
        STOP
    END IF
    CALL MPI_COMM_SIZE(MPI_COMM_WORLD, size, ierr)
    CALL MPI_COMM_RANK(MPI_COMM_WORLD, rank, ierr)


    IF (size /= 4) THEN
        PRINT *, "This program must be run with 4 processes. Currently, there are ", size, " processes."
        CALL MPI_FINALIZE(ierr)
        STOP
    END IF

    ! Assign roles to the processes
    IF (rank == size-1) THEN
        is_server = .TRUE.
    ELSE IF (rank == size-2) THEN
        is_client_atm = .TRUE.
    ELSE 
        is_client_ocn = .TRUE.
    END IF


    if(is_server) THEN
        CALL xios_init_server()
    ELSE
        IF (is_client_ocn) THEN
            write (*,*) "I am client ocn with rank ", rank
            CALL runModel("ocn")
        ELSE IF (is_client_atm) THEN
            write (*,*) "I am client atm with rank ", rank
            CALL runModel("atm")
        END IF
        print *, "Model ", rank, " is done"
        CALL xios_finalize()
    ENDIF


    CALL MPI_FINALIZE(ierr)

CONTAINS
    
    ! Init XIOS environment (context, timestep, duration, etc.) by loading parameters from xml and usual XIOS routines
    SUBROUTINE initEnvironment(model_id, x_start_date, x_end_date, x_timestep, x_duration, freq_op, ni_glo, nj_glo)
        CHARACTER(LEN=*), INTENT(IN) :: model_id
        TYPE(xios_date), INTENT(OUT) :: x_start_date, x_end_date
        TYPE(xios_duration), INTENT(OUT) :: x_timestep, x_duration
        INTEGER, INTENT(OUT) :: freq_op
        INTEGER :: ni_glo, nj_glo
        INTEGER :: local_comm
        TYPE(xios_context) :: ctx
        TYPE(xios_duration) :: x_freq_op
        INTEGER :: ierr
        CHARACTER(LEN=255) :: tmp = "" ! Temporary string to store intermiediate xml valules

        ! Initializing the runModel but local_com is not used in this example
        CALL xios_initialize(model_id, return_comm = local_comm)

        write(*,*) "Model ", model_id, " is init  with rank ", rank

        ! Retrieve and set context
        CALL xios_context_initialize(model_id, local_comm)
        CALL xios_get_handle(model_id, ctx)
        CALL xios_set_current_context(ctx)

        ! Retrieve the starting timestep and duration
        ierr = xios_getvar("duration", tmp)
        print *, "Duration: ", TRIM(tmp)
        x_duration = xios_duration_convert_from_string(TRIM(tmp))
        tmp = ""

        ierr = xios_getvar("timestep_duration", tmp)
        print *, "Timestep duration: ", TRIM(tmp)
        x_timestep = xios_duration_convert_from_string(TRIM(tmp))
        tmp = ""

        CALL xios_set_timestep(x_timestep) 

        ! Retrieve the start date and calculate end date 
        CALL xios_get_start_date(x_start_date)
        x_end_date = x_start_date + x_duration

        ! Getting the frequency of the operation
        CALL xios_get_field_attr("field2D_oce_to_atm", freq_op=x_freq_op)
        CALL xios_duration_convert_to_string(x_freq_op, tmp)
        ! Remove the last two characters from the string to retrieve the pure number "(xx)ts"
        tmp = tmp(1:LEN_TRIM(tmp)-2)
        ! Convert to integer
        READ(tmp, *) freq_op
        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        CALL xios_get_domain_attr("domain", ni_glo=ni_glo, nj_glo=nj_glo)

        ! Close the context definition


    END SUBROUTINE initEnvironment

    SUBROUTINE runModel(model_id)
    IMPLICIT NONE
        CHARACTER(LEN=*), INTENT(IN):: model_id
        INTEGER :: curr_timestep
        TYPE(xios_date) :: x_start_date, x_end_date, x_curr_date
        TYPE(xios_duration) :: x_timestep, x_duration, x_freq_op
        INTEGER :: freq_op

        INTEGER :: ni_glo, nj_glo, ni, nj, ibegin, jbegin, data_ibegin, data_jbegin, data_dim, data_ni, data_nj, i
        INTEGER, POINTER :: data_i_index(:), data_j_index(:)
        DOUBLE PRECISION, POINTER :: field_send(:) ! 1D now
        DOUBLE PRECISION, POINTER :: field_recv(:,:)

        ! Init XIOS environment (context, timestep, duration, etc.) by loading parameters from xml and usual XIOS routines
        CALL initEnvironment(model_id, x_start_date, x_end_date, x_timestep, x_duration, freq_op, ni_glo, nj_glo)

        IF(ni_glo /=4 .or. nj_glo /=4) THEN
            print *, "This example is only for 4x4 grid"
            STOP
        END IF

        data_dim = 1 ! Source data is 1D
        data_ni = 8 ! Length of data 
        data_ibegin = 0 ! Offset of data wrt ibegin
        ni = ni_glo ! Local partition size
        nj = nj_glo ! Local partition size
        ibegin = 0 ! Offset of the local partition wrt the global grid
        jbegin = 0 ! Offset of the local partition wrt the global grid

        ALLOCATE(data_i_index(data_ni)) ! Indices ao
        ALLOCATE(field_send(data_ni))
        ALLOCATE(field_recv(4,4))
        
        ! Checkboard distribution on two processes, 1D data source
        IF (rank==0) THEN
            data_i_index = [(i, i=0, 14, 2)]
            field_send = [(0, i=0, 14, 2)]
        ELSE
            data_i_index = [(i, i=1, 15, 2)]
            field_send = [(1, i=1, 15, 2)]
        END IF

        IF (model_id == "ocn") THEN
            ! Add the local sizes and begin indices to the domain referred in the xml
            CALL xios_set_domain_attr("domain", ni=ni, nj=nj, ibegin=ibegin, jbegin=jbegin, data_ni=data_ni, data_i_index=data_i_index, data_ibegin=data_ibegin, data_dim=1)
            print * , "Model ", model_id, " ni_glo = ", ni_glo, " nj_glo = ", nj_glo, " ni = ", ni, " nj = ", nj, " ibegin = ", ibegin, " jbegin = ", jbegin
        END IF 

        CALL xios_close_context_definition()
        
        
        ! XIOS preference to start from 1
        x_curr_date = x_start_date
        curr_timestep = 1

        print *, "Model ",model_id, " is starting"


        ! Iterate for the duration of the simulation (x_end ecluded)
        DO WHILE (x_curr_date < x_end_date)

            ! Communicate timestep increment to XIOS
            CALL xios_update_calendar(curr_timestep)


            ! Ocean sends to atmosphere
            IF(model_id == "ocn" ) THEN

                ! Start sending field starting from 1 with a certain frequency
                CALL xios_send_field("field2D_send", field_send)
                print *, "Model ", model_id, " sended @ts =", curr_timestep

            ! Atmosphere receives data from ocean
            ELSE IF(model_id == "atm") THEN

                ! Start receiving field starting from 1 with a certain frequency
                !!!! "GET" call at the desired timestep EXPLICITLY
                IF (modulo(curr_timestep-1, freq_op) == 0) THEN
                    CALL xios_recv_field("field2D_recv", field_recv)
                    print *, "Model ", model_id, " received " , field_recv(1,1), " @ts = ", curr_timestep
                END IF

            END IF
            

            ! Increase time counters
            x_curr_date = x_curr_date + x_timestep ! Date
            curr_timestep = curr_timestep + 1 ! Timestep

        END DO
        DEALLOCATE(field_send)
        DEALLOCATE(field_recv)

        CALL xios_context_finalize()

    END SUBROUTINE runModel


END PROGRAM basic_couple
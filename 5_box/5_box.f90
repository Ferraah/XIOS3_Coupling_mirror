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


    IF (size /= 6) THEN
        PRINT *, "This program must be run with 6 processes. Currently, there are ", size, " processes."
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
        INTEGER :: nij(4, 2), begin_points(4, 2)
        INTEGER :: ni_glo, nj_glo, ni, nj, ibegin, jbegin
        DOUBLE PRECISION, POINTER :: field_send(:,:)
        DOUBLE PRECISION, POINTER :: field_recv(:,:)

        ! Init XIOS environment (context, timestep, duration, etc.) by loading parameters from xml and usual XIOS routines
        CALL initEnvironment(model_id, x_start_date, x_end_date, x_timestep, x_duration, freq_op, ni_glo, nj_glo)

        ! For this toy model, we define the local sizes and offsets manually.
        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        begin_points(1, :) = [0, 0] ! Rank 0 (ibegin, jbegin)
        begin_points(2, :) = [24, 0]
        begin_points(3, :) = [0, 10]
        begin_points(4, :) = [36, 10] ! Rank 3 (ibegin, jbegin)

        nij(1, :) = [24, 10] ! Rank 0 (ni, nj)
        nij(2, :) = [36, 10]
        nij(3, :) = [36, 10]
        nij(4, :) = [24, 10] ! Rank 3 (ni, nj)
        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        ! Defining the local sizes and offsets
        ni = nij(rank+1, 1)
        nj = nij(rank+1, 2)
        ibegin = begin_points(rank+1, 1)
        jbegin = begin_points(rank+1, 2)

        IF (model_id == "ocn") THEN
            ! Add the local sizes and begin indices to the domain referred in the xml
            CALL xios_set_domain_attr("domain", ni=ni, nj=nj, ibegin=ibegin, jbegin=jbegin)
            print * , "Model ", model_id, " ni_glo = ", ni_glo, " nj_glo = ", nj_glo, " ni = ", ni, " nj = ", nj, " ibegin = ", ibegin, " jbegin = ", jbegin
        END IF

        CALL xios_close_context_definition()
        !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        ALLOCATE(field_send(ni, nj))
        ALLOCATE(field_recv(ni_glo, nj_glo))

        ! XIOS preference to start from 1
        x_curr_date = x_start_date
        curr_timestep = 1

        print *, "Model ",model_id, " is starting"


        ! Iterate for the duration of the simulation (x_end ecluded)
        DO WHILE (x_curr_date < x_end_date)

            ! Communicate timestep increment to XIOS
            CALL xios_update_calendar(curr_timestep)

            field_send = curr_timestep ! Assigning the field values to the current timestep for testing

            ! Ocean sends to atmosphere
            IF(model_id == "ocn") THEN

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
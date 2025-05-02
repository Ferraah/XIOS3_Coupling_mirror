program basic_couple
    use xios
    implicit none
    include "mpif.h"

    integer :: ierr
    integer :: rank, size
    character(len=255) :: model_id

    ! Mpi initialization
    call MPI_INIT(ierr)
    call MPI_COMM_SIZE(MPI_COMM_WORLD, size, ierr)
    call MPI_COMM_RANK(MPI_COMM_WORLD, rank, ierr)

    if(rank==0) then
        call xios_init_server()
    else if (rank==1) then
        model_id = "atm"
        call run_toymodel()
    else if (rank==2) then
        model_id = "ocn"
        call run_toymodel()
    else if (rank==3) then
        model_id = "ice"
        call run_toymodel()
    end if

    call MPI_FINALIZE(ierr)

contains
    
    subroutine run_toymodel()
    implicit none
        integer :: local_comm
        type(xios_context) :: ctx
        type(xios_duration) :: timestep
        timestep%second = 3600

        ! Standard XIOS initialization
        call xios_initialize(model_id, return_comm = local_comm)
        call xios_context_initialize(model_id, local_comm)
        call xios_get_handle(model_id, ctx)
        call xios_set_current_context(ctx)

        call xios_set_timestep(timestep)
        call xios_close_context_definition()
        ! --------------------------------------------

        call xios_context_finalize()
        call xios_finalize()


    end subroutine run_toymodel


end program
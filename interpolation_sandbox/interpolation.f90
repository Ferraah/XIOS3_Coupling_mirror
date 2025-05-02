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

    model_id = "client"
    call run_toymodel()

    call MPI_FINALIZE(ierr)

contains
    
    subroutine run_toymodel()
    implicit none
        integer :: local_comm
        type(xios_context) :: ctx
        type(xios_duration) :: timestep
        integer :: ts = 1
        integer :: ni, nj, ni_glo, nj_glo
        double precision, allocatable :: lon(:), lat(:)
        double precision, allocatable :: field_send(:, :)
        integer :: i, j
        double precision, allocatable :: xcoor(:, :), ycoor(:, :)

        ! Standard XIOS initialization
        call xios_initialize(model_id, return_comm = local_comm)
        call xios_context_initialize(model_id, local_comm)
        call xios_get_handle(model_id, ctx)
        call xios_set_current_context(ctx)

        timestep = xios_duration_convert_from_string("1d")
        call xios_set_timestep(timestep)
        call xios_close_context_definition()

        call xios_get_domain_attr("field_2D::", ni_glo=ni_glo, nj_glo=nj_glo)
        print *, "ni_glo = ", ni_glo, " nj_glo = ", nj_glo
        allocate(field_send(ni_glo, nj_glo))
        allocate(lon(ni_glo))
        allocate(lat(nj_glo))
        call xios_get_domain_attr("field_2D::", lonvalue_1d=lon, latvalue_1d=lat)

        call function_ana(ni_glo, nj_glo, xcoor, ycoor, field_send)
        deallocate(xcoor, ycoor)
        

        do ts=1,1
            call xios_update_calendar(1)
            call xios_send_field("field_2D", field_send)
        end do
        ! --------------------------------------------

        call xios_context_finalize()
        call xios_finalize()

        deallocate(field_send)

    end subroutine run_toymodel

    subroutine function_ana(ni, nj, lat, lon, fnc_ana)
      implicit none
      integer, parameter :: wp = selected_real_kind(12,307) ! double
      !
      integer, intent(in) :: ni, nj
      real(kind=wp), dimension(ni,nj) :: xcoor, ycoor
      real(kind=wp), dimension(ni), intent(in) :: lon
      real(kind=wp), dimension(nj), intent(in) :: lat
      real(kind=wp), dimension(ni,nj), intent(out) :: fnc_ana
      !
      real (kind=wp), parameter    :: dp_pi=3.14159265359
      real (kind=wp), parameter    :: dp_conv = dp_pi/180.
      real(kind=wp)  :: dp_length, coef, coefmult
      integer             :: i,j
      character(len=7) :: cl_anaftype="fcos"

      ! make xcoor and ycoor 2d arrays from lon and lat
      allocate(xcoor(ni_glo, nj_glo))
      allocate(ycoor(ni_glo, nj_glo))
      do j = 1, nj_glo
          do i = 1, ni_glo
              xcoor(i, j) = lon(i)
              ycoor(i, j) = lat(j)
          end do
      end do

      do j=1,nj
        do i=1,ni
          select case (cl_anaftype)
          case ("fcos")
            dp_length = 1.2*dp_pi
            coef = 2.
            coefmult = 1.
            fnc_ana(i,j) = coefmult*(coef - cos( dp_pi*(acos( cos(xcoor(i,j)*dp_conv)*cos(ycoor(i,j)*dp_conv) )/dp_length)) )
          case ("fcossin")
            dp_length = 1.d0*dp_pi
            coef = 21.d0
            coefmult = 3.846d0 * 20.d0
            fnc_ana(i,j) = coefmult*(coef - cos( dp_pi*(acos( cos(ycoor(i,j)*dp_conv)*cos(ycoor(i,j)*dp_conv) )/dp_length)) * &
                                            sin( dp_pi*(asin( sin(xcoor(i,j)*dp_conv)*sin(ycoor(i,j)*dp_conv) )/dp_length)) )
          end select
        enddo
     enddo
    end subroutine function_ana
end program
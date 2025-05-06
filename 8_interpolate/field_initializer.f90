module field_initializer
    implicit none

contains

    !> @brief Initialize a 2D field with a vortex pattern.
    !> @param ni_glo Number of global grid points in the i-direction.
    !> @param nj_glo Number of global grid points in the j-direction.
    !> @param lon Array of longitudes.
    !> @param lat Array of latitudes.
    !> @param mask Logical array indicating valid grid points.
    !> @param field_2d Output 2D field initialized with a vortex pattern.
    subroutine init_field2d_vortex(ni_glo, nj_glo, lon, lat, mask, field_2d)
        implicit none
        integer, intent(in) :: ni_glo, nj_glo
        double precision, allocatable, intent(in):: lon(:)
        double precision, allocatable, intent(in):: lat(:)
        logical, allocatable, intent(in):: mask(:)
        double precision, allocatable, intent(out):: field_2d(:,:)
        double precision, allocatable :: field_1d(:)

        double precision, parameter :: dp_pi=3.14159265359
        double precision, parameter :: dlon0 = 5.5
        double precision, parameter :: dlat0 = 0.2
        double precision, parameter :: dr0   = 3.0
        double precision, parameter :: dd    = 5.0
        double precision, parameter :: dt    = 6.0
        double precision :: dp_conv
        integer :: i,xy

        double precision :: dsinc, dcosc, dcost, dsint
        double precision :: dtrm, dx, dy, dz
        double precision :: dlon, dlat
        double precision :: drho, dvt, domega
        
        xy=ni_glo*nj_glo

        allocate(field_1d(0:xy-1))
        allocate(field_2d(0:ni_glo-1,0:nj_glo-1))


        dp_conv = dp_pi/180.
        dsinc = sin( dlat0 )
        dcosc = cos( dlat0 )

        do i=0,xy-1
        if (mask(i)) then
        
            ! find the rotated longitude and latitude of a point on a sphere
            !		with pole at (dlon0, dlat0).
            dcost = cos( lat(i)*dp_conv )
            dsint = sin( lat(i)*dp_conv )

            dtrm = dcost * cos( lon(i)*dp_conv - dlon0 )
            dx   = dsinc * dtrm - dcosc * dsint
            dy   = dcost * sin( lon(i)*dp_conv - dlon0 )
            dz   = dsinc * dsint + dcosc * dtrm

            dlon = atan2( dy, dx )
            if( dlon < 0.0 ) dlon = dlon + 2.0 * dp_pi
            dlat = asin( dz )
            
            drho = dr0 * cos(dlat)
            dvt = 3.0 * sqrt(3.0)/2.0/cosh(drho)/cosh(drho)*tanh(drho)
            if (drho == 0.0) then
                domega = 0.0
            else
                domega = dvt / drho
            end if

            field_1d(i) = 2.0 * ( 1.0 + tanh( drho / dd * sin( dlon - domega * dt ) ) )

        end if
        end do

        field_2d = reshape(field_1d, (/ni_glo, nj_glo/))
        
    end subroutine init_field2d_vortex

    !> @brief Initialize a 2D field with a vortex pattern and a Gulf Stream.
    !! @param ni_glo Number of global grid points in the i-direction.
    !! @param nj_glo Number of global grid points in the j-direction.
    !! @param lon Array of longitudes.
    !! @param lat Array of latitudes.
    !! @param mask Logical array indicating valid grid points.
    !! @param field_2d Output 2D field initialized with a vortex pattern.
    !! 
    !! @author Andrea Piacentini
    subroutine init_field2d_gulfstream(ni_glo, nj_glo, lon, lat, mask, field_2d)
        implicit none
        integer, intent(in) :: ni_glo, nj_glo
        double precision, allocatable, intent(in) :: lon(:)
        double precision, allocatable, intent(in) :: lat(:)
        logical, allocatable, intent(in) :: mask(:)
        double precision, allocatable, intent(out) :: field_2d(:,:)
        double precision, allocatable :: field_1d(:)

        double precision, parameter :: coef = 2.0, dp_pi = 3.14159265359
        double precision :: dp_length, dp_conv
        integer :: i, xy

        double precision :: gf_coef, gf_ori_lon, gf_ori_lat, &
            & gf_end_lon, gf_end_lat, gf_dmp_lon, gf_dmp_lat
        double precision :: gf_per_lon
        double precision :: dx, dy, dr, dth, dc, dr0, dr1

        xy = ni_glo * nj_glo

        allocate(field_1d(0:xy-1))
        allocate(field_2d(0:ni_glo-1, 0:nj_glo-1))

        dp_length = 1.2 * dp_pi
        dp_conv = dp_pi / 180.0
        gf_coef = 1.0 ! Coefficient for Gulf Stream term (adjust as needed)
        gf_ori_lon = -80.0 ! Origin of the Gulf Stream (longitude in deg)
        gf_ori_lat = 25.0 ! Origin of the Gulf Stream (latitude in deg)
        gf_end_lon = -1.8 ! End point of the Gulf Stream (longitude in deg)
        gf_end_lat = 50.0 ! End point of the Gulf Stream (latitude in deg)
        gf_dmp_lon = -25.5 ! Point of the Gulf Stream decrease (longitude in deg)
        gf_dmp_lat = 55.5 ! Point of the Gulf Stream decrease (latitude in deg)

        dr0 = sqrt(((gf_end_lon - gf_ori_lon) * dp_conv)**2 + &
            & ((gf_end_lat - gf_ori_lat) * dp_conv)**2)
        dr1 = sqrt(((gf_dmp_lon - gf_ori_lon) * dp_conv)**2 + &
            & ((gf_dmp_lat - gf_ori_lat) * dp_conv)**2)

        do i = 0, xy - 1
            if (mask(i)) then
                field_1d(i) = (coef - cos(dp_pi * (acos(cos(lat(i) * dp_conv) * &
                    cos(lon(i) * dp_conv)) / dp_length)))
                gf_per_lon = lon(i)
                if (gf_per_lon > 180.0) gf_per_lon = gf_per_lon - 360.0
                if (gf_per_lon < -180.0) gf_per_lon = gf_per_lon + 360.0
                dx = (gf_per_lon - gf_ori_lon) * dp_conv
                dy = (lat(i) - gf_ori_lat) * dp_conv
                dr = sqrt(dx * dx + dy * dy)
                dth = atan2(dy, dx)
                dc = 1.3 * gf_coef
                if (dr > dr0) dc = 0.0
                if (dr > dr1) dc = dc * cos(dp_pi * 0.5 * (dr - dr1) / (dr0 - dr1))
                field_1d(i) = field_1d(i) + &
                    & (max(1000.0 * sin(0.4 * (0.5 * dr + dth) + &
                    & 0.007 * cos(50.0 * dth) + 0.37 * dp_pi), 999.0) - 999.0) * &
                    & dc
            end if
        end do

        field_2d = reshape(field_1d, (/ni_glo, nj_glo/))

    end subroutine init_field2d_gulfstream


end module field_initializer
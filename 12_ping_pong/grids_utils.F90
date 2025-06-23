module grids_utils
    use xios
    use netcdf
    implicit none
    include "mpif.h"

    !> @brief Structure to store the coupling configuration. 
    !! To load these informations, we exploit xios routines
    !! which provide an easy way to retrieve variables at runtime for our toymodels.
    !! 
    !! @param start_date Start date of the simulation
    !! @param end_date End date of the simulation
    !! @param curr_date Current date of the simulation
    !! @param timestep Timestep of the simulation
    !! @param duration Duration of the simulation
    !! @param freq_op_in_ts Frequency of operations in timesteps
    !! @param grids_filename Filename of the grid file
    !! @param masks_filename Filename of the mask file
    !! @param areas_filename Filename of the area file
    !! @param src_domain Source domain name in files (e.g., "bggd", "nogt", ..)
    !! @param dst_domain Destination domain name in files (e.g., "bggd", "nogt", ..)
    !! @param domain_mask Logical flag for applying domain mask
    type :: coupling_config
        type(xios_date) :: start_date, end_date, curr_date
        type(xios_duration) :: timestep, duration
        integer :: freq_op_in_ts
        character(len=255) :: grids_filename = ""
        character(len=255) :: masks_filename = ""
        character(len=255) :: areas_filename = ""
        character(len=255) :: domain = ""
        logical :: domain_mask = .true.
    end type coupling_config

    !> @brief Structure to store the field description globally and locally
    !!
    !! @param ni_glo Global number of points in i direction
    !! @param nj_glo Global number of points in j direction
    !! @param ncrn Number of corners for the grid
    !! @param ni Local number of points in i direction
    !! @param nj Local number of points in j direction
    !! @param ibegin Starting index in i direction
    !! @param jbegin Starting index in j direction
    !! @param lon Array of longitudes
    !! @param lat Array of latitudes
    !! @param mask Logical array for the mask
    type :: field_description
        integer :: ni_glo, nj_glo, ncrn, ni, nj, ibegin, jbegin
        double precision, allocatable :: lon(:)
        double precision, allocatable :: lat(:)
        logical, allocatable:: mask(:)
    end type field_description
contains

    !> @brief Initialize the domain based on the coupling configuration and domain type which could be the 
    !! source or the destination domain, in the coupling configuration.
    !! @param[in] local_comm MPI communicator of the model
    !! @param[in] domain_id Domain id of the tag in iodef.xml
    !! @param[in] cpl_conf Coupling configuration retrieved previously
    !! @param[in] cpl_conf_domain The content of variable "src_domain" or "dst_domain" in the coupling configuration
    !! @param[out] fd Description of the global and local distribution of the field
    subroutine init_domain(local_comm, domain_id, cpl_conf, cpl_conf_domain, fd)
        implicit none 
         
        integer, intent(in) :: local_comm
        character(len=*), intent(in) :: domain_id
        type(coupling_config), intent(in) :: cpl_conf
        character(len=255), intent(in) :: cpl_conf_domain
        type(field_description), intent(out) :: fd

        if (cpl_conf_domain == "icoh") then
            call init_domain_icos(local_comm, domain_id, cpl_conf, cpl_conf_domain, fd)
        else if (cpl_conf_domain == "t12e") then
            call init_domain_orca(local_comm, domain_id, cpl_conf, cpl_conf_domain, fd)
        else
            print *, "Unknown domain type: ", trim(cpl_conf_domain)
            stop 1
        end if

    end subroutine init_domain

    !> @brief Initialize a NOGT domain as it were a real mode, firstly calculating the distribution of data
    !! and then setting xios domain attributes.
    !! @param[in] local_comm MPI communicator of the model
    !! @param[in] domain_id Domain id of the tag in iodef.xml
    !! @param[in] cpl_conf Coupling configuration retrieved previously
    !! @param[in] cpl_conf_domain Identifier for the nogt grid to be loaded from grid file
    !! @param[out] fd Description of the local distribution of the field
    subroutine init_domain_orca(local_comm, domain_id, cpl_conf, cpl_conf_domain, fd)
        implicit none 
         
        integer, intent(in) :: local_comm
        character(len=*), intent(in) :: domain_id
        type(coupling_config), intent(in) :: cpl_conf
        character(len=255), intent(in) :: cpl_conf_domain
        type(field_description), intent(out) :: fd

        integer :: mpi_rank, mpi_size
        integer :: ierr

        ! Global variables to retrieve data from file in 2D
        double precision, pointer :: lon_glo2d(:,:), lat_glo2d(:,:)
        double precision, pointer :: clo_glo2d(:,:,:), cla_glo2d(:,:,:)
        integer, pointer :: msk_glo2d(:,:)
        double precision, pointer :: srf_glo2d(:,:)

        ! Local variables to calculate the local grids
        integer :: ni, nj, ni_glo, nj_glo, ncrn
        integer :: ibegin, jbegin
        double precision, allocatable :: lon2d(:,:), lat2d(:,:), srf_loc2d(:,:)
        double precision, allocatable :: bounds_lon(:,:,:), bounds_lat(:,:,:)
        logical, allocatable :: mask(:)
        integer :: nbp, nbp_glo, offset

        integer :: i, j, ij, ic
        integer :: base_rows, remainder
        integer :: nproc_i, nproc_j
        integer, allocatable :: size_i(:), begin_i(:), size_j(:), begin_j(:)
        integer :: r
        integer :: tmp

        ! Get MPI rank and size
        call mpi_comm_rank(local_comm, mpi_rank, ierr)
        call mpi_comm_size(local_comm, mpi_size, ierr)

        ! GRID, MASKS, AREAS READING from files
        call read_oasis_grid(cpl_conf, cpl_conf_domain, ni_glo, nj_glo, ncrn, lon_glo2d, lat_glo2d, clo_glo2d, cla_glo2d, msk_glo2d, srf_glo2d)

        ! Calculate the number of processes in each dimension
        nproc_j = int(sqrt(mpi_size * 1.0))
        do while (mod(mpi_size, nproc_j) /= 0)
            nproc_j = nproc_j - 1
        end do
        nproc_i = mpi_size / nproc_j

        ! Calculate size and starting indices for each process in i and j dimensions
        allocate(size_i(0:nproc_i-1), begin_i(0:nproc_i-1))
        do i = 0, nproc_i-1
            size_i(i) = ni_glo / nproc_i
            if (i < mod(ni_glo, nproc_i)) size_i(i) = size_i(i) + 1
            if (i == 0) then
                begin_i(i) = 0
            else
                begin_i(i) = begin_i(i-1) + size_i(i-1)
            end if
        end do

        allocate(size_j(0:nproc_j-1), begin_j(0:nproc_j-1))
        do j = 0, nproc_j-1
            size_j(j) = nj_glo / nproc_j
            if (j < mod(nj_glo, nproc_j)) size_j(j) = size_j(j) + 1
            if (j == 0) then
                begin_j(j) = 0
            else
                begin_j(j) = begin_j(j-1) + size_j(j-1)
            end if
        end do

        ! Determine local grid dimensions and starting indices
        r = 0
        do j = 0, nproc_j-1
            do i = 0, nproc_i-1
                if (mpi_rank == r) then
                    ibegin = begin_i(i)
                    ni = size_i(i)
                    jbegin = begin_j(j)
                    nj = size_j(j)
                end if
                r = r + 1
            end do
        end do

        ! Allocate local arrays
        allocate(mask(0:ni*nj-1))
        allocate(lon2d(0:ni-1, 0:nj-1), lat2d(0:ni-1, 0:nj-1))
        allocate(bounds_lon(ncrn, 0:ni-1, 0:nj-1))
        allocate(bounds_lat(ncrn, 0:ni-1, 0:nj-1))
        allocate(srf_loc2d(0:ni-1, 0:nj-1))

        ! Extract local domain values
        lon2d(:,:) = lon_glo2d(ibegin:ibegin+ni-1, jbegin:jbegin+nj-1)
        lat2d(:,:) = lat_glo2d(ibegin:ibegin+ni-1, jbegin:jbegin+nj-1)
#ifdef USE_SURFACE 
            srf_loc2d(:,:) = srf_glo2d(ibegin:ibegin+ni-1, jbegin:jbegin+nj-1)
#endif

        do j = 0, nj-1
            do i = 0, ni-1
                ij = i + j * ni
                mask(ij) = msk_glo2d(ibegin+i, jbegin+j) == 0
                do ic = 1, ncrn
                    bounds_lon(ic, i, j) = clo_glo2d(ibegin+i, jbegin+j, ic)
                    bounds_lat(ic, i, j) = cla_glo2d(ibegin+i, jbegin+j, ic)
                end do
            end do
        end do

        ! Set XIOS domain attributes
        if (xios_is_valid_domain(trim(domain_id))) then
            call xios_set_domain_attr(trim(domain_id), type="curvilinear", data_dim=2)
            call xios_set_domain_attr(trim(domain_id), ni_glo=ni_glo, nj_glo=nj_glo)
            call xios_set_domain_attr(trim(domain_id), ni=ni, nj=nj, ibegin=ibegin, jbegin=jbegin)
            call xios_set_domain_attr(trim(domain_id), lonvalue_2d=lon2d, latvalue_2d=lat2d)
            call xios_set_domain_attr(trim(domain_id), mask_1d=fd%mask)
            call xios_set_domain_attr(trim(domain_id), bounds_lon_2d=bounds_lon, bounds_lat_2d=bounds_lat, nvertex=ncrn)
#ifdef USE_SURFACE
            call xios_set_domain_attr(trim(domain_id), area=srf_loc2d)
#endif

            print *, "NOGT set in XIOS: ", trim(domain_id)
            print *, "ni_glo: ", ni_glo
            print *, "nj_glo: ", nj_glo
            print *, "ni: ", ni
            print *, "nj: ", nj
            print *, "ibegin: ", ibegin
            print *, "jbegin: ", jbegin
            print *, "ncrn: ", ncrn
        else
            print *, "Domain not found in XIOS: ", trim(domain_id), " at line ", __LINE__
        end if

        ! Populate field_description structure
        fd%lon = reshape(lon2d, [ni*nj])
        fd%lat = reshape(lat2d, [ni*nj])
        fd%mask = mask
        fd%ni_glo = ni_glo
        fd%nj_glo = nj_glo
        fd%ncrn = ncrn
        fd%ibegin = ibegin
        fd%jbegin = jbegin
        fd%ni = ni
        fd%nj = nj

        ! Deallocate global pointers
        deallocate(lon_glo2d, lat_glo2d, clo_glo2d, cla_glo2d, msk_glo2d, srf_glo2d)

    end subroutine init_domain_orca

    !> @brief Initialize an ICOS domain, distributing points among processes and setting XIOS domain attributes.
    !! @param[in] local_comm MPI communicator of the model
    !! @param[in] domain_id Domain id of the tag in iodef.xml
    !! @param[in] cpl_conf Coupling configuration retrieved previously
    !! @param[in] cpl_conf_domain Identifier for the icos grid to be loaded from grid file
    !! @param[out] fd Description of the local distribution of the field
    subroutine init_domain_icos(local_comm, domain_id, cpl_conf, cpl_conf_domain, fd)
        implicit none

        integer, intent(in) :: local_comm
        character(len=*), intent(in) :: domain_id
        type(coupling_config), intent(in) :: cpl_conf
        character(len=255), intent(in) :: cpl_conf_domain
        type(field_description), intent(out) :: fd

        integer :: mpi_rank, mpi_size
        integer :: ierr

        double precision, pointer :: lon_glo2d(:,:), lat_glo2d(:,:)
        double precision, pointer :: clo_glo2d(:,:,:), cla_glo2d(:,:,:)
        integer, pointer :: msk_glo2d(:,:)
        double precision, pointer :: srf_glo2d(:,:)

        integer :: ni_glo, nj_glo, ncrn
        integer :: nbp, nbp_glo, offset
        integer :: i, ic

        double precision, allocatable :: lon(:), lat(:), srf_loc2d(:,:)
        double precision, allocatable :: bounds_lon(:,:), bounds_lat(:,:)
        logical, allocatable :: mask(:)

        ! Get MPI rank and size
        call mpi_comm_rank(local_comm, mpi_rank, ierr)
        call mpi_comm_size(local_comm, mpi_size, ierr)

        ! Read grid, mask, and area files
        call read_oasis_grid(cpl_conf, cpl_conf_domain, ni_glo, nj_glo, ncrn, &
            lon_glo2d, lat_glo2d, clo_glo2d, cla_glo2d, msk_glo2d, srf_glo2d)

        ! ICOS grid is 1D (ni_glo points, nj_glo=1)
        nbp_glo = ni_glo
        nbp = nbp_glo / mpi_size
        if (mpi_rank < mod(nbp_glo, mpi_size)) then
            nbp = nbp + 1
            offset = nbp * mpi_rank
        else
            offset = (nbp + 1) * mod(nbp_glo, mpi_size) + nbp * (mpi_rank - mod(nbp_glo, mpi_size))
        end if

        allocate(lon(0:nbp-1))
        allocate(lat(0:nbp-1))
        allocate(bounds_lon(ncrn,0:nbp-1))
        allocate(bounds_lat(ncrn,0:nbp-1))
        allocate(mask(0:nbp-1))
        allocate(srf_loc2d(0:0,0:nbp-1))

        do i = 0, nbp-1
            lat(i) = lat_glo2d(i+offset,0)
            lon(i) = lon_glo2d(i+offset,0)
            do ic = 1, ncrn
                bounds_lon(ic,i) = clo_glo2d(i+offset,0,ic)
                bounds_lat(ic,i) = cla_glo2d(i+offset,0,ic)
            end do
            mask(i) = msk_glo2d(i+offset,0) == 0
#ifdef USE_SURFACE 
                srf_loc2d(0,i) = srf_glo2d(i+offset,0)
#endif 
        end do

        ! Set XIOS domain attributes
        if (xios_is_valid_domain(trim(domain_id))) then
            call xios_set_domain_attr(trim(domain_id), type="unstructured", data_dim=1)
            call xios_set_domain_attr(trim(domain_id), ni_glo=ni_glo, nj_glo=1)
            call xios_set_domain_attr(trim(domain_id), ni=nbp, nj=1, ibegin=offset, jbegin=0)
            call xios_set_domain_attr(trim(domain_id), lonvalue_1d=lon, latvalue_1d=lat, mask_1d=mask)
            call xios_set_domain_attr(trim(domain_id), bounds_lon_1d=bounds_lon, bounds_lat_1d=bounds_lat, nvertex=ncrn)
#ifdef USE_SURFACE 
                call xios_set_domain_attr(trim(domain_id), area=srf_loc2d)
#endif
            call xios_set_domain_attr(trim(domain_id), radius=1.0_8)

            print *, "ICOS set in XIOS: ", trim(domain_id)
            print *, "ni_glo: ", ni_glo
            print *, "nj_glo: ", 1
            print *, "ni: ", nbp
            print *, "nj: ", 1
            print *, "ibegin: ", offset
            print *, "jbegin: ", 0
            print *, "ncrn: ", ncrn
        else
            print *, "Domain not found in XIOS: ", trim(domain_id), " at line ", __LINE__
        end if

        ! Populate field_description structure
        fd%lon = lon
        fd%lat = lat
        fd%mask = mask
        fd%ni_glo = ni_glo
        fd%nj_glo = 1
        fd%ncrn = ncrn
        fd%ibegin = offset
        fd%jbegin = 0
        fd%ni = nbp
        fd%nj = 1

        ! Deallocate global pointers
        deallocate(lon_glo2d, lat_glo2d, clo_glo2d, cla_glo2d, msk_glo2d, srf_glo2d)
        deallocate(lon, lat, srf_loc2d, bounds_lon, bounds_lat, mask)

    end subroutine init_domain_icos

    !> @brief Initialize a BGGD domain as it were a real mode, firstly calculating the diustribution of data
    !! and then setting xios domain attributes. 
    !! @param[in] local_comm MPI communicator of the model
    !! @param[in] domain_id Domain id of the tag in iodef.xml
    !! @param[in] cpl_conf Coupling configuration retrieved previously
    !! @param[in] file_domain_id Identifier for the bggd grid to be loaded from grid file
    !! @param[out] fd Description of the local distribution of the field
    subroutine init_domain_bggd(local_comm, domain_id, cpl_conf, file_domain_id, fd)
        implicit none 

        integer, intent(in) :: local_comm
        character(len=*), intent(in) :: domain_id
        type(coupling_config), intent(in) :: cpl_conf
        character(len=255), intent(in) :: file_domain_id
        type(field_description), intent(out), optional :: fd

        ! Model mpi communicator
        integer :: mpi_rank, mpi_size
        integer ::  ierr

        ! Global variables to retrieve data from file in 2D
        double precision, pointer :: lon_glo2d(:,:), lat_glo2d(:,:)
        double precision, pointer :: clo_glo2d(:,:,:), cla_glo2d(:,:,:)
        integer, pointer :: msk_glo2d(:,:)
        double precision, pointer :: srf_glo2d(:,:)

        ! Local variables to calculate the local grids
        integer :: ni,nj,ni_glo,nj_glo, ncrn
        integer :: ibegin,jbegin
        double precision, allocatable :: lon2d(:,:), lat2d(:,:), srf_loc2d(:,:)
        double precision, allocatable :: bounds_lon(:,:,:), bounds_lat(:,:,:)
        logical,allocatable :: mask(:)
        logical,allocatable :: dom_mask(:)
        integer :: nbp,nbp_glo,offset

        integer :: i,j,ij,ic
        integer :: base_rows, remainder
        ! ------------------------------------------------------------------------------

        call mpi_comm_rank(local_comm,mpi_rank,ierr)
        call mpi_comm_size(local_comm,mpi_size,ierr)
       
        ! GRID, MASKS, AREAS READING from files
        call read_oasis_grid(cpl_conf, file_domain_id, ni_glo, nj_glo, ncrn, lon_glo2d, lat_glo2d, clo_glo2d, cla_glo2d, msk_glo2d, srf_glo2d)

        ! Calculating distribuition parameters ROW MAJOR --------------------------------

        ! Compute base number of rows per process
        base_rows = nj_glo / mpi_size ! Rows per process
        remainder = mod(nj_glo, mpi_size) ! Remaining rows
        nbp_glo = ni_glo*nj_glo ! Total number of points

        ! Local number of rows (nj) and starting row index (jbegin)
        if (mpi_rank < remainder) then
            nj = base_rows + 1 
            jbegin = mpi_rank * nj
        else
            nj = base_rows
            jbegin = base_rows * mpi_rank + remainder ! Starting local row index
        end if

        nbp = ni_glo * nj ! Local number of points

        ! Local full width as global
        ni = ni_glo
        ibegin = 0

        ! Row-major offset to first local element
        offset = jbegin * ni_glo + ibegin

        allocate(mask(0:ni*nj-1), dom_mask(0:ni*nj-1))
        allocate(lon2d(0:ni-1,0:nj-1), lat2d(0:ni-1,0:nj-1))

        ! Extract local domain values of longitude and latitude (2D arrays)
        lon2d(:,:)=lon_glo2d(ibegin:ibegin+ni-1,jbegin:jbegin+nj-1)
        lat2d(:,:)=lat_glo2d(ibegin:ibegin+ni-1,jbegin:jbegin+nj-1)

        ! Allocate space for the bounds of longitude and latitude
        !   (1st dimension is the number of corners)
        !   (2nd and 3rd dimensions are the local grid)
        allocate(bounds_lon(ncrn,0:ni-1,0:nj-1))
        allocate(bounds_lat(ncrn,0:ni-1,0:nj-1))
        ! Allocate space for the local grid surface values
        allocate(srf_loc2d(0:ni-1,0:nj-1))

        ! Extract local domain values of areas of the local grid
#ifdef USE_SURFACE 
            srf_loc2d(:,:)=srf_glo2d(ibegin:ibegin+ni-1,jbegin:jbegin+nj-1)
#endif

        ! Monodimensional arrays for the local grid
        allocate(fd%lon(0:ni*nj-1))
        allocate(fd%lat(0:ni*nj-1))
        allocate(fd%mask(0:ni*nj-1))

        do j=0,nj-1
            do i=0,ni-1
                ij = i+j*ni

                ! 2D to 1D points definitions array
                fd%lon(ij)=lon_glo2d(ibegin+i,jbegin+j)
                fd%lat(ij)=lat_glo2d(ibegin+i,jbegin+j)

                ! Local domain mask from global one
                fd%mask(ij) = msk_glo2d(ibegin+i,jbegin+j) == 0 

                ! For each corner of the rectangle 
                do ic = 1, ncrn
                    ! Extract local domain values of bounds of longitude and latitude
                    bounds_lon(ic,i,j) = clo_glo2d(ibegin+i,jbegin+j,ic)
                    bounds_lat(ic,i,j) = cla_glo2d(ibegin+i,jbegin+j,ic)
                end do
            enddo
        enddo

        fd%ni_glo=ni_glo
        fd%nj_glo=nj_glo
        fd%ncrn=ncrn
        fd%ibegin=ibegin
        fd%jbegin=jbegin
        fd%ni=ni
        fd%nj=nj


        if (xios_is_valid_domain(trim(domain_id))) then
            call xios_set_domain_attr(trim(domain_id), type="rectilinear", data_dim=2)
            call xios_set_domain_attr(trim(domain_id), ni_glo=ni_glo, nj_glo=nj_glo)
            call xios_set_domain_attr(trim(domain_id), ni=ni, nj=nj, ibegin=ibegin, jbegin=jbegin)
            call xios_set_domain_attr(trim(domain_id), lonvalue_2d=lon2d, latvalue_2d=lat2d)
            call xios_set_domain_attr(trim(domain_id), mask_1d=fd%mask)
            call xios_set_domain_attr(trim(domain_id), bounds_lon_2d=bounds_lon, bounds_lat_2d=bounds_lat, nvertex=ncrn)
#ifdef USE_SURFACE 
                call xios_set_domain_attr(trim(domain_id), area=srf_loc2d)
#endif
            call xios_set_domain_attr(trim(domain_id), radius=1.0_8)

            print *, "BGGD setted in XIOS: ", trim(domain_id)
            print *, "ni_glo: ", ni_glo
            print *, "nj_glo: ", nj_glo
            print *, "ni: ", ni
            print *, "nj: ", nj
            print *, "ibegin: ", ibegin
            print *, "jbegin: ", jbegin
            print *, "ncrn: ", ncrn


        else
            print *, "Domain not found in XIOS: ", trim(domain_id), " at line ", __LINE__
        end if

        ! Deallocating pointers 
        deallocate(lon_glo2d, lat_glo2d, clo_glo2d, cla_glo2d, msk_glo2d, srf_glo2d)

   end subroutine init_domain_bggd

    !> @brief Read the grid, mask and area files to get the global grid information
    !! @param[in] cpl_conf Coupling configuration retrieved previously
    !! @param[in] cpl_conf_domain Identifier for the grid to be loaded from grid file
    !! @param[out] ni_glo Global number of points in i direction
    !! @param[out] nj_glo Global number of points in j direction
    !! @param[out] ncrn Number of corners for the grid
    !! @param[out] lon_glo2d 2D array of longitudes
    !! @param[out] lat_glo2d 2D array of latitudes
    !! @param[out] clo_glo2d 3D array of longitudes for corners
    !! @param[out] cla_glo2d 3D array of latitudes for corners
    !! @param[out] msk_glo2d 2D array of masks
    !! @param[out] srf_glo2d 2D array of surface values
    subroutine read_oasis_grid(cpl_conf, cpl_conf_domain,  ni_glo, nj_glo, ncrn,&
      & lon_glo2d, lat_glo2d, clo_glo2d, cla_glo2d, msk_glo2d, srf_glo2d)
      implicit none 
      type(coupling_config), intent(in) :: cpl_conf
      character(len=*), intent(in) :: cpl_conf_domain
      integer, intent(out) :: ni_glo, nj_glo, ncrn
      double precision, pointer :: lon_glo2d(:,:), lat_glo2d(:,:)
      double precision, pointer :: clo_glo2d(:,:,:), cla_glo2d(:,:,:)
      integer, pointer :: msk_glo2d(:,:)
      double precision, pointer :: srf_glo2d(:,:) 
      ! local variables
      integer ::  ierr
      character(len=256) :: grid_filename
      character(len=256) :: mask_filename
      character(len=256) :: surf_filename
      character(len=8)           :: cl_nam ! cl_grd+.lon,+.lat ...
      integer :: il_file_id, il_lon_id, il_lat_id, il_clo_id, il_cla_id
      integer :: il_msk_id, il_srf_id
      integer :: lon_dims, lat_dims
      integer, dimension(nf90_max_var_dims) :: lon_dims_ids,lat_dims_ids
      integer, dimension(nf90_max_var_dims) :: lon_dims_len,lat_dims_len
      integer :: i
      integer,  dimension(:), allocatable   :: ila_dim, ila_what
      character(len=256) :: domain 
      domain = trim(cpl_conf_domain)
      grid_filename = trim(cpl_conf%grids_filename)
      mask_filename = trim(cpl_conf%masks_filename)
      surf_filename = trim(cpl_conf%areas_filename)

    call handle_f90err(nf90_open(trim(grid_filename), nf90_nowrite, il_file_id), __LINE__)
    cl_nam = trim(domain)//".lon"
    print *, "cl_nam: ", cl_nam
    call handle_f90err(nf90_inq_varid(il_file_id, cl_nam,  il_lon_id), __LINE__)
    call handle_f90err(nf90_inquire_variable(il_file_id, varid=il_lon_id, ndims=lon_dims, dimids=lon_dims_ids), __LINE__)
    do i=1,lon_dims
       call handle_f90err(nf90_inquire_dimension(ncid=il_file_id,dimid=lon_dims_ids(i),len=lon_dims_len(i)), __LINE__)
    enddo
    ni_glo=lon_dims_len(1)
    nj_glo=lon_dims_len(2)

    cl_nam = trim(domain)//".lat"
    call handle_f90err(nf90_inq_varid(il_file_id, cl_nam,  il_lat_id), __LINE__)
    call handle_f90err(nf90_inquire_variable(il_file_id, varid=il_lat_id, ndims=lat_dims, dimids=lat_dims_ids), __LINE__)
    do i=1,lat_dims
       call handle_f90err(nf90_inquire_dimension(ncid=il_file_id,dimid=lat_dims_ids(i),len=lat_dims_len(i)), __LINE__)
    enddo
    allocate(lon_glo2d(0:ni_glo-1,0:nj_glo-1), lat_glo2d(0:ni_glo-1,0:nj_glo-1))
    allocate(ila_what(2), ila_dim(2))
    ila_what(:)=1
    ila_dim(:)=[ni_glo, nj_glo]
    call handle_f90err(nf90_get_var (il_file_id, il_lon_id, lon_glo2d(0:ni_glo-1,0:nj_glo-1), ila_what, ila_dim), __LINE__)
    call handle_f90err(nf90_get_var (il_file_id, il_lat_id, lat_glo2d(0:ni_glo-1,0:nj_glo-1), ila_what, ila_dim), __LINE__)
    deallocate(ila_what, ila_dim)

    cl_nam = trim(domain)//".clo"
    call handle_f90err(nf90_inq_varid(il_file_id, cl_nam,  il_clo_id), __LINE__)
    call handle_f90err(nf90_inquire_variable(il_file_id, varid=il_clo_id, ndims=lon_dims, dimids=lon_dims_ids), __LINE__)
    do i=1,lon_dims
       call handle_f90err(nf90_inquire_dimension(ncid=il_file_id,dimid=lon_dims_ids(i),len=lon_dims_len(i)), __LINE__)
    enddo
    ncrn=lon_dims_len(3)

    cl_nam = trim(domain)//".cla"
    call handle_f90err(nf90_inq_varid(il_file_id, cl_nam,  il_cla_id), __LINE__)
    call handle_f90err(nf90_inquire_variable(il_file_id, varid=il_lat_id, ndims=lat_dims, dimids=lat_dims_ids), __LINE__)
    do i=1,lat_dims
       call handle_f90err(nf90_inquire_dimension(ncid=il_file_id,dimid=lat_dims_ids(i),len=lat_dims_len(i)), __LINE__)
    enddo

    allocate(clo_glo2d(0:ni_glo-1,0:nj_glo-1,ncrn), cla_glo2d(0:ni_glo-1,0:nj_glo-1,ncrn))
    allocate(ila_what(3), ila_dim(3))
    ila_what(:)=1
    ila_dim(:)=[ni_glo, nj_glo, ncrn]
    call handle_f90err(nf90_get_var (il_file_id, il_clo_id, clo_glo2d(0:ni_glo-1,0:nj_glo-1,1:ncrn), ila_what, ila_dim), __LINE__)
    call handle_f90err(nf90_get_var (il_file_id, il_cla_id, cla_glo2d(0:ni_glo-1,0:nj_glo-1,1:ncrn), ila_what, ila_dim), __LINE__)
    deallocate(ila_what, ila_dim)

    call handle_f90err(nf90_close(il_file_id), __LINE__)

    call handle_f90err(nf90_open(trim(mask_filename), nf90_nowrite, il_file_id), __LINE__)
    cl_nam = trim(domain)//".msk"
    call handle_f90err(nf90_inq_varid(il_file_id, cl_nam,  il_msk_id), __LINE__)
    allocate(msk_glo2d(0:ni_glo-1,0:nj_glo-1))
    allocate(ila_what(2), ila_dim(2))
    ila_what(:)=1
    ila_dim(:)=[ni_glo, nj_glo]
    call handle_f90err(nf90_get_var (il_file_id, il_msk_id, msk_glo2d(0:ni_glo-1,0:nj_glo-1), ila_what, ila_dim), __LINE__)
    deallocate(ila_what, ila_dim)
    call handle_f90err(nf90_close(il_file_id), __LINE__)

    allocate(srf_glo2d(0:ni_glo-1,0:nj_glo-1))
#ifdef USE_SURFACE
    call handle_f90err(nf90_open(trim(surf_filename), nf90_nowrite, il_file_id), __LINE__)
    cl_nam = trim(domain)//".srf"
    call handle_f90err(nf90_inq_varid(il_file_id, cl_nam,  il_srf_id), __LINE__)
    allocate(ila_what(2), ila_dim(2))
    ila_what(:)=1
    ila_dim(:)=[ni_glo, nj_glo]
    print *, "ila_dim: ", ila_dim, "ila_what: ", ila_what, "ni_glo: ", ni_glo, "nj_glo: ", nj_glo
    call handle_f90err(nf90_get_var (il_file_id, il_srf_id, srf_glo2d(0:ni_glo-1,0:nj_glo-1), ila_what, ila_dim), __LINE__)
    deallocate(ila_what, ila_dim)
    call handle_f90err(nf90_close(il_file_id), __LINE__)
#endif
    end subroutine read_oasis_grid

    ! --------------------------------------------------------------------------

    !> @brief Handle errors from NetCDF Fortran API
    subroutine handle_f90err(status, line)
        implicit none
        integer, intent ( in) :: status, line
        if(status /= nf90_noerr) then
        print *, trim(nf90_strerror(status)) , " at line ", line 
        stop "Stopped"
        end if
    end subroutine handle_f90err   

    !> @brief Handle errors from XIOS API
    subroutine handle_xioserr(func, msg)
        implicit none
        integer, intent(in) :: func
        character(len=*), intent(in) :: msg
        if (func /= -1) then
            print *, msg
            stop 1
        end if
    end subroutine handle_xioserr



end module grids_utils

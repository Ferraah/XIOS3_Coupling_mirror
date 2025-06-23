program test_loadgrid
    use grids_utils
    type(coupling_config) :: params

    integer :: ni_glo, nj_glo, ncrn
    double precision, pointer :: lon_glo2d(:,:), lat_glo2d(:,:)
    double precision, pointer :: clo_glo2d(:,:,:), cla_glo2d(:,:,:)
    integer, pointer :: msk_glo2d(:,:)
    double precision, pointer :: srf_glo2d(:,:)
    integer :: comm = MPI_COMM_WORLD
    type(field_description) :: fd

    params%grids_filename = "../grids.nc"
    params%masks_filename = "../masks.nc"
    params%areas_filename = "../areas.nc"
    params%src_domain = "bggd"
    params%dst_domain = "nogt"
    
    call mpi_init()
    call init_domain_orca_noxios(comm, "domain", params, params%src_domain, fd)

contains

    subroutine init_domain_orca_noxios(local_comm, domain_id, cpl_conf, cpl_conf_domain, fd)
        implicit none 
        
        integer, intent(in) :: local_comm
        character(len=*), intent(in) :: domain_id
        type(coupling_config), intent(in) :: cpl_conf
        character(len=255), intent(in) :: cpl_conf_domain
        type(field_description), intent(out) :: fd

        integer :: mpi_rank, mpi_size
        integer :: ierr

        ! Local variables to retrieve data from file in 2D
        double precision, pointer :: lon_glo2d(:,:), lat_glo2d(:,:)
        double precision, pointer :: clo_glo2d(:,:,:), cla_glo2d(:,:,:)
        integer, pointer :: msk_glo2d(:,:)
        double precision, pointer :: srf_glo2d(:,:)

        ! Local variables to calculate the local grids
        integer :: ni, nj, ni_glo, nj_glo, ncrn
        integer :: ibegin, jbegin
        integer :: offset_i, offset_j
        double precision, allocatable :: lon(:,:), lat(:,:), bounds_lon(:,:,:), bounds_lat(:,:,:), srf_loc2d(:,:)
        logical, allocatable :: mask(:)
        logical, allocatable :: dom_mask(:)
        double precision, allocatable :: return_lon(:), return_lat(:)
        logical, allocatable :: return_mask(:)
        integer, allocatable :: return_index(:)
        integer :: i, j, ij, ic
        integer :: nproc_i, nproc_j
        integer :: r
        integer, allocatable :: size_i(:), begin_i(:), size_j(:), begin_j(:)

        call mpi_comm_rank(local_comm, mpi_rank, ierr)
        call mpi_comm_size(local_comm, mpi_size, ierr)

        ! Call read_oasis_grid to get the global grid, mask and surface from files defined in config
        call read_oasis_grid(cpl_conf, cpl_conf_domain, ni_glo, nj_glo, ncrn, lon_glo2d, lat_glo2d, clo_glo2d, cla_glo2d, msk_glo2d, srf_glo2d)

        ! Calculate the number of processes in each dimension

        nproc_j = int(sqrt(mpi_size * 1.0))
        do while (mod(mpi_size, nproc_j) /= 0)
            nproc_j = nproc_j - 1
        end do
        nproc_i = mpi_size/ nproc_j


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
        offset_i = 2    ! halo of 2 on i
        offset_j = 1    ! halo of 1 on j

        allocate(lon(0:ni-1, 0:nj-1))
        allocate(lat(0:ni-1, 0:nj-1))
        allocate(bounds_lon(ncrn, 0:ni-1, 0:nj-1))
        allocate(bounds_lat(ncrn, 0:ni-1, 0:nj-1))
        allocate(srf_loc2d(0:ni-1, 0:nj-1))

        allocate(return_lon(0:ni*nj-1))
        allocate(return_lat(0:ni*nj-1))
        allocate(return_mask(0:ni*nj-1))
        allocate(return_index(0:(ni+2*offset_i)*(nj+2*offset_j)-1))

        return_index = -1
        do j = 0, nj-1
            do i = 0, ni-1
                ij = j * ni + i
                return_lon(ij) = lon_glo2d(ibegin+i, jbegin+j)
                return_lat(ij) = lat_glo2d(ibegin+i, jbegin+j)
                return_mask(ij) = msk_glo2d(ibegin+i, jbegin+j) == 0
                srf_loc2d(i, j) = srf_glo2d(ibegin+i, jbegin+j)
                lon(i, j) = return_lon(ij)
                lat(i, j) = return_lat(ij)
                do ic = 1, ncrn
                    bounds_lon(ic, i, j) = clo_glo2d(ibegin+i, jbegin+j, ic)
                    bounds_lat(ic, i, j) = cla_glo2d(ibegin+i, jbegin+j, ic)
                end do

                ij = (j+offset_j) * (ni+2*offset_i) + i + offset_i
                return_index(ij) = i + j * ni
            end do
        end do

        ! if (xios_is_valid_domain(trim(domain_id))) then
        !     call xios_set_domain_attr(trim(domain_id), type="curvilinear", data_dim=2)
        !     call xios_set_domain_attr(trim(domain_id), ni_glo=ni_glo, nj_glo=nj_glo)
        !     call xios_set_domain_attr(trim(domain_id), ni=ni, nj=nj, ibegin=ibegin, jbegin=jbegin)
        !     call xios_set_domain_attr(trim(domain_id), lonvalue_2d=lon, latvalue_2d=lat)
        !     call xios_set_domain_attr(trim(domain_id), bounds_lon_2d=bounds_lon, bounds_lat_2d=bounds_lat, nvertex=ncrn)
        !     call xios_set_domain_attr(trim(domain_id), area=srf_loc2d)
        !     call xios_set_domain_attr(trim(domain_id), radius=1.0_8)
        ! end if

        fd%lon = return_lon
        fd%lat = return_lat
        fd%mask = return_mask
        fd%indices = return_index
        fd%ni_glo = ni_glo
        fd%nj_glo = nj_glo
        fd%ncrn = ncrn
        fd%ibegin = ibegin
        fd%jbegin = jbegin
        fd%ni = ni
        fd%nj = nj

        
        deallocate(lon, lat, bounds_lon, bounds_lat, srf_loc2d, size_i, begin_i, size_j, begin_j)
    end subroutine init_domain_orca_noxios
end program test_loadgrid
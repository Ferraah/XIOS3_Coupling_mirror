module grids_utils
    use xios
    use netcdf
    implicit none
    include "mpif.h"

    type :: coupling_config
        type(xios_date) :: start_date, end_date, curr_date
        type(xios_duration) :: timestep, duration
        integer :: freq_op_in_ts
        character(len=255) :: field_type = "" 
        character(len=255) :: grids_filename = ""
        character(len=255) :: masks_filename = ""
        character(len=255) :: areas_filename = ""
        character(len=255) :: src_domain = ""
        character(len=255) :: dst_domain = ""
        logical :: domain_mask = .true.
    end type coupling_config

    type :: field_description
        integer :: ni_glo, nj_glo, ncrn, ni, nj, ibegin, jbegin
        double precision, pointer :: lon(:)
        double precision, pointer :: lat(:)
        logical, pointer :: mask(:)
        integer, pointer :: indices(:)
    end type field_description
contains
    subroutine init_domain_src(local_comm, domain_id, cpl_conf, fd)
        implicit none 
         
        integer, intent(in) :: local_comm
        character(len=*), intent(in) :: domain_id
        type(coupling_config), intent(in) :: cpl_conf
        type(field_description), intent(out) :: fd

        call init_domain(local_comm, domain_id, cpl_conf, cpl_conf%src_domain,  fd)
    end subroutine init_domain_src

    subroutine init_domain_dst(local_comm, domain_id, cpl_conf, fd)
        implicit none 
        
        integer, intent(in) :: local_comm
        character(len=*), intent(in) :: domain_id
        type(coupling_config), intent(in) :: cpl_conf
        type(field_description), intent(out) :: fd

        call init_domain(local_comm, domain_id, cpl_conf, cpl_conf%dst_domain,  fd)
    end subroutine init_domain_dst


    subroutine init_domain(local_comm, domain_id, cpl_conf, cpl_conf_domain, fd)
        implicit none 
         
        integer, intent(in) :: local_comm
        character(len=*), intent(in) :: domain_id
        type(coupling_config), intent(in) :: cpl_conf
        character(len=255), intent(in) :: cpl_conf_domain
        type(field_description), intent(out) :: fd

        if (cpl_conf_domain == "bggd") then
            call init_domain_bggd(local_comm, domain_id, cpl_conf, cpl_conf_domain, fd)
        else if (cpl_conf_domain == "nogt") then
            call init_domain_orca(local_comm, domain_id, cpl_conf, cpl_conf_domain, fd)
        else
            print *, "Unknown field type: ", cpl_conf%field_type
            stop 1
        end if

    end subroutine init_domain

    subroutine init_domain_orca(local_comm, domain_id, cpl_conf, cpl_conf_domain, fd)
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

        if (xios_is_valid_domain(trim(domain_id))) then
            call xios_set_domain_attr(trim(domain_id), type="curvilinear", data_dim=2)
            call xios_set_domain_attr(trim(domain_id), ni_glo=ni_glo, nj_glo=nj_glo)
            call xios_set_domain_attr(trim(domain_id), ni=ni, nj=nj, ibegin=ibegin, jbegin=jbegin)
            call xios_set_domain_attr(trim(domain_id), lonvalue_2d=lon, latvalue_2d=lat)
            call xios_set_domain_attr(trim(domain_id), bounds_lon_2d=bounds_lon, bounds_lat_2d=bounds_lat, nvertex=ncrn)
            call xios_set_domain_attr(trim(domain_id), area=srf_loc2d)
            call xios_set_domain_attr(trim(domain_id), radius=1.0_8)
        end if

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
    end subroutine init_domain_orca


    subroutine init_domain_bggd(local_comm, domain_id, cpl_conf, cpl_conf_domain, fd)
        implicit none 

        integer, intent(in) :: local_comm
        character(len=*), intent(in) :: domain_id
        type(coupling_config), intent(in) :: cpl_conf
        character(len=255), intent(in) :: cpl_conf_domain
        type(field_description), intent(out) :: fd

        integer :: mpi_rank, mpi_size
        integer ::  ierr

        ! Local variables to retrieve data from file in 2D
        double precision, pointer :: lon_glo2d(:,:), lat_glo2d(:,:)
        double precision, pointer :: clo_glo2d(:,:,:), cla_glo2d(:,:,:)
        integer, pointer :: msk_glo2d(:,:)
        double precision, pointer :: srf_glo2d(:,:)

        ! Local variables to calculate the local grids
        integer :: ni,nj,ni_glo,nj_glo, ncrn
        integer :: ibegin,jbegin
        integer :: nbp,nbp_glo, offset
        double precision, allocatable :: lon2d(:,:), lat2d(:,:), srf_loc2d(:,:)
        double precision, allocatable :: bounds_lon(:,:,:), bounds_lat(:,:,:)
        logical,allocatable :: mask(:)
        logical,allocatable :: dom_mask(:)
        integer :: i,j,ij,ic
        integer :: base_rows, remainder

        double precision, allocatable :: return_lon(:), return_lat(:)
        logical, allocatable :: return_mask(:)
        integer, allocatable :: return_index(:)
        ! ------------------------------------------------------------------------------

        ! Call read_oasis_grid to get the global grid, mask and surface from files defined in config
        call read_oasis_grid(cpl_conf, cpl_conf_domain, ni_glo, nj_glo, ncrn, lon_glo2d, lat_glo2d, clo_glo2d, cla_glo2d, msk_glo2d, srf_glo2d)

        
        call mpi_comm_rank(local_comm,mpi_rank,ierr)
        call mpi_comm_size(local_comm,mpi_size,ierr)

        ! Calculating distribuition parameters ROW MAJOR ------------------------

        ! Compute base number of rows per process
        base_rows = nj_glo / mpi_size
        remainder = mod(nj_glo, mpi_size)

        ! Local number of rows (nj) and starting row index (jbegin)
        if (mpi_rank < remainder) then
            nj = base_rows + 1
            jbegin = mpi_rank * (base_rows + 1)
        else
            nj = base_rows
            jbegin = remainder * (base_rows + 1) + (mpi_rank- remainder) * base_rows
        end if

        ! Local full width
        ni = ni_glo
        ibegin = 0

        ! Row-major offset to first local element
        offset = jbegin * ni_glo + ibegin

        !!  ------------------------------------------------------------------

        allocate(mask(0:ni*nj-1), dom_mask(0:ni*nj-1))
        allocate(lon2d(0:ni-1,0:nj-1), lat2d(0:ni-1,0:nj-1))

        ! Mark which are the points of the local grid
        mask(:)=.false.
        mask(offset:offset+nbp-1)=.true.

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
        srf_loc2d(:,:)=srf_glo2d(ibegin:ibegin+ni-1,jbegin:jbegin+nj-1)

        ! Monodimensional arrays for the local grid
        allocate(return_lon(0:ni*nj-1))
        allocate(return_lat(0:ni*nj-1))
        allocate(return_mask(0:ni*nj-1))
        allocate(return_index(0:ni*nj-1))

        do j=0,nj-1
            do i=0,ni-1
                ij = i+j*ni

                ! 2D to 1D points definitions array
                return_lon(ij)=lon_glo2d(ibegin+i,jbegin+j)
                return_lat(ij)=lat_glo2d(ibegin+i,jbegin+j)
                ! Local domain mask from global one
                dom_mask(ij) = msk_glo2d(ibegin+i,jbegin+j) == 0 
                return_index(ij)=ij

                ! For each corner of the rectangle 
                do ic = 1, ncrn
                    ! Extract local domain values of bounds of longitude and latitude
                    bounds_lon(ic,i,j) = clo_glo2d(ibegin+i,jbegin+j,ic)
                    bounds_lat(ic,i,j) = cla_glo2d(ibegin+i,jbegin+j,ic)
                end do
            enddo
        enddo

        
        ! @TODO
        return_mask = mask .and. dom_mask
        if ( .not. cpl_conf%domain_mask ) return_mask = mask



        if (xios_is_valid_domain(trim(domain_id))) then
            call xios_set_domain_attr(trim(domain_id), type="rectilinear", data_dim=2)
            call xios_set_domain_attr(trim(domain_id), ni_glo=ni_glo, nj_glo=nj_glo)
            call xios_set_domain_attr(trim(domain_id), ni=ni, nj=nj, ibegin=ibegin, jbegin=jbegin)
            call xios_set_domain_attr(trim(domain_id), lonvalue_2d=lon2d, latvalue_2d=lat2d)
            call xios_set_domain_attr(trim(domain_id), bounds_lon_2d=bounds_lon, bounds_lat_2d=bounds_lat, nvertex=ncrn)
            ! @TODO: to set only if receiver
            ! call xios_set_domain_attr(trim(domain_id), area=srf_loc2d)
            ! call xios_set_domain_attr(trim(domain_id), radius=1.0_8)
        end if

        fd%lon=return_lon
        fd%lat=return_lat
        fd%mask=return_mask
        fd%indices=return_index
        fd%ni_glo=ni_glo
        fd%nj_glo=nj_glo
        fd%ncrn=ncrn
        fd%ibegin=ibegin
        fd%jbegin=jbegin
        fd%ni=ni
        fd%nj=nj

        deallocate(lon2d, lat2d, srf_loc2d, bounds_lon, bounds_lat, mask, dom_mask)
        
   end subroutine init_domain_bggd

   
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

      call handle_f90err(nf90_open(trim(grid_filename), nf90_nowrite, il_file_id))
      cl_nam = trim(domain)//".lon"
      print *, "cl_nam: ", cl_nam
      call handle_f90err(nf90_inq_varid(il_file_id, cl_nam,  il_lon_id))
      call handle_f90err(nf90_inquire_variable(il_file_id, varid=il_lon_id, ndims=lon_dims, dimids=lon_dims_ids))
      do i=1,lon_dims
         call handle_f90err(nf90_inquire_dimension(ncid=il_file_id,dimid=lon_dims_ids(i),len=lon_dims_len(i)))
      enddo
      ni_glo=lon_dims_len(1)
      nj_glo=lon_dims_len(2)

      cl_nam = trim(domain)//".lat"
      call handle_f90err(nf90_inq_varid(il_file_id, cl_nam,  il_lat_id))
      call handle_f90err(nf90_inquire_variable(il_file_id, varid=il_lat_id, ndims=lat_dims, dimids=lat_dims_ids))
      do i=1,lat_dims
         call handle_f90err(nf90_inquire_dimension(ncid=il_file_id,dimid=lat_dims_ids(i),len=lat_dims_len(i)))
      enddo
      allocate(lon_glo2d(0:ni_glo-1,0:nj_glo-1), lat_glo2d(0:ni_glo-1,0:nj_glo-1))
      allocate(ila_what(2), ila_dim(2))
      ila_what(:)=1
      ila_dim(:)=[ni_glo, nj_glo]
      call handle_f90err(nf90_get_var (il_file_id, il_lon_id, lon_glo2d(0:ni_glo-1,0:nj_glo-1), ila_what, ila_dim))
      call handle_f90err(nf90_get_var (il_file_id, il_lat_id, lat_glo2d(0:ni_glo-1,0:nj_glo-1), ila_what, ila_dim))
      deallocate(ila_what, ila_dim)

      cl_nam = trim(domain)//".clo"
      call handle_f90err(nf90_inq_varid(il_file_id, cl_nam,  il_clo_id))
      call handle_f90err(nf90_inquire_variable(il_file_id, varid=il_clo_id, ndims=lon_dims, dimids=lon_dims_ids))
      do i=1,lon_dims
         call handle_f90err(nf90_inquire_dimension(ncid=il_file_id,dimid=lon_dims_ids(i),len=lon_dims_len(i)))
      enddo
      ncrn=lon_dims_len(3)

      cl_nam = trim(domain)//".cla"
      call handle_f90err(nf90_inq_varid(il_file_id, cl_nam,  il_cla_id))
      call handle_f90err(nf90_inquire_variable(il_file_id, varid=il_lat_id, ndims=lat_dims, dimids=lat_dims_ids))
      do i=1,lat_dims
         call handle_f90err(nf90_inquire_dimension(ncid=il_file_id,dimid=lat_dims_ids(i),len=lat_dims_len(i)))
      enddo

      allocate(clo_glo2d(0:ni_glo-1,0:nj_glo-1,ncrn), cla_glo2d(0:ni_glo-1,0:nj_glo-1,ncrn))
      allocate(ila_what(3), ila_dim(3))
      ila_what(:)=1
      ila_dim(:)=[ni_glo, nj_glo, ncrn]
      call handle_f90err(nf90_get_var (il_file_id, il_clo_id, clo_glo2d(0:ni_glo-1,0:nj_glo-1,1:ncrn), ila_what, ila_dim))
      call handle_f90err(nf90_get_var (il_file_id, il_cla_id, cla_glo2d(0:ni_glo-1,0:nj_glo-1,1:ncrn), ila_what, ila_dim))
      deallocate(ila_what, ila_dim)

      call handle_f90err(nf90_close(il_file_id))

      call handle_f90err(nf90_open(trim(mask_filename), nf90_nowrite, il_file_id))
      cl_nam = trim(domain)//".msk"
      call handle_f90err(nf90_inq_varid(il_file_id, cl_nam,  il_msk_id))
      allocate(msk_glo2d(0:ni_glo-1,0:nj_glo-1))
      allocate(ila_what(2), ila_dim(2))
      ila_what(:)=1
      ila_dim(:)=[ni_glo, nj_glo]
      call handle_f90err(nf90_get_var (il_file_id, il_msk_id, msk_glo2d(0:ni_glo-1,0:nj_glo-1), ila_what, ila_dim))
      deallocate(ila_what, ila_dim)
      call handle_f90err(nf90_close(il_file_id))

      call handle_f90err(nf90_open(trim(surf_filename), nf90_nowrite, il_file_id))
      cl_nam = trim(domain)//".srf"
      call handle_f90err(nf90_inq_varid(il_file_id, cl_nam,  il_srf_id))
      allocate(srf_glo2d(0:ni_glo-1,0:nj_glo-1))
      allocate(ila_what(2), ila_dim(2))
      ila_what(:)=1
      ila_dim(:)=[ni_glo, nj_glo]
      call handle_f90err(nf90_get_var (il_file_id, il_srf_id, srf_glo2d(0:ni_glo-1,0:nj_glo-1), ila_what, ila_dim))
      deallocate(ila_what, ila_dim)
      call handle_f90err(nf90_close(il_file_id))
    end subroutine read_oasis_grid





    !! ERROR HANDLERS !!
    subroutine handle_f90err(status)
        implicit none
        integer, intent ( in) :: status
        if(status /= nf90_noerr) then
        print *, trim(nf90_strerror(status))
        stop "Stopped"
        end if
    end subroutine handle_f90err   

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

  ! Initializing the component 
  CALL oasis_init_comp(compid, 'ocean_component',ierror)!

  ! Returns a local communicator gethering only tasks of that component
  CALL oasis_get_localcomm(local_comm, ierror)
  
  ! \param[OUT] il_part_id: Id of the created partition
  ! \param[IN] ig_paral: partition type, segment global offset, segment local size
  CALL oasis_def_partition (il_part_id,ig_paral,ierror)

  ! Starts grid writing process
  CALL oasis_start_grids_writing(flag)

  ! 
  CALL oasis_write_grid('torc',nlon_ocean,nlat_ocean,grid_lon_ocean,grid_lat_ocean,il_part_id)
  CALL oasis_write_corner('torc',nlon_ocean, nlat_ocean,4, grid_clo_ocean,grid_cla_ocean,il_part_id)
  CALL oasis_write_mask('torc',nlon_ocean,nlat_ocean,grid_msk_ocean(:,:),il_part_id)
  CALL oasis_terminate_grids_writing()

  CALL oasis_def_var(var_id(1), 'FIELD_RECV_OCN', il_part_id,var_nodims, OASIS_In, var_actual_shape, var_type,ierror)
  CALL oasis_def_var(var_id(2), 'FIELD_SEND_OCN', il_part_id,var_nodims, OASIS_Out, var_actual_shape, var_type,ierror)

  CALL oasis_enddef(ierror)

  CALL oasis_put(var_id(2),itap_sec,field_send_ocean,info)!

  CALL oasis_get(var_id(1),itap_sec,field_recv_ocean,info)

  CALL oasis_terminate(ierror)

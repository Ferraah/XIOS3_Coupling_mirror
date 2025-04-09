
#include <mpi.h>
#include <iostream>

#include <my_xios.hpp>

using namespace std;

int main( int argc, char* argv[] )
{
  MPI_Init(&argc,&argv);

  string clientId( "client" );
  MPI_Comm clientComm;
  //CALL xios_initialize("client",return_comm=comm)
  // $ grep -rw initialize src/interface | grep SUBROUTINE
  // -> src/interface/fortran/idata.F90:   SUBROUTINE  xios(initialize)(client_id, local_comm, return_comm)
  MPI_Fint clientComm_F ;
  MPI_Fint nullComm_F = MPI_Comm_c2f( MPI_COMM_NULL );
  
  cxios_init_client( clientId.c_str(), clientId.length(), &nullComm_F, &clientComm_F );
  clientComm = MPI_Comm_f2c( clientComm_F );
    
  int rank(0);
  MPI_Comm_rank( clientComm, &rank );
  int size(1);
  MPI_Comm_size( clientComm, &size );
  
  cout << "Hello XIOS from proc " << rank << endl;
  
  string contextId( "test" );
  //CALL xios_context_initialize("test",comm)|grep SUBROUTINE
  // $ grep -rw context_initialize src/interface | grep SUBROUTINE
  // -> src/interface/fortran/idata.F90:   SUBROUTINE  xios(context_initialize)(context_id,comm)
  cxios_context_initialize( contextId.c_str(), contextId.length(), &clientComm_F );

  // -----------------------------
  // -----------------------------
  //CALL xios_define_calendar(type="Gregorian")
  //We define the calendar type in xml
		     
  cxios_date dorigin;
  char dorigin_str[20];
  //CALL xios_get_time_origin(dorigin);
  // $ grep -rw get_time_origin src/interface | grep SUBROUTINE
  // -> src/interface/fortran/icalendar.F90:   SUBROUTINE xios(get_time_origin)(time_origin)
  //    1. TO MANIPULATE AN XIOS OBJECT, REQUIRE THE HANDLE MANAGED BY THE FORTRAN INTERFACE
  //    -> CALL xios(get_default_calendar_wrapper_handle)(calendar_wrapper)
  //       $ grep -rw get_default_calendar_wrapper_handle src/interface | grep SUBROUTINE
  //       -> src/interface/fortran/icalendar_wrapper.F90:   SUBROUTINE xios(get_default_calendar_wrapper_handle)(ret)
  //    2. WITH THE HANDLE, XIOS OBJECT ATTRIBUTRES ARE AVAILABLE READ/WRITE (GET/SET)
  //    -> CALL xios(get_time_origin_hdl)(calendar_wrapper, time_origin)
  //       $ grep -rw get_time_origin_hdl src/interface | grep SUBROUTINE
  //       -> src/interface/fortran/icalendar_wrapper.F90:   SUBROUTINE xios(get_time_origin_hdl)(hdl, time_origin)
  xios::CCalendarWrapper* clientCalendar;
  cxios_get_current_calendar_wrapper( &clientCalendar );
  cxios_get_calendar_wrapper_date_time_origin( clientCalendar, &dorigin );
  //CALL xios_date_convert_to_string(dorigin, dorigin_str);
  // $ grep -rw date_convert_to_string src/interface | grep SUBROUTINE
  // -> src/interface/fortran/idate.F90:   SUBROUTINE xios(date_convert_to_string)(date, str)
  cxios_date_convert_to_string( dorigin, dorigin_str, 20);
  if (rank == 0) cout << "calendar time_origin = " << dorigin_str << endl;

  cxios_date dstart;
  char dstart_str[20];
  //CALL xios_get_start_date(dstart);
  cxios_get_calendar_wrapper_date_start_date( clientCalendar, &dstart );
  //CALL xios_date_convert_to_string(dstart, dstart_str);
  cxios_date_convert_to_string( dstart, dstart_str, 20);
  if (rank == 0) cout << "calendar start_date = " << dstart_str << endl;

  cxios_duration dtime;
  dtime.year = 0;
  dtime.month = 0;
  dtime.day = 0;
  dtime.hour = 0;
  dtime.minute = 0;
  dtime.second = 0;
  dtime.timestep = 0;
  dtime.second = 3600;
  //CALL xios_set_timestep(dtime);
  //  - CALL xios(set_calendar_wrapper_attr_hdl)(calendar_wrapper, timestep=timestep)
  cxios_set_calendar_wrapper_timestep( clientCalendar, dtime );
  //  - CALL xios(update_calendar_timestep)(calendar_wrapper)
  cxios_update_calendar_timestep( clientCalendar );
		     
  // -----------------------------
  // -----------------------------

  int axis_size(0);
  string axisId( "axis_A" );
  //CALL xios_get_axis_attr("axis_A", n_glo = axis_size);
  // $ grep -rw get_axis_attr src/interface | grep SUBROUTINE
  // -> src/interface/fortran_attr/iaxis_attr.F90:  SUBROUTINE xios(get_axis_attr)  &
  //    1. TO MANIPULATE AN XIOS OBJECT, REQUIRE THE HANDLE MANAGED BY THE FORTRAN INTERFACE
  //    -> CALL xios(get_axis_handle) (axis_id,axis_hdl)
  //       $ grep -rw get_axis_handle src/interface | grep SUBROUTINE
  //       -> src/interface/fortran/iaxis.F90:   SUBROUTINE xios(get_axis_handle)(idt,ret)
  //    2. WITH THE HANDLE, XIOS OBJECT ATTRIBUTRES ARE AVAILABLE READ/WRITE (GET/SET)
  //    -> CALL xios(get_axis_attr_hdl_) ( ...)
  //       $ grep -rw get_axis_attr_hdl_ src/interface | grep SUBROUTINE
  //       -> src/interface/fortran_attr/iaxis_attr.F90:  SUBROUTINE xios(get_axis_attr_hdl_)   &
  //          ...
  //          "get/set_object_attr" ARE WRAPPERS FOR MANY OPTIONAL ATTRIBUTES, LOOK FOR THE REQUESTED ONES (ONE BY ONE, see xios_set_domain_attr below)
  //          IF (PRESENT(name_)) THEN
  //            CALL cxios_get_axis_name &
  //          (axis_hdl%daddr, name_, len(name_))
  //          ENDIF
  xios::CAxis* axis_A = NULL;
  cxios_axis_handle_create( &axis_A, axisId.c_str(), axisId.length() );
  cxios_get_axis_n_glo( axis_A, &axis_size);
  double* axis_value = new double[axis_size];
  //CALL xios_get_axis_attr("axis_A", value = axis_value)
  //    -> HANDLE AVAILABLE
  //    -> CALL xios(get_axis_attr_hdl_) ( ...)
  //       -> src/interface/fortran_attr/iaxis_attr.F90:  SUBROUTINE xios(get_axis_attr_hdl_)   &
  //       IF (PRESENT(value_)) THEN
  //         CALL cxios_get_axis_value &
  //       (axis_hdl%daddr, value_, SHAPE(value_))
  //       ENDIF
  cxios_get_axis_value( axis_A, axis_value, &axis_size );
  if (rank == 0) cout << "axis value = " << axis_value[0] << " ..." << axis_value[axis_size-1] << endl;


  xios::CDomain* domain_A = NULL;
  int ni_glo(0), nj_glo(0);
  //CALL xios_get_domain_attr("domain_A", type = domain_type)
  string domainId( "domain_A" );
  cxios_domain_handle_create( &domain_A, domainId.c_str(), domainId.length() );
  char domain_type[20];
  cxios_get_domain_type( domain_A, domain_type, 20 );
  if(rank == 0) cout << "domain type = " << domain_type << endl;
  //CALL xios_get_domain_attr("domain_A", ni_glo = ni_glo, nj_glo=nj_glo)
  cxios_get_domain_ni_glo( domain_A, &ni_glo );
  cxios_get_domain_nj_glo( domain_A, &nj_glo );
  if(rank == 0) cout << "domain size = " << ni_glo << "*" << nj_glo << endl;
  
  int ni=ni_glo/size;
  int nj=nj_glo;

  int ibegin=ni*rank;
  int jbegin=0;
  
  //CALL xios_set_domain_attr("domain_A", ni=ni, nj=nj, ibegin=ibegin,jbegin=jbegin)
  cxios_set_domain_ni( domain_A, ni );
  cxios_set_domain_nj( domain_A, nj );
  cxios_set_domain_ibegin( domain_A, ibegin );
  cxios_set_domain_jbegin( domain_A, jbegin );
  cout << "Proc " << rank << " occupies subdomain "
       << ibegin << "->" << ibegin+ni << " X "
       << jbegin << "->" << jbegin+nj << endl;

  double* lonvalue = new double[ni];
  double* latvalue = new double[nj];

  for (int i=0 ; i<ni ; i++ )
    lonvalue[i] = -180 + (rank*ni+i) * 360/ni_glo;

  for (int j=0 ; j<nj ; j++ )
    latvalue[j] = -90 + j * 180/nj_glo;

  //CALL xios_set_domain_attr("domain_A", lonvalue_1d=lonvalue,latvalue_1d=latvalue)
  cxios_set_domain_lonvalue_1d( domain_A, lonvalue, &ni );
  cxios_set_domain_latvalue_1d( domain_A, latvalue, &nj );
  cxios_context_close_definition();

  double* field_A = new double[ni*nj*axis_size];
  for (int idx=0 ; idx<ni*nj*axis_size ; idx++ )
    field_A[idx]=rank;

  string fieldId( "field_A" );
  for (int ts=1 ; ts<=4 ; ts++ ) {
    //CALL xios_update_calendar(ts)
    cxios_update_calendar(ts);
    //CALL xios_send_field("field_A", field_A)
    // $ grep -rw send_field src/interface
    // -> src/interface/fortran/ixios_interfaces.F90:INTERFACE xios(send_field)
    //    MODULE PROCEDURE xios(send_field_r8_0d), xios(send_field_r8_1d), xios(send_field_r8_2d), xios(send_field_r8_3d), &
    //                     ...
    //                     xios(send_field_r4_0d), xios(send_field_r4_1d), xios(send_field_r4_2d), xios(send_field_r4_3d), &
    //                     ...
    //                     xios(send_field_r8_0d_hdl), xios(send_field_r8_1d_hdl), xios(send_field_r8_2d_hdl), xios(send_field_r8_3d_hdl), &
    //                     ...
    //    MANY INTERFACES : field_A defined on a 3D grid (see iodef.xml) -> 3d
    //                      write in double precision -> r8
    //                      (suffixed by hdl permits to manipulate CField object like CAxis, CDomain ...)
    cxios_write_data_k83( fieldId.c_str(), fieldId.length(), field_A, ni, nj, axis_size, -1);
  }

  cxios_context_finalize();
  delete [] field_A;
  delete [] lonvalue;
  delete [] latvalue;
  delete [] axis_value;

  cxios_finalize();

  MPI_Finalize();
  return 0;
}

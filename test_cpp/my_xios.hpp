
#include <calendar_wrapper.hpp>
#include <icdate.hpp>
#include <axis.hpp>
#include <domain.hpp>
#include <field.hpp>

extern "C"
{  
  void cxios_init_client(const char* client_id , int len_client_id, MPI_Fint* f_local_comm, MPI_Fint* f_return_comm );
  void cxios_finalize();

  void cxios_context_initialize(const char* context_id , int len_context_id, MPI_Fint* f_comm);
  void cxios_context_close_definition();
  void cxios_context_finalize();

  void cxios_get_current_calendar_wrapper(xios::CCalendarWrapper** _ret);
  void cxios_get_calendar_wrapper_date_time_origin(xios::CCalendarWrapper* calendarWrapper_hdl, cxios_date* time_origin_c);
  void cxios_date_convert_to_string(cxios_date date_c, char* str, int str_size);
  void cxios_get_calendar_wrapper_date_start_date(xios::CCalendarWrapper* calendarWrapper_hdl, cxios_date* start_date_c);

  void cxios_set_calendar_wrapper_timestep(xios::CCalendarWrapper* calendar_wrapper_hdl, cxios_duration timestep_c);
  void cxios_update_calendar_timestep(xios::CCalendarWrapper* calendarWrapper_hdl);
    
  void cxios_axis_handle_create (xios::CAxis** _ret, const char * _id, int _id_len);
  void cxios_get_axis_n_glo(xios::CAxis* axis_hdl, int* n_glo);
  void cxios_get_axis_value(xios::CAxis* axis_hdl, double* value, int* extent);

  void cxios_domain_handle_create(xios::CDomain** _ret, const char * _id, int _id_len);
  void cxios_get_domain_type(xios::CDomain* domain_hdl, char * type, int type_size);
  void cxios_get_domain_ni_glo(xios::CDomain* domain_hdl, int* ni_glo);
  void cxios_get_domain_nj_glo(xios::CDomain* domain_hdl, int* nj_glo);
  void cxios_set_domain_ni(xios::CDomain* domain_hdl, int ni);
  void cxios_set_domain_nj(xios::CDomain* domain_hdl, int nj);
  void cxios_set_domain_ni_glo(xios::CDomain* domain_hdl, int ni);
  void cxios_set_domain_nj_glo(xios::CDomain* domain_hdl, int ni);
  void cxios_set_domain_ibegin(xios::CDomain* domain_hdl, int ibegin);
  void cxios_set_domain_jbegin(xios::CDomain* domain_hdl, int jbegin);
  void cxios_set_domain_lonvalue_1d(xios::CDomain* domain_hdl, double* lonvalue_1d, int* extent);
  void cxios_set_domain_latvalue_1d(xios::CDomain* domain_hdl, double* latvalue_1d, int* extent);

  void cxios_field_handle_create (xios::CField** ret, const char * id, int _id_len);

  void cxios_update_calendar(int step);
  void cxios_write_data_k83(const char* fieldid, int fieldid_size, double* data_k8, int data_Xsize, int data_Ysize, int data_Zsize, int tileid);


  void cxios_get_variable_data_k8(const char* varId, int varIdSize, double* data, bool* isVarExisted);
  void cxios_get_variable_data_k4(const char* varId, int varIdSize, float* data, bool* isVarExisted);
  void cxios_get_variable_data_int(const char* varId, int varIdSize, int* data, bool* isVarExisted);
  void cxios_get_variable_data_logic(const char* varId, int varIdSize, bool* data, bool* isVarExisted);
  void cxios_get_variable_data_char(const char* varId, int varIdSize, char* data, int dataSizeIn, bool* isVarExisted);
  void cxios_get_field_freq_op(xios::CField* field_hdl, cxios_duration* freq_op_c);
  void cxios_set_domain_ni(xios::CDomain* domain_hdl, int ni);
  void cxios_set_domain_nj(xios::CDomain* domain_hdl, int ni);
  cxios_duration cxios_duration_convert_from_string(const char* str, int str_size);
  void cxios_duration_convert_to_string(cxios_duration dur_c, char* str, int str_size);
  cxios_date cxios_date_add_duration(cxios_date date_c, cxios_duration dur_c);
  bool cxios_date_lt(cxios_date date1_c, cxios_date date2_c);
  bool cxios_date_le(cxios_date date1_c, cxios_date date2_c);
};

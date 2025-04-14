#include <iostream>
#include <mpi.h>
#include <my_xios.hpp>
#include "xios.hpp"

struct ToymodelParameters
{
  cxios_duration duration;
  xios::CDuration timestep_duration;
  xios::CDuration freq_op;
  cxios_date start_date, curr_date, end_date;
  int ni_glo, nj_glo;
  int freq_op_in_ts;
};


cxios_duration CDuration_to_cxios_duration(xios::CDuration duration)
{
  cxios_duration dur_c;
  dur_c.year = duration.year;
  dur_c.month = duration.month;
  dur_c.day = duration.day;
  dur_c.hour = duration.hour;
  dur_c.minute = duration.minute;
  dur_c.second = duration.second;
  return dur_c;
}

void loadToyModelData(std::string model_id, ToymodelParameters & params)
{
  
  char tmp[255];
  memset(tmp, 0, sizeof(tmp));

  bool is_var_existed;
  std::string label = "toymodel_duration";
  cxios_get_variable_data_char(label.c_str(), label.length(), tmp, 255, &is_var_existed);
  params.duration = CDuration_to_cxios_duration(xios::CDuration::FromString(std::string(tmp)));
  memset(tmp, 0, sizeof(tmp));

  label = "toymodel_timestep_duration";
  cxios_get_variable_data_char(label.c_str(), label.length(), tmp, 255, &is_var_existed);
  params.timestep_duration = xios::CDuration::FromString(std::string(tmp));
  memset(tmp, 0, sizeof(tmp));

  label = "toymodel_ni_glo";
  cxios_get_variable_data_int(label.c_str(), label.length(), &params.ni_glo, &is_var_existed);
  label = "toymodel_nj_glo";
  cxios_get_variable_data_int(label.c_str(), label.length(), &params.nj_glo, &is_var_existed);

  // Getting the frequency of the coupling operation from iodef
  xios::CField *field_hdl;
  cxios_duration freq_op;
  label = "field2D_oce_to_atm";
  cxios_field_handle_create(&field_hdl, label.c_str(), label.length());
  cxios_get_field_freq_op(field_hdl, &freq_op);
  cxios_duration_convert_to_string(freq_op, tmp, 255);
  std::string freq_op_str(tmp);
  freq_op_str = freq_op_str.substr(0, freq_op_str.find("ts"));
  params.freq_op_in_ts = std::stoi(freq_op_str);
  //

  xios::CCalendarWrapper* clientCalendar;
  cxios_get_current_calendar_wrapper( &clientCalendar );
  cxios_get_calendar_wrapper_date_start_date( clientCalendar, &params.start_date);

  cxios_duration ts;
  ts.year = params.timestep_duration.year;
  ts.month = params.timestep_duration.month;
  ts.day = params.timestep_duration.day;
  ts.hour = params.timestep_duration.hour;
  ts.minute = params.timestep_duration.minute;
  ts.second = params.timestep_duration.second;
  ts.timestep = 0;

  cxios_set_calendar_wrapper_timestep(clientCalendar, ts);
  cxios_update_calendar_timestep( clientCalendar );

  std::cout << "Loaded Toy Model Data: " << std::endl;
  std::cout << "Timestep Duration: " << params.timestep_duration << std::endl;
  std::cout << "ni_glo: " << params.ni_glo << std::endl;
  std::cout << "nj_glo: " << params.nj_glo << std::endl;
  std::cout << "Frequency of Operation in Timestep: " << params.freq_op_in_ts << std::endl;
  std::cout << "Frequency of Operation: " << freq_op_str << std::endl;
  std::cout << "Model ID: " << model_id << std::endl;
  
}

void configureXiosFromModel(std::string model_id, ToymodelParameters & params)
{
  xios::CDomain *domain_hdl;
  std::string label = "domain";

  std::cout << "Creating domain handle: " << label << std::endl;
  cxios_domain_handle_create(&domain_hdl, label.c_str(), label.length());

  cxios_set_domain_ni_glo(domain_hdl, params.ni_glo); 
  cxios_set_domain_nj_glo(domain_hdl, params.nj_glo); 

  std::cout << "Configured XIOS from Model: " << std::endl;
  cxios_context_close_definition();
}

void runCoupling(std::string model_id, ToymodelParameters & params)
{
  int current_timestep = 1;

  params.curr_date = params.start_date;
  params.end_date = cxios_date_add_duration(params.start_date, params.duration);
  
  while(cxios_date_lt(params.curr_date,params.end_date))
  {
    // This function would contain the logic to run the coupling
    std::cout << "Running coupling for timestep: " << current_timestep << std::endl;
    cxios_update_calendar(current_timestep);
    current_timestep++;
    params.curr_date = cxios_date_add_duration(params.curr_date, CDuration_to_cxios_duration(params.timestep_duration));
  }
  // This function would contain the logic to run the coupling
  std::cout << "Running coupling for model: " << model_id << std::endl;

}

void runToyModel(std::string model_id)
{

    MPI_Comm local_comm;
    MPI_Comm world_comm = MPI_COMM_WORLD;
    ToymodelParameters params;

    std::cout << "Running toy model..." << std::endl;
    cxios_init_client(model_id.c_str(), model_id.length(), &world_comm, &local_comm);
    cxios_context_initialize(model_id.c_str(), model_id.length(), &world_comm); 

    loadToyModelData(model_id, params);
    configureXiosFromModel(model_id, params);
    runCoupling(model_id, params);

    cxios_context_finalize();
    cxios_finalize();
    // This function would contain the logic of your toy model

}

int main(int argc, char *argv[])
{
    // Initialize MPI
    MPI_Init(&argc, &argv);
    int rank, size;

    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    // Your code here
    std::cout << "Hello from XIOS!" << std::endl;
     //CXios::initialize();
    
    if(rank==0){
      runToyModel("ocn");
    }
    else{
      CXios::initServerSide() ;
    }

    // Finalize MPI
    MPI_Finalize();

  return 0;
}
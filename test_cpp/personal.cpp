#include <iostream>
#include <mpi.h>
 #include "xios.hpp"

int main(int argc, char *argv[])
{
    // Initialize MPI
    MPI_Init(&argc, &argv);
    int rank, size;
    MPI_Comm local_comm;

    MPI_Comm_rank(MPI_COMM_WORLD, &rank);

    // Your code here
    std::cout << "Hello from XIOS!" << std::endl;
     CXios::initialize();
    if(rank==0){
      // CXios::initClientSide("client", MPI_COMM_WORLD, local_comm); ;
    }
    else{
      // CXios::initServerSide("server") ;
    }

    // Finalize MPI
    MPI_Finalize();

  return 0;
}
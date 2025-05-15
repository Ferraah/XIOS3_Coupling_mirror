mv iodef.xml iodef_original.xml

cp restart_zerofield.nc restart.nc
cp restart_zerofield.nc restart_next.nc

# Set the iodef file 
mv iodef_3.xml iodef.xml 
# Runs
mpirun -np 3 ./1_cpl_time_params.exe
# Set back to the original iodef file
mv iodef.xml iodef_3.xml 

ncdump restart_next.nc
mv iodef_original.xml iodef.xml
echo "Completed runSingle.sh"


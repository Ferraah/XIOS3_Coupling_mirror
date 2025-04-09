mv iodef.xml iodef_original.xml

cp restart_zerofield.nc restart.nc
cp restart_zerofield.nc restart_next.nc

# Set the iodef file 
mv iodef_1.xml iodef.xml 
# Runs
mpirun -np 3 ./2_singlefield_restart.exe
# Set back to the original iodef file
mv iodef.xml iodef_1.xml 
# The next run will use the restart file
cp restart_next.nc restart.nc

mv iodef_2.xml iodef.xml 
mpirun -np 3 ./2_singlefield_restart.exe
mv iodef.xml iodef_2.xml 
cp restart_next.nc restart.nc

mv iodef_original.xml iodef.xml

ncdump restart_next.nc
echo "Completed runDouble.sh"


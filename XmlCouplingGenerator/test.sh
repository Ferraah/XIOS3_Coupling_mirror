exec_dir=/scratch/globc/ferrario/xios_experiments/cnrm-cm6

mv $exec_dir/iodef.xml $exec_dir/iodef_old.xml
cp coupling_config.xml $exec_dir/iodef.xml
cd $exec_dir
./run.sh

# Check if the run was successful
if [ $? -eq 0 ]; then
    echo "✅ Run completed successfully."
else
    echo "❌ Run failed. Please check the logs for details."
    exit 1
fi

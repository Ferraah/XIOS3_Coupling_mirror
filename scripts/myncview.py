import xarray as xr
import sys
import matplotlib.pyplot as plt

# Open the NetCDF file
# Get the file path and variable name from command line arguments
file_path = sys.argv[1]
variable_name = sys.argv[2] 
ds = xr.open_dataset(file_path)

# Select a variable to plot (replace 'variable_name' with the actual name)
var = ds[variable_name]
# Get coordinate bounds
lon = ds["lon"]
lat = ds["lat"]

# Remove the first dimension (assuming it's time)
# Plot the first time step (if time-dependent)
var.isel(time_counter=0).plot(y="lon", cmap="viridis")  # Adjust cmap as needed
plt.title("Visualization of "+file_path.split('/')[-1]+ " - "+variable_name)
output_file_name = file_path.split('/')[-1].replace('.nc', '_plot.png')
plt.savefig(output_file_name)
plt.show()
import slurm_sbatcher as sb

# Get XIOS or OASIS from argv
import sys
if len(sys.argv) < 2:
    print("Usage: python runBenchmark.py <xios|oasis>")
    sys.exit(1)
software = sys.argv[1].lower()
if software not in ["xios", "oasis"]:
    print("Invalid software. Choose 'xios' or 'oasis'.")
    sys.exit(1)


sbatcher = sb.SlurmSbatcher(
    nm_list=[(n, n) for n in [64]],  
    do_interpolation=True,
    res="high",
    partition="prod",
    time_limit="01:00:00",
    software_path=f"../{software}/",
    template_file="job_template.sh",
    results_dir="results",
    output_dir="outputs")

sbatcher.run()

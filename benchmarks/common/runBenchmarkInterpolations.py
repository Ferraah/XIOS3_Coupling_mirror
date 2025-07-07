import slurm_sbatcher_interp as sb
# Get XIOS or OASIS from argv
import sys
if len(sys.argv) < 2:
    print("Usage: python runBenchmark.py <xios|oasis>")
    sys.exit(1)
software = sys.argv[1].lower()
if software not in ["xios", "oasis"]:
    print("Invalid software. Choose 'xios' or 'oasis'.")
    sys.exit(1)


sbatcher = sb.SlurmSbatcherInterpolations(
    nm_list=[(n, n) for n in [64]],  # List of (n, m) pairs for the benchmark
    interpolation_iterations=20,  # Number of iterations for the interpolation benchmark
    res="high",
    partition="bench",
    time_limit="06:00:00",
    software_path=f"../{software}/",
    template_file="job_template_interp.sh",
    results_dir="results_interp",
    output_dir="outputs_interp")

sbatcher.run()

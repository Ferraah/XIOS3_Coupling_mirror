import os
import subprocess
import time
import pandas as pd
import matplotlib.pyplot as plt

N_LIST = [1, 2, 4, 8, 16]
PARTITION = "bigmem2"
TIME_LIMIT = "00:20:00"
TEMPLATE_PATH = "job_template.sh"
RESULTS_DIR = "results"
OUTPUT_DIR = "outputs"

os.makedirs(RESULTS_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)

def submit_job(n, m):
    job_script = f"{RESULTS_DIR}/job_n{n}_m{m}.sh"
    with open(TEMPLATE_PATH) as f:
        template = f.read()
    content = template.replace("{{N}}", str(n)).replace("{{M}}", str(m))
    content = content.replace("{{NTOT}}", str(n + m)).replace("{{PARTITION}}", PARTITION)
    content = content.replace("{{TIME}}", TIME_LIMIT)
    with open(job_script, "w") as f:
        f.write(content)
    job_id = subprocess.check_output(["sbatch", job_script]).decode().strip().split()[-1]
    return job_id

def wait_for_jobs(job_ids):
    while True:
        out = subprocess.check_output(["squeue", "-u", os.getenv("USER")]).decode()
        if not any(jid in out for jid in job_ids):
            break
        time.sleep(10)

def parse_timing(n, m):
    output_file = f"{OUTPUT_DIR}/ocean_times_n{n}_m{m}.txt"
    times = []
    with open(output_file) as f:
        for line in f:
            if "TIMING:" in line:
                times.append(float(line.strip().split()[-1]))
    return pd.Series(times).mean(), pd.Series(times).var()

# Submit jobs
job_ids = []
for n in N_LIST:
    # RECHANGE: M_LIST should be defined
    job_id = submit_job(n, n)
    job_ids.append(job_id)

# Wait for completion
wait_for_jobs(job_ids)

# Collect results
records = []
for n in N_LIST:
    # RECHANGE: M_LIST should be defined
    avg, var = parse_timing(n, n)
    records.append({"n": n, "m": n, "avg_time": avg, "var_time": var})

df = pd.DataFrame(records)
df.to_csv("results/scaling_results.csv", index=False)

# # Plot
# pivot = df.pivot(index="n", columns="m", values="avg_time")
# plt.figure(figsize=(8,6))
# plt.title("Average Time vs Ocean/Atmosphere Process Counts")
# plt.xlabel("Atmosphere Processes (m)")
# plt.ylabel("Ocean Processes (n)")
# plt.imshow(pivot, cmap="viridis", origin="lower")
# plt.colorbar(label="Avg Time (s)")
# plt.xticks(range(len(M_LIST)), M_LIST)
# plt.yticks(range(len(N_LIST)), N_LIST)
# plt.savefig("plots/scaling_plot.png")
# plt.show()

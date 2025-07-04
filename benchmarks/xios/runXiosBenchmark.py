import os
import subprocess
import time
import pandas as pd
import matplotlib.pyplot as plt
import analyzeResults as ar

N_LIST = [1]
DO_INTERPOLATION = True
RES = "high"

if RES == "high":
    GRIDS = (("t12e", "LR"), ("icoh", "U"))  #Highres
elif RES == "low":
    GRIDS = (("nogt", "LR"), ("lmdz", "LR"))  #Lowres
else:
    raise ValueError("RES must be either 'high' or 'low'")

# Only these couples for our benchmarking
PARTITION = "bench"
TIME_LIMIT = "01:00:00"
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

    # ntasks = n + m  
    ntasks = n+m
    content = content.replace("{{NTOT}}", str(ntasks)).replace("{{PARTITION}}", PARTITION)
    
    content = content.replace("{{TIME}}", TIME_LIMIT)
    content = content.replace("{{RES}}", RES)
    content = content.replace("{{GRID_NAME_SRC}}", GRIDS[0][0])
    content = content.replace("{{GRID_TYPE_SRC}}", GRIDS[0][1])
    content = content.replace("{{GRID_NAME_DST}}", GRIDS[1][0])
    content = content.replace("{{GRID_TYPE_DST}}", GRIDS[1][1])

    with open(job_script, "w") as f:
        f.write(content)

    print(["sbatch", job_script, str(DO_INTERPOLATION).lower()])
    job_id = subprocess.check_output(["sbatch", job_script, str(DO_INTERPOLATION).lower()]).decode().strip().split()[-1]
    return job_id

def wait_for_jobs(job_ids):
    while True:
        out = subprocess.check_output(["squeue", "-u", os.getenv("USER")]).decode()
        if not any(jid in out for jid in job_ids):
            break
        time.sleep(10)



def submit_all_jobs():
    job_ids = []
    for n in N_LIST:
        # RECHANGE: M_LIST should be defined
        job_id = submit_job(n, n)
        job_ids.append(job_id)
    return job_ids

def main():
    # Submit jobs
    job_ids = submit_all_jobs()

    # Wait for completion
    wait_for_jobs(job_ids)

    # Collect results
    df = ar.collect_results()

    if not df.empty:
        ar.make_plots("results/scaling_results.csv")

if __name__ == "__main__":
    main()

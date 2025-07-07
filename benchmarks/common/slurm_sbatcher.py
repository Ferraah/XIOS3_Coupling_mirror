import os
import subprocess
import time
import pandas as pd
import matplotlib.pyplot as plt

class SlurmSbatcher:

    def __init__(
        self,
        nm_list,
        do_interpolation,
        res,
        partition,
        time_limit,
        software_path,
        template_file,
        results_dir,
        output_dir):

        self.NM_LIST = nm_list
        self.DO_INTERPOLATION = do_interpolation
        self.RES = res

        # High resolution grids labels
        if self.RES == "high":
            self.GRIDS = (("t12e", "LR"), ("icoh", "U"))  # Highres
        # Low resolution grids labels for debugging
        elif self.RES == "low":
            self.GRIDS = (("torc", "LR"), ("lmdz", "LR"))  # Lowres
        else:
            raise ValueError("RES must be either 'high' or 'low'")

        self.PARTITION = partition
        self.TIME_LIMIT = time_limit
        self.SOFTWARE_PATH = software_path
        self.TEMPLATE_PATH = software_path+template_file
        self.RESULTS_DIR_PATH = software_path+results_dir
        self.OUTPUT_DIR_PATH = software_path+output_dir

        os.makedirs(self.RESULTS_DIR_PATH, exist_ok=True)
        os.makedirs(self.OUTPUT_DIR_PATH, exist_ok=True)

    def submit_job(self, n, m):

        # Create folder named run_n_m
        run_dir = f"{self.SOFTWARE_PATH}/run_{n}_{m}"
        os.makedirs(run_dir, exist_ok=True)

        # Create job script name based on n and m in 
        job_script = f"{run_dir}/job_n{n}_m{m}.sh"


        # Customize the job script content using the template
        with open(self.TEMPLATE_PATH) as f:
            template = f.read()

        content = template.replace("{{N}}", str(n)).replace("{{M}}", str(m))
        content = content.replace("{{NTOT}}", str(n + m)).replace("{{PARTITION}}", self.PARTITION)
        content = content.replace("{{TIME}}", self.TIME_LIMIT)
        content = content.replace("{{RES}}", self.RES)
        content = content.replace("{{GRID_NAME_SRC}}", self.GRIDS[0][0])
        content = content.replace("{{GRID_TYPE_SRC}}", self.GRIDS[0][1])
        content = content.replace("{{GRID_NAME_DST}}", self.GRIDS[1][0])
        content = content.replace("{{GRID_TYPE_DST}}", self.GRIDS[1][1])
        content = content.replace("{{SLURM_OUTPUT}}", self.RESULTS_DIR_PATH)

        # Apply modifications
        with open(job_script, "w") as f:
            f.write(content)

        # Run command and get job ID
        job_id = subprocess.check_output(
            # Run the bash command, pass also if to generate the weights or not during the run
            ["sbatch", job_script, str(self.DO_INTERPOLATION).lower()]
        ).decode().strip().split()[-1]

        return job_id

    # Wait for all jobs to finish
    def wait_for_jobs(self, job_ids):
        while True:
            out = subprocess.check_output(["squeue", "-u", os.getenv("USER")]).decode()
            active_jobs = [jid for jid in job_ids if jid in out]
            if not active_jobs:
                break

            os.system('clear')
            # Print SQUEUE every second. Comment if needed
            print(out)
            time.sleep(1)

    # Create and submit all jobs with different process counts
    def submit_all_jobs(self):
        job_ids = []
        for n, m in self.NM_LIST:
            job_id = self.submit_job(n, m)
            job_ids.append(job_id)
        return job_ids

    def run(self):
        job_ids = self.submit_all_jobs()
        self.wait_for_jobs(job_ids)
        print("All jobs have finished.")




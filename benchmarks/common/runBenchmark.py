import slurm_sbatcher as sb

software_path = "../xios/"
sbatcher = sb.SlurmSbatcher(
    nm_list=[(n, n) for n in [32]],
    do_interpolation=True,
    res="high",
    partition="bench",
    time_limit="01:00:00",
    template_path=software_path+"job_template.sh",
    results_dir=software_path+"results",
    output_dir=software_path+"outputs")

sbatcher.run()

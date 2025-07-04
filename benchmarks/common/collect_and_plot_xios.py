#################### XIOS COLLECT DATA FROM BENCHMARKS ####################

from parser_utils import *

# Collect and plot results from already run jobs
trim_outliers = 10  # Percentage of outliers to trim
NM_LIST = [(n, n) for n in [2, 4, 8, 16, 32, 64, 128, 256, 512]]  # Process counts for ping-pong tests

df = collect_results(
    IS_XIOS=True,
    NM_LIST=NM_LIST, 
    PING_PONG_LINE_PREFIX=" TIMING:",
    INTERPOLATION_LINE_PREFIX="",
    RESULTS_CSV="../xios/results/scaling_results.csv", 
    RAW_TIMES_DIR="../xios/outputs", 
    PARSE_INTERPOLATIONS=True, 
    trim_outliers=trim_outliers)
print(df)

title_pp = "XIOS Ping Pong Scaling Results (trimmed outliers: {}%)".format(trim_outliers)
title_interp = "XIOS First order interpolation weight generation time"

make_ping_pong_plot(df, title_pp, save_path="benchmark_xios_ping_pong.png")
make_interpolation_plot(df, title_interp, save_path="benchmark_xios_interpolation.png")
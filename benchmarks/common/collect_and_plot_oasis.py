#################### OASIS COLLECT DATA FROM BENCHMARKS ####################

from parser_utils import *

# Collect and plot results from already run jobs
trim_outliers = 10  # Percentage of outliers to trim
NM_LIST = [(n, n) for n in [2, 4, 8, 16, 32, 64, 128, 256, 512]]  # Process counts for ping-pong tests

df = collect_results(
    IS_XIOS=False,
    NM_LIST=NM_LIST, 
    PING_PONG_LINE_PREFIX=" TIMING:",
    INTERPOLATION_LINE_PREFIX=" YAC mapping time =",
    RESULTS_CSV="../oasis/results/scaling_results.csv", 
    RAW_TIMES_DIR="../oasis/outputs", 
    PARSE_INTERPOLATIONS=False, 
    trim_outliers=trim_outliers)
print(df)

dfi = collect_interpolations_results(
    IS_XIOS=False,
    NM_LIST=NM_LIST,
    INTERPOLATION_LINE_PREFIX=" YAC mapping time =",
    RESULTS_CSV="../oasis/results_interp/interpolation_results.csv",
    RAW_TIMES_DIR="../oasis/outputs_interp",
)

print(dfi)
title_pp = "OASIS 100 Ping Pongs Scaling Results (trimmed outliers: {}%)".format(trim_outliers)
title_interp = "OASIS-YAC Two first order interpolations weight generation time"

make_ping_pong_plot(df, title_pp, save_path="benchmark_oasis_ping_pong.png")
make_interpolation_plot(dfi, title_interp, save_path="benchmark_oasis_interpolation.png")
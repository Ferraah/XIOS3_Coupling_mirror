import pandas as pd
import os
import numpy as np
import matplotlib.pyplot as plt

# Parse ping pong times from an output log file.
# @param n: Number of processes modelA
# @param m: Number of processes modelB (in this benchmark, n == m)
# @param LOGS_FILE_PATH: Path to the log file containing ping pong timings
# @param trim_outliers: Percentage of outliers to trim from the data
def parse_ping_pongs(LOGS_FILE_PATH, LINE_PREFIX, trim_outliers=0):
    times = []
    with open(LOGS_FILE_PATH) as f:
        for line in f:
            if line.startswith(LINE_PREFIX):
                times.append(float(line.strip().split()[-1]))

    if not times:
            return None, None, None, None

    # Remove outliers (top trim_outliers percent)
    if trim_outliers > 0:
        times = pd.Series(times)
        times = times[times < times.quantile(1 - trim_outliers//2 / 100)]
        times = times[times > times.quantile(trim_outliers//2 / 100)]
        #print("Removed outliers, new size:", len(times))


    avg = pd.Series(times).mean()
    var = pd.Series(times).var()
    median = pd.Series(times).median()
    ci = pd.Series(times).quantile(0.95) - pd.Series(times).quantile(0.05)
    min = pd.Series(times).min()
    max = pd.Series(times).max()

    return avg, median, var, ci, min, max

# Parse interpolation times from an output log file.
def parse_interpolations(n, LOGS_FILE_PATH, LINE_PREFIX):
    interp_times = []
    with open(LOGS_FILE_PATH) as f:
        for line in f:
            if line.startswith(LINE_PREFIX):
                # Extract the time from the line
                # Example line: "Interpolation time for src->dst: 0.123456 seconds"
                # We assume the time is always the last element in the line
                interp_times.append(float(line.strip().split()[-1]))
    if not interp_times:
        return None


    
    n_iters = len(interp_times) // (2*n)

    # Average every n processes 
    interp_times = [np.mean(interp_times[i:i + n]) for i in range(0, len(interp_times), n)]

    # Average of time of two interpolations (src->dst and dst->src) in one iteration
    avg = pd.Series(interp_times).sum() / (n_iters)

    # Sum every two element of interp_times to get the total time for each iteration
    interp_times = [interp_times[i] + interp_times[i + 1] for i in range(0, len(interp_times), 2)]
    min_times = pd.Series(interp_times).min()
    max_times = pd.Series(interp_times).max()

    return avg, min_times, max_times

def collect_interpolations_results(IS_XIOS, 
                                   NM_LIST, 
                                   RAW_TIMES_DIR, 
                                   RESULTS_CSV, 
                                   INTERPOLATION_LINE_PREFIX=""):
    records = []
    for proc in NM_LIST:
        n = proc[0]
        m = proc[1]

        # Path to the log file for this process count
        if IS_XIOS:
            interp_file_path = os.path.join(RAW_TIMES_DIR, f"interpolations_times_n{n}_m{m}.txt")
        else:
            interp_file_path = os.path.join(RAW_TIMES_DIR, f"ocean_times_n{n}_m{m}.txt")

        interp_processes = n  #@TODO: Handle case m != n if necessary
        avg_interp, min_interp, max_interp = parse_interpolations(interp_processes, interp_file_path, INTERPOLATION_LINE_PREFIX)


        # Append parsed data for this process count to the records
        records.append({
            "n": n,
            "m": m,
            "avg_interp": avg_interp,
            "min_interp": min_interp,
            "max_interp": max_interp
            })

    # Create a DataFrame from the records and save it to a CSV file
    df = pd.DataFrame(records)
    os.makedirs(os.path.dirname(RESULTS_CSV), exist_ok=True)
    df.to_csv(RESULTS_CSV, index=False)

    return df

# Collecrt results from multiple runs of the ping pong benchmark and interpolation tests.
# @param IS_XIOS: Whether the benchmark is for XIOS (True) or not (False)
# @param NM_LIST: List of process counts from test(e.g., [[N1,M1], [N2,M2], ...])
# @param PING_PONG_LINE_PREFIX: Prefix for ping pong timing lines in the log file
# @param INTERPOLATION_LINE_PREFIX: Prefix for interpolation timing lines in the log file
# @param DO_INTERPOLATION: Whether to include interpolation results in the output
# @param RESULTS_CSV: Path to save the results CSV file
def collect_results(IS_XIOS, 
                    NM_LIST, 
                    RAW_TIMES_DIR, 
                    RESULTS_CSV, 
                    PING_PONG_LINE_PREFIX="",
                    INTERPOLATION_LINE_PREFIX="",
                    PARSE_INTERPOLATIONS=True, 
                    trim_outliers=0):
    records = []
    for proc in NM_LIST:
        n = proc[0]
        m = proc[1]

        # Path to the log file for this process count
        log_file_path = os.path.join(RAW_TIMES_DIR, f"ocean_times_n{n}_m{m}.txt")

        avg_pp, med_pp, var_pp, ci_pp, min_pp, max_pp = parse_ping_pongs(log_file_path, PING_PONG_LINE_PREFIX, trim_outliers=trim_outliers)

        if PARSE_INTERPOLATIONS:
            if IS_XIOS:
                interp_file_path = os.path.join(RAW_TIMES_DIR, f"interpolations_times_n{n}_m{m}.txt")
            else:
                interp_file_path = log_file_path # For OASIS, YAC mapping times are in the same file 
            avg_interp = parse_interpolations(interp_file_path, INTERPOLATION_LINE_PREFIX)
        else:
            avg_interp = None

        # Append parsed data for this process count to the records
        records.append({
            "n": n,
            "m": n,
            "avg_pp": avg_pp,
            "var_pp": var_pp,
            "medi_pp": med_pp,
            "ci_pp": ci_pp,
            "min_pp": min_pp,
            "max_pp": max_pp,
            "avg_interp": avg_interp})

    # Create a DataFrame from the records and save it to a CSV file
    df = pd.DataFrame(records)
    os.makedirs(os.path.dirname(RESULTS_CSV), exist_ok=True)
    df.to_csv(RESULTS_CSV, index=False)

    return df

def make_ping_pong_plot(df, title, save_path):
    plt.figure(figsize=(10, 6))

    # Reference curve: perfect scaling 1/n that intersects the first point
    x0 = df['n'].iloc[0]
    y0 = df['avg_pp'].iloc[0]

    def reference_curve(n):
        return y0 * x0 / n

    # Add the reference curve
    n_vals = df['n']
    plt.plot(
        n_vals,
        reference_curve(n_vals),
        '--r',
        label=r'Perfect strong scaling $1/p$'
    )

    # Plot only averages 
    plt.plot(
        df['n'], df['avg_pp'],
        'o',
        label='Average Ping Pong Time', color='blue'
    )

    # Plot range as light gray
    plt.fill_between(
        df['n'],
        df['min_pp'],
        df['max_pp'],
        color='lightgray',
        alpha=0.5,
        label='Range (min-max)'
    )

    plt.xlabel('p (Processes per model)')
    plt.ylabel('Time (seconds)')
    plt.title(title)
    plt.xscale('log', base=2)
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(save_path)

    # Save as tex the dataframe with n, avg_pp, min_pp, max_pp, speedup, efficiency
    speedup = df['avg_pp'].iloc[0] / df['avg_pp']
    efficiency = speedup / (df['n'] / df['n'].iloc[0])  
    speedup_df = pd.DataFrame({
        'n': df['n'],
        'avg_pp': df['avg_pp'],
        'min_pp': df['min_pp'],
        'max_pp': df['max_pp'],
        'speedup': speedup,
        'efficiency': efficiency
    })
    speedup_df.to_latex(save_path.replace('.svg', '.tex'), index=False)



def make_interpolation_plot(df, title, save_path):
    plt.figure(figsize=(10, 6))

    # Actual data
    plt.plot(
        df['n'], df['avg_interp'],
        '-bo',
        label='Average'
    )

    # Reference curve: perfect scaling 1/n that intersects the first point
    x0 = df['n'].iloc[0]
    y0 = df['avg_interp'].iloc[0]

    def reference_curve(n):
        return y0 * x0 / n

    # Add the reference curve
    n_vals = df['n']
    plt.plot(
        n_vals,
        reference_curve(n_vals),
        '--r',
        label=r'Perfect strong scaling $1/p$'
    )

    plt.fill_between(
        df['n'],
        df['min_interp'],
        df['max_interp'],
        color='lightgray',
        alpha=0.5,
        label='Range (min-max)'
    )

    # Y-limit
    # plt.ylim(0, 350)

    # Log scale on x-axis (optional, since you mention it's based on powers of 2)
    plt.xscale('log', base=2)

    # Labels, title, etc.
    plt.xlabel('p (Processes per model)')
    plt.ylabel('Time (seconds)')
    plt.title(title)
    plt.legend()
    plt.grid(True)
    plt.tight_layout()

    # Save to file
    plt.savefig(save_path)


    # Plot speedup and efficiency
    # Note: baseline is n=2, which is first element in df['n']
    plt.figure(figsize=(10, 6))
    n_ref = df['n'].iloc[0]
    speedup = df['avg_interp'].iloc[0] / df['avg_interp']
    efficiency = speedup / (df['n']/n_ref)

    # Ideal curves
    ideal_speedup = df['n'] / n_ref

    # Speedup plot
    plt.figure(figsize=(10, 6))
    plt.plot(df['n'], speedup, 'o-', label='Speedup', color='green')
    plt.plot(df['n'], ideal_speedup, '--', label='Ideal Speedup', color='gray')
    plt.xlabel('p (Processes per model)')
    plt.ylabel('Speedup')
    plt.title('Speedup')
    plt.xscale('log', base=2)
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(save_path.replace('.svg', '_speedup.svg'))

    # Print table of n, avg_interp, speedup, efficiency
    speedup_df = pd.DataFrame({
        'n': df['n'],
        'avg_interp': df['avg_interp'],
        'speedup': speedup,
        'efficiency': efficiency
    })
    print(speedup_df)



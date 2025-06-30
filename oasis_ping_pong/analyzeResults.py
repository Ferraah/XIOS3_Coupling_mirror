import pandas as pd
import os
import matplotlib.pyplot as plt


def parse_timing(n, m, OUTPUT_DIR="outputs"):
    output_file = f"{OUTPUT_DIR}/ocean_times_n{n}_m{m}.txt"
    times = []
    with open(output_file) as f:
        for line in f:
            if line.startswith(" TIMING:"):
                times.append(float(line.strip().split()[-1]))

    if not times:
            return None, None, None, None

    avg = pd.Series(times).mean()
    var = pd.Series(times).var()
    median = pd.Series(times).median()
    ci = pd.Series(times).quantile(0.95) - pd.Series(times).quantile(0.05)

    return avg, median, var, ci

def parse_yac(n, m, OUTPUT_DIR="outputs"):
    output_file = f"{OUTPUT_DIR}/ocean_times_n{n}_m{m}.txt"
    yac_times = []
    with open(output_file) as f:
        for line in f:
            if line.startswith(" YAC mapping time ="):
                yac_times.append(float(line.strip().split()[-1]))

    if not yac_times:
        return None
    # Average all processes interpolation times, both from src->dst and dst->src
    avg = pd.Series(yac_times).mean()

    return avg

def make_plots(csv_path = "results/scaling_results.csv"):
    
    if not os.path.exists(csv_path):
        print(f"CSV file {csv_path} not found.")
        return
    df = pd.read_csv(csv_path)

    # Plotting Ping Pong results
    plt.figure(figsize=(10, 6))
    plt.errorbar(df['n'], df['avg_pp'], yerr=df['ci_pp'], label='Ping Pong', fmt='o')
    plt.xlabel('N (Number of Processes)')
    plt.ylabel('Time (seconds)')
    plt.title('Oasis Ping Pong Benchmark Results')
    plt.legend()
    plt.grid()
    plt.savefig("benchmark_ping_pong_results.png")
    plt.show()
    plt.close()

    # Plotting YAC results
    plt.figure(figsize=(10, 6))
    plt.errorbar(df['n'], df['avg_yac'], label='YAC', fmt='o')
    plt.xlabel('N (Number of Processes)')
    plt.ylabel('Time (seconds)')
    plt.title('Oasis YAC Benchmark Results')
    plt.legend()
    plt.grid()
    plt.savefig("benchmark_yac_results.png")
    plt.show()
    plt.close()

#make_plots()
#print(parse_yac(16, 16))
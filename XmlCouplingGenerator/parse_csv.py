import pandas as pd

# Returns the names of the components and the dataframe with the coupled fields
def parse_coupled_fields_from_csv(path):

    df = pd.read_csv(path, header=0, encoding='latin1')

    # All labels of source and destination components
    src_comp = df['src_comp'].unique().tolist()
    dst_comp = df['dst_comp'].unique().tolist()
    all_comp = set(src_comp + dst_comp)
    print("All components of source and destination:", all_comp)

    print(df)
    return all_comp, df 

def generate_fortran_labels(all_comp, df):
    """
    Generate Fortran labels for the fields in the DataFrame.
    """
    # For each model, retrieved the labels of the src_var and dst_var
    for comp in all_comp:
        src_vars = df[df['src_comp'] == comp]['src_var'].unique().tolist()
        dst_vars = df[df['dst_comp'] == comp]['dst_var'].unique().tolist()
        print(f"Component: {comp}")
        print(f"len={len(src_vars)} Source variables:", src_vars)
        print(f"len={len(dst_vars)} Destination variables:", dst_vars)
        print()

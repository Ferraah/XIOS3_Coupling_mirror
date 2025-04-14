import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

import numpy as np
from math import gcd

class XiosCouplerPlotter:
    
    field_bottom_label = "OCN"
    field_top_label = "ATM"

    '''
        Add ticks but manually add the labels of the timesteps between two consecutive ticks.
    '''
    def _set_timesteps_ticks(self, ax, top_duration, bottom_duration):
        # The number of ticks are the number of timesteps + 1

        lcm = (top_duration * bottom_duration) // gcd(top_duration, bottom_duration)
        ax.set_xticks(range(0, lcm+1))
        ax.set_yticks([])

        # Show ticks on bottom and top
        ax.tick_params(axis='x', which='both', top=True, bottom=True)
        ax.set_xlabel("XIOS timestep", labelpad=20)


        # FIELDS LABELS
        ax.text(-0.5, -0.5, self.field_bottom_label, ha='center', va='center', color='black')
        ax.text(-0.5, self.figsize[1] + 0.5, self.field_top_label, ha='center', va='center', color='black')

        # Setting manually the labels of the timesteps between two consecutive ticks,
        # meaning placing the timestep 1 label between t=0 and t=1 and so on.
        step = lcm // top_duration
        for t in range(0, top_duration):
            ax.text(t*step + step/2, 1, str(t+1), ha='center', va='bottom', color='black')
        
        step = lcm // bottom_duration 
        for t in range(0, bottom_duration):
            ax.text(t*step + step/2, 0, str(t+1), ha='center', va='top', color='black')

        # Remove the default tick labels
        ax.set_xticklabels([])  # Hide major tick labels

        # Gray delimiters for the timesteps
        ax.grid(axis='x', linestyle='--', alpha=0.6)

    '''
        Add the arrows representing xios_recv_field on the restart file
    '''
    def _add_startup_arrow(self, ax, restart_file):
        if(restart_file):
            ax.arrow(-self.padding, self.arrow_height, 2*self.padding, self.figsize[1]-self.arrow_height, head_width=0.1, head_length=0.05, color='orange', label="xios_recv_field(field_restart)")

    '''
        Add the arrows representing xios_send_field and xios_recv_field.
    '''
    def _add_internal_exchanges(self, ax, top_duration, bottom_duration, recv_freq, recv_offset, restart_file):

        lcm = (top_duration * bottom_duration) // gcd(top_duration, bottom_duration)
        
        step = lcm // bottom_duration

         # Upward arrows and Downward arrows
        for ts in range(1, bottom_duration+1):
            x_pos = ts*step - self.padding
            # Upward blue arrows slightly before the tick with shorter height
            ax.add_patch(mpatches.FancyArrowPatch((x_pos, 0), (x_pos, self.arrow_height), color='b', arrowstyle='->', mutation_scale=10))


        step = lcm // top_duration 
        # Upward arrows and Downward arrows
        for ts in range(1, top_duration+1):
            x_pos = (ts-1)*step + self.padding
            # Reciving calls are only done at coupling frequency (current limitation of XIOS)
            # Do not plot the first receive if there is a starting file recv
            # If there is no file to load, then plot the arrow also at the first timestep
            if (ts-1) % recv_freq == 0 and (ts >= recv_offset or not restart_file):
                ax.add_patch(mpatches.FancyArrowPatch((x_pos, 1), (x_pos, 1-self.arrow_height), color='r', arrowstyle='->', mutation_scale=10,
                    label="xios_recv_field(field_recv)" if ts == recv_offset else ""))



    '''
        Add the links connecting the sender and receiving arrows when the coupling is done.
    '''
    def _add_coupling_links(self, ax, top_duration, bottom_duration, send_freq, send_offset, restart_file):

        lag = 1 if restart_file else 0 

        lcm = (top_duration * bottom_duration) // gcd(top_duration, bottom_duration)
        step_bottom = lcm // bottom_duration
        step_top = lcm // top_duration

        # Emulating the behaviour of XIOS paramaters, still to indagate
        starting_timestep = send_freq + send_offset 

        # Display coupling (connect the arrows)
        for ts in range(starting_timestep, top_duration+1, send_freq):
            # Draw a line connecting the arrowheads
            begin = (ts*step_bottom-self.padding, self.arrow_height)
            end  = ((ts-1)*step_top+ lag + self.padding, 1 - self.arrow_height)
            if(ts > 0):
                ax.add_patch(mpatches.FancyArrowPatch(begin, end, color='b', arrowstyle='->', mutation_scale=10))
                # ax.plot([ts - self.padding, ts - 1 + lag + self.padding], [self.arrow_height, self.figsize[1] - self.arrow_height], color='gray', linestyle='--', alpha=0.7)

        # -------------------------

    '''
        Add the arrow representing the savinfile call done in XIOS.
    '''
    def _add_savinfile_arrow(self, ax, timesteps, save_file):
        # Save to file arrow
        if(save_file):
            ax.arrow(timesteps - self.padding, self.arrow_height, 2*self.padding, self.figsize[1]-2*self.arrow_height, head_width=0.1, head_length=0.05, color='purple', label="Save to file by XIOS")
        # -------------------------

    '''
        Add the legend to the plot.
    '''
    def _add_legend(self, plt):
        # Add arrows legend
        plt.legend(loc='upper center', bbox_to_anchor=(0.5, -0.2),
            fancybox=True, shadow=True, ncol=2)

    def _add_parameters_to_legend(self, ax, send_freq, recv_freq, send_offset, recv_offset):

        label = f"  {self.field_bottom_label}      →      {self.field_top_label}" 
        plt.plot([],[], ' ', label=f"{label}\nfreq_op: {send_freq}      freq_op: {recv_freq}\nfreq_offset: {send_offset} freq_offset: {recv_offset}")

    # def __init__(self, figsize=None, arrow_height=2, padding=0.2):
    #     self.figsize = figsize
    #     self.arrow_height = arrow_height
    #     self.padding = padding

    def plot(self, top_duration, bottom_duration, send_freq, recv_freq, recv_offset, send_offset, restart_file=False, save_file=False, title="XIOS Coupling Diagram", path="xios_coupling_plot.png"):


        lcm = (top_duration * bottom_duration) // gcd(top_duration, bottom_duration)
        # Set plot style and size
        self.figsize = (lcm//1.5, 5)  # Width and height of the figure

        self.arrow_height = 0.33  # Adjust arrow height based on figure height
        self.padding = 0.2  # Padding for the arrows


        _, ax = plt.subplots(figsize=self.figsize) 
        #plt.subplots_adjust(bottom=0.3) # Some margins to avoid overlapping with the legend
        
        # -------------------------------------------------------------------------------- #
        ax.set_title(title, pad=20)  # Move title lower by increasing pad
        self._set_timesteps_ticks(ax, top_duration, bottom_duration)
        # self._add_startup_arrow(ax, restart_file)
        self._add_internal_exchanges(ax, top_duration, bottom_duration, recv_freq, recv_offset, restart_file) 
        self._add_coupling_links(ax, top_duration, bottom_duration, send_freq, send_offset, restart_file) 
        # self._add_savinfile_arrow(ax, bottom_duration, save_file)
        # self._add_parameters_to_legend(plt, send_freq, recv_freq, send_offset, recv_offset)
        # self._add_legend(plt)
        # -------------------------------------------------------------------------------- #

        # Save and close
        plt.savefig(path)
        plt.close()

        self.figsize = None

# Style attributes when initializing class
pl = XiosCouplerPlotter()

# Specific algorithm parameters for the plot
pl.plot(top_duration=24, bottom_duration=16, send_freq=2, send_offset=-1, recv_freq=3, recv_offset=1,  restart_file=False, save_file=False)
#pl.plot(top_duration=31, bottom_duration=31, send_freq=4, send_offset=-3, recv_freq=4, recv_offset=1)


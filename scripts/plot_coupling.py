import matplotlib.pyplot as plt
import numpy as np

class XiosCouplerPlotter:
    
    '''
        Add ticks but manually add the labels of the timesteps between two consecutive ticks.
    '''
    def _set_timesteps_ticks(self, ax, timesteps):
        # The number of ticks are the number of timesteps + 1
        ax.set_xticks(range(0, timesteps+1))
        ax.set_yticks([])

        # Show ticks on bottom and top
        ax.tick_params(axis='x', which='both', top=True, bottom=True)
        ax.set_xlabel("XIOS timestep", labelpad=20)

        # Setting manually the labels of the timesteps between two consecutive ticks,
        # meaning placing the timestep 1 label between t=0 and t=1 and so on.
        for t in range(0, timesteps):
            ax.text(t + 0.5, -0.5, str(t+1), ha='center', va='center', color='black')
            ax.text(t + 0.5, self.figsize[1] + 0.5, str(t+1), ha='center', va='center', color='black')

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
    def _add_internal_exchanges(self, ax, timesteps, recv_freq, recv_offset, restart_file):
         # Upward arrows and Downward arrows
        for ts in range(1, timesteps+1):
            time = ts - 1  # Adjust for zero-based indexing

            # Reciving calls are only done at coupling frequency (current limitation of XIOS)
            # Do not plot the first receive if there is a starting file recv
            # If there is no file to load, then plot the arrow also at the first timestep
            if (ts-1) % recv_freq == 0 and (ts >= (recv_offset+1) or not restart_file):

                ax.arrow(time + self.padding, self.figsize[1] - self.arrow_height, 0, self.arrow_height, head_width=0.1, head_length=0.05, 
                    color='r',
                    label=("xios_recv_field(field_recv)" if ts == recv_offset # For legend purpouses
                        else ""))

            # Upward blue arrows slightly before the tick with shorter height
            ax.arrow(time + 1 - self.padding, 0, 0, self.arrow_height, head_width=0.1, head_length=0.05, color='b', label="xios_send_field(field_send)" if time == 0 else "")

    '''
        Add the links connecting the sender and receiving arrows when the coupling is done.
    '''
    def _add_coupling_links(self, ax, timesteps, send_freq, send_offset, restart_file):

        lag = 1 if restart_file else 0 

        # Display coupling (connect the arrows)
        for ts in range(send_offset, timesteps+1, send_freq):
            # Draw a line connecting the arrowheads
            if(ts > 0):
                ax.plot([ts - self.padding, ts - 1 + lag + self.padding], [self.arrow_height, self.figsize[1] - self.arrow_height], color='gray', linestyle='--', alpha=0.7)
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
    def add_legend(self, plt):
        # Add arrows legend
        plt.legend(loc='upper center', bbox_to_anchor=(0.5, -0.2),
            fancybox=True, shadow=True, ncol=2)

    def add_parameters_to_legend(self, ax, send_freq, recv_freq, send_offset, recv_offset):
        plt.plot([],[], ' ', label=f"send_freq: {send_freq} send_offset: {send_offset}\nrecv_freq: {recv_freq} recv_offset: {recv_offset}")

    def __init__(self, figsize=None, arrow_height=2, padding=0.2):
        self.figsize = figsize
        self.arrow_height = arrow_height
        self.padding = padding

    def plot(self, timesteps, send_freq, recv_freq, recv_offset, send_offset, restart_file=False, save_file=False, title="XIOS Coupling Diagram", path="xios_coupling_plot.png"):

        # Set plot style and size
        if self.figsize is None:
            self.figsize = (timesteps//1.5, 5)  # Width and height of the figure

        self.arrow_height = self.figsize[1] // 3  # Adjust arrow height based on figure height
        self.padding = 0.2  # Padding for the arrows


        _, ax = plt.subplots(figsize=self.figsize) 
        plt.subplots_adjust(bottom=0.3) # Some margins to avoid overlapping with the legend

        # -------------------------------------------------------------------------------- #
        ax.set_title(title, pad=20)  # Move title lower by increasing pad
        self._set_timesteps_ticks(ax, timesteps)
        self._add_startup_arrow(ax, restart_file)
        self._add_internal_exchanges(ax, timesteps, recv_freq, recv_offset, restart_file) 
        self._add_coupling_links(ax, timesteps, send_freq, send_offset, restart_file) 
        self._add_savinfile_arrow(ax, timesteps, save_file)
        self.add_parameters_to_legend(plt, send_freq, recv_freq, send_offset, recv_offset)
        self.add_legend(plt)
        # -------------------------------------------------------------------------------- #

        # Save and close
        plt.savefig(path)
        plt.close()

        self.figsize = None

# Style attributes when initializing class
pl = XiosCouplerPlotter(arrow_height=2, padding=0.2)

# Specific algorithm parameters for the plot
#pl.plot(timesteps=20, send_freq=4, recv_freq=4, recv_offset=5, send_offset=0, restart_file=True, save_file=True)
pl.plot(timesteps=128, send_freq=4, recv_freq=4, recv_offset=1, send_offset=0, restart_file=True, save_file=True)

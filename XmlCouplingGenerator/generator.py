import xml.etree.ElementTree as ET
from xml.dom import minidom
from dataclasses import dataclass
from parse_csv import parse_coupled_fields_from_csv, generate_fortran_labels


def prettify(elem):
    """Return a pretty-printed XML string for the Element."""
    rough_string = ET.tostring(elem, 'utf-8')
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="    ")

@dataclass
class TemporalParams:
    operation: str
    sampling_freq_op: str
    sampling_freq_offset: str
    coupler_send_freq_op: str
    coupler_restart_send_freq_op: str
    coupler_recv_freq_op: str
    coupler_recv_freq_offset: str
    coupler_restart_recv_freq_op: str
    coupler_restart_recv_freq_offset: str
    file_output_freq: str
    file_restart_output_freq: str
    file_restart_record_offset: str

def generate_initial_context(context_id, timestep, total_duration, all_components):
    """Create a context element with basic structure."""
    context = ET.Element("context", id=context_id)
    ET.SubElement(context, "calendar", type="Gregorian", time_origin="2025-01-01", start_date="2025-01-01")

    grid_def = ET.SubElement(context, "grid_definition")
    for comp in all_components:
        grid = ET.SubElement(grid_def, "grid", id="grid_2D_"+comp)
        domain = ET.SubElement(grid, "domain", id="domain_"+comp)
        ET.SubElement(domain, "generate_rectilinear_domain")

    var_def = ET.SubElement(context, "variable_definition")
    variables = [
        ("toymodel_timestep_duration", timestep),
        ("toymodel_duration", total_duration),
        ("toymodel_ni_glo", "10"),
        ("toymodel_nj_glo", "10"),
        ("toymodel_type", "rectilinear"),
    ]
    for var_id, value in variables:
        ET.SubElement(var_def, "variable", id=var_id).text = value

    ET.SubElement(context, "field_definition")
    ET.SubElement(context, "coupler_out_definition")
    ET.SubElement(context, "coupler_in_definition")
    ET.SubElement(context, "file_definition")
    return context

def append_coupled_fields(root, user_fields):
    """Append coupled field definitions and related elements to the XML tree."""
    for field in user_fields:
        context_sender = root.find(f"context[@id='{field['sender_context']}']")
        context_receiver = root.find(f"context[@id='{field['receiver_context']}']")
        field_def_sender = context_sender.find("field_definition")
        field_def_receiver = context_receiver.find("field_definition")
        coupler_out_def = context_sender.find("coupler_out_definition")
        coupler_in_def = context_receiver.find("coupler_in_definition")
        file_definition = context_sender.find("file_definition")

        # Field definitions
        ET.SubElement(
            field_def_sender, "field",
            id=field['sender_field'],
            grid_ref="grid_2D_"+field['sender_context'],
            operation=field['temporal_params'].operation,
            freq_op=field['temporal_params'].sampling_freq_op,
            freq_offset=field['temporal_params'].sampling_freq_offset
        )

        ET.SubElement(
            field_def_receiver, "field",
            id=field['receiver_field'],
            field_ref=field['cpl_interface']
        )

        # Coupler out/in
        coupler_out = ET.SubElement(
            coupler_out_def, "coupler_out",
            context=f"{field['receiver_context']}::{field['receiver_context']}"
        )

        ET.SubElement(
            coupler_out, "field",
            id=field['cpl_interface'],
            field_ref=field['sender_field'],
            freq_op=field['temporal_params'].coupler_send_freq_op,
            expr="@this_ref"
        )
        coupler_in = ET.SubElement(
            coupler_in_def, "coupler_in",
            context=f"{field['sender_context']}::{field['sender_context']}"
        )
        ET.SubElement(
            coupler_in, "field",
            id=field['cpl_interface'],
            grid_ref="grid_2D_" + field['sender_context'],
            freq_op=field['temporal_params'].coupler_recv_freq_op,
            freq_offset=field['temporal_params'].coupler_recv_freq_offset,
            read_access="true"
        )

        # Restart fields
        file_field_name = field['restart_field'] + "_read"
        ET.SubElement(
            coupler_out, "field",
            id=field['restart_field'],
            field_ref=file_field_name,
            freq_op="1y"
        )

        ET.SubElement(
            coupler_in, "field",
            id=field['restart_field'],
            grid_ref="grid_2D_" + field['sender_context'],
            freq_op="1y",
            freq_offset="1ts",
            read_access="true"
        )

        # RESTART file definition ---------------------------------------------------

        # Restart file (add only if not already present)
        if not any(f.get("id") == field["restart_file_name"] for f in file_definition.findall("file")):
            file = ET.SubElement(
                file_definition, "file",
                id=field["restart_file_name"],
                name=field["restart_file_name"],
                enabled="true",
                type="one_file",
                output_freq=field['temporal_params'].file_restart_output_freq,
                record_offset=field['temporal_params'].file_restart_record_offset,
                mode="read"
            )
        else:
            file = file_definition.find(f"file[@id='{field['restart_file_name']}']")

        # If specified, use the restart field in the file
        if 'restart_field_in_file' in field:
            field_in_restart_file = field['restart_field_in_file']
        else:
            field_in_restart_file = field['restart_field']

        print(f"Adding restart field {file_field_name} to file {field['restart_file_name']} in context {field['sender_context']}") 
        # Add restart field to the file
        ET.SubElement(
            file, "field",
            id=file_field_name,
            name=field_in_restart_file,
            grid_ref="grid_2D_" + field['sender_context'],
            operation="instant",
            read_access="true"
        )

        # OUTPUT file -----------------------------------------------------------------
        output_file = ET.SubElement(
            file_definition, "file",
            id=field['output_file_name'],
            name=field['output_file_name'],
            output_freq=field['temporal_params'].file_output_freq,
            type="one_file",
            enabled="true",
            append="false"
        )

        ET.SubElement(
            output_file, "field",
            field_ref=field['cpl_interface'],
            name=field['cpl_interface']
        )

    return root

def generate_xios_context():
    """Generate the default XIOS context."""
    xios = ET.Element("context", id="xios")
    var_def = ET.SubElement(xios, "variable_definition")
    var_grp = ET.SubElement(var_def, "variable_group", id="parameters")
    ET.SubElement(var_grp, "variable", id="print_file", type="bool").text = "true"
    ET.SubElement(var_grp, "variable", id="transport_protocol", type="string").text = "p2p"
    return xios

def create_standard_temporal_params( 
        total_duration,
        coupler_send_freq_op,
        coupler_recv_freq_op,
        operation="instant", 
        sampling_freq_op="1ts",
        sampling_freq_offset="0ts"):

    # Given a timestep string, create another one with an offset
    def add_ts_string(original, offset):
        if original.endswith("ts"):
            return f"{int(original[:-2]) + offset}ts"


    """Create standard parameters for the XML generation."""
    return TemporalParams(
        operation=operation,
        sampling_freq_op=sampling_freq_op,
        sampling_freq_offset=sampling_freq_offset,
        coupler_send_freq_op=coupler_send_freq_op,
        coupler_restart_send_freq_op=total_duration,
        coupler_recv_freq_op=coupler_recv_freq_op,
        coupler_recv_freq_offset=add_ts_string(coupler_recv_freq_op, 1),
        coupler_restart_recv_freq_op="100000y",
        coupler_restart_recv_freq_offset="1ts",
        file_output_freq=total_duration,
        file_restart_output_freq="100000y",
        file_restart_record_offset="0"
    )


def generate_xml():

    all_components, df = parse_coupled_fields_from_csv(path="cmip6.csv")
    generate_fortran_labels(all_components, df)

    total_duration = "1d" 

    root = ET.Element("simulation")

    for comp_name in all_components:
        root.append(generate_initial_context(context_id=comp_name, timestep="3600s", total_duration=total_duration, all_components=all_components))

    # Create standard temporal parameters object 
    temporal = create_standard_temporal_params(
                total_duration=total_duration,
                coupler_send_freq_op="1ts",
                coupler_recv_freq_op="1ts",
                operation="instant")

    coupling_params = []
    print(df)
    # Iterate through the DataFrame to create coupling parameters
    for _, row in df.iterrows():
        sender_context = row['src_comp'].strip()
        receiver_context = row['dst_comp'].strip()
        sender_field = row['src_var'].strip()
        receiver_field = row['dst_var'].strip()
        coupling_params.append({
            "sender_context": sender_context,
            "receiver_context": receiver_context,
            "sender_field": sender_field,
            "receiver_field": receiver_field,
            "restart_field": f"{receiver_field}_restart",
            "restart_file_name": "zero_restart_file",
            "restart_field_in_file": "zero_restart",
            "output_file_name": f"{sender_field}_next",
            "cpl_interface":  f"{sender_field}_to_{receiver_field}",
            "temporal_params": temporal
        })




    # Append coupled fields to the XML tree following the provided parameters
    append_coupled_fields(root, coupling_params)

    # Append standard XIOS context
    root.append(generate_xios_context())

    xml_str = prettify(root)
    with open("coupling_config.xml", "w") as f:
        f.write(xml_str)
    print("✅ XML written to coupling_config.xml")

if __name__ == "__main__":
    generate_xml()

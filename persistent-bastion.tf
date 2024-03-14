resource "oci_core_instance" "bastion" {

    lifecycle {
        ignore_changes = [
            source_details,
        ]
    }

    compartment_id = "ocid1.compartment.oc1..."
    availability_domain = "abcd:...AD-1"
    shape = "VM.Standard3.Flex"
    state = "RUNNING"
    display_name = "persistent-bastion"

    is_pv_encryption_in_transit_enabled = true

    source_details {
        source_id = "ocid1.image.oc1..." 
        source_type = "image"
        boot_volume_size_in_gbs = 50 
        boot_volume_vpus_per_gb = 10

        instance_source_image_filter_details {
            compartment_id = "ocid1.compartment.oc1..."
        }
    }

    create_vnic_details {
        hostname_label = "persistent-bastion"
        assign_public_ip = true 
        subnet_id = "ocid1.subnet.oc1...."
    }

    launch_options {
        boot_volume_type = "PARAVIRTUALIZED"
        network_type = "PARAVIRTUALIZED"
    }

    shape_config {
        ocpus = 1
        memory_in_gbs = 8
    }

    metadata = {
        "ssh_authorized_keys" = "ssh-rsa ..."
        user_data = "${base64encode(file("./install.sh"))}"
    }

    freeform_tags = {
        name = "persistent-bastion"
        platform = "Oracle Linux 9"
    }
}
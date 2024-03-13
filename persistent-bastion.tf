resource "oci_core_instance" "bastion" {

    lifecycle {
        ignore_changes = [
            source_details,
        ]
    }

    compartment_id = "ocid1.tenancy.oc1..aaaaaaaazvwxkafidkrx7cl6o6fmtkhqfnzg2c2vklo77g237wa2xvv75ohq"
    availability_domain = "rgiR:US-SANJOSE-1-AD-1"
    shape = "VM.Standard3.Flex"
    state = "RUNNING"
    display_name = "persistent-bastion"

    is_pv_encryption_in_transit_enabled = true

    source_details {
        source_id = "ocid1.image.oc1.us-sanjose-1.aaaaaaaastmjltdybyyrrhydqyrhpauw2opnffhlqg6yqsuasvmsbv4gq6pa" 
        source_type = "image"
        boot_volume_size_in_gbs = 50 
        boot_volume_vpus_per_gb = 10

        instance_source_image_filter_details {
            compartment_id = "ocid1.tenancy.oc1..aaaaaaaazvwxkafidkrx7cl6o6fmtkhqfnzg2c2vklo77g237wa2xvv75ohq"
        }
    }

    create_vnic_details {
        hostname_label = "ipersistent-bastion"
        assign_public_ip = true 
        subnet_id = "ocid1.subnet.oc1.us-sanjose-1.aaaaaaaarawqasyronbogrzzxisecljtvmgpwxnj6xbarkhhzg5eyhohbrhq"
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
        "ssh_authorized_keys" = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCmO4xz6XnbRWdVZStWMxTGqy52hG9/kjxagEI3ZX1gevqbvKH7hhh6sNcScuraTKomk0kk6d5Azc85XZYsEvETU4ENvEUV6dhuEdCWmK7afvdoPQb82R8SqDs/6Wdr/BxBDcqYYya2VpAJ31xn5d0TfHZXZbm/fVoPemXq/fWW3QMLFmgGoCNPjgACYlxliY2ecrpvw2Uetk7HvpDXNxMXaGGvaZKVZfEj2PW/SRI0jGvlJN+1nI16C4d7qPXPPI+ix63tcLa4qSdsEsjcCsiImauG+bV1saeRH6DM11KvlQul4GuCOSyNh1MvR8vxfI3++CkTq86ApReInHYcn8KJt4zndYcdADIU1KZDlGxDFhDSGNj0maXgnIU+l/BC1S/V/6Y4BZFJi5JAPzYz0DO8IALFiKi+l2af01Llx4OhVjaNUVRClTmjpxFzIq19UUc5nX91HMvLPFfA3ENAouadfE13f2pQ+LrKw0Zxzvu2XrUAtKs2i7MX35/4+eWFZYc= tomarkel@tomarkel-mac"
        user_data = "${base64encode(file("./install.sh"))}"
    }

    freeform_tags = {
        name = "persistent-bastion"
        platform = "Oracle Linux 9"
    }
}
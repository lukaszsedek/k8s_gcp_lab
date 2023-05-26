
locals {
  vpc_name         = format("%s-%s-vpc-01", var.tenant_name, var.environment)
  subnet_name      = format("%s-%s-%s-subnet", var.tenant_name, var.environment, var.region)
  master_node_name = format("vm-%s-%s-master", var.tenant_name, var.environment)
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 7.0"

  project_id   = var.project_id
  network_name = local.vpc_name
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name           = local.subnet_name
      subnet_ip             = "10.10.20.0/24"
      subnet_region         = var.region
      subnet_private_access = "true"
      subnet_flow_logs      = "false"
      description           = "This subnet has a description"
    }
  ]

  routes = [
    {
      name              = "egress-internet"
      description       = "route through IGW to access internet"
      destination_range = "0.0.0.0/0"
      tags              = "egress-inet"
      next_hop_internet = "true"
    }
  ]

}

resource "google_service_account" "default" {
  account_id   = "kubernetes-compute-sa"
  display_name = "Service Account"

}

#35.235.240.0/20 on port 22.
resource "google_compute_firewall" "rules" {
  project     = var.project_id # Replace this with your project ID in quotes
  name        = "allow-ssh-from-internet"
  network     = local.vpc_name
  description = "Creates firewall rule targeting tagged instances"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges      = ["35.235.240.0/20"]
  destination_ranges = ["10.10.20.0/24"]

}

resource "google_compute_instance" "k8s-cluster-master" {
  name           = "${local.master_node_name}-01"
  machine_type   = "e2-standard-2"
  zone           = "${var.region}-a"
  project        = var.project_id
  can_ip_forward = true

  tags = ["foo", "bar"]

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20230524"
      labels = {
        my_label = "value"
      }

    }
  }

  // Local SSD disk
  #scratch_disk {
  #  interface = "SCSI"

  network_interface {
    subnetwork = local.subnet_name

    #access_config {
    // Ephemeral public IP
    #}
  }

  metadata = {
    startup_script = <<EOF
sudo apt update
sudo apt install golang-go -y
echo "Installing cfssljson & cfssl..."
sudo apt install golang-cfssl
cfssl version
cfssljson --version
echo "cfssljson & cfssl installation completed"

echo "Installing kubectl..."
wget https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
echo "kubectl installation completed"
EOF

  }


  service_account {
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    module.vpc,
    google_service_account.default
  ]
}

resource "google_compute_router" "rtr1" {
  name    = "rtr-${var.project_id}-01"
  network = local.vpc_name
  project = var.project_id

  depends_on = [module.vpc]
}

resource "google_compute_router_nat" "nat" {
  name                               = "my-router-nat"
  router                             = google_compute_router.rtr1.name
  region                             = google_compute_router.rtr1.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  depends_on                         = [google_compute_router.rtr1]
}

# Google Cloud Terraform Configuration

## Overview

This repository contains a Terraform configuration for setting up a Google Cloud environment. The configuration includes the creation of a VPC network, subnets, firewall rules, NAT configuration, Cloud SQL, Cloud Run services, IAM policies, and necessary outputs.

## Prerequisites

Before applying this Terraform configuration, ensure you have:

1. A Google Cloud Platform account.
2. The Google Cloud SDK installed and authenticated.
3. Terraform installed.

## Getting Started

### Set Up Google Cloud Project and Region

Required google provider for terraform

```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.23.0"
    }
  }
}
provider "google" {
 # Configuration options
project = var.project_id
region = var.region
}
```
Edit the variables.tf file to set your Google Cloud project ID and region:

```hcl
variable "project_id" {
  description = "The ID of the project in which to provision resources."
  default     = "your-project-id"
}

variable "region" {
  description = "The region in which to provision resources."
  default     = "your-region"
}
```
Replace your-project-id and your-region with your actual project ID and desired region.
## Resources
### VPC Network
```hcl
resource "google_compute_network" "vpc_network" {
  name                    = "vpc-network"
  auto_create_subnetworks = false
  mtu                     = 1460
}
```
This resource creates a VPC network named vpc-network without automatic subnet creation and with an MTU of 1460.

### Subnetworks
#### Public Subnet
```hcl
resource "google_compute_subnetwork" "public_subnet" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.name
}
```
This resource creates a public subnet named public-subnet with the IP CIDR range 10.0.1.0/24 in the specified region.
#### Private Subnet
```hcl
resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  purpose       = "PRIVATE_NAT"
  network       = google_compute_network.vpc_network.name
}
```
This resource creates a private subnet named private-subnet with the IP CIDR range 10.0.2.0/24 in the specified region. The subnet is designated for private NAT.
#### Firewall Rules
```hcl
resource "google_compute_firewall" "my_firewall" {
  name    = "my-firewall"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "8080"]
  }

  source_ranges = ["0.0.0.0/0"]
}
```
This resource creates a firewall rule named my-firewall allowing ICMP and TCP traffic on ports 80 and 8080 from any source IP address.
### Router and NAT Configuration
#### Router
```hcl
resource "google_compute_router" "router" {
  name    = "my-router"
  region  = google_compute_subnetwork.private_subnet.region
  network = google_compute_network.vpc_network.id

  bgp {
    asn = 64514
  }
}
```
This resource creates a router named my-router in the specified region, associated with the VPC network, and configured with BGP ASN 64514.

#### NAT Configuration
```hcl
resource "google_compute_router_nat" "nat" {
  name                               = "my-router-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
```
This resource creates a NAT configuration named my-router-nat for the router. It allows auto IP allocation and NAT for all IP ranges in the private subnet. Logging is enabled for errors only.

### Cloud Run Services
#### Cloud Run Service
```hcl
resource "google_cloud_run_service" "cloudrun" {
  name     = "cloudrun"
  location = var.region

  template {
    spec {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}
```
This resource creates a Cloud Run service named cloudrun in the specified region, using the specified container image, with 100% traffic directed to the latest revision.

#### Lambda Cloud Run Service
```hcl
resource "google_cloud_run_service" "lambda_cloudrun" {
  name     = "lambda-cloudrun"
  location = var.region

  template {
    spec {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}
```
This resource creates another Cloud Run service named lambda-cloudrun, similar to the previous one.

### IAM Policy for Cloud Run Service
#### IAM Policy
```hcl
data "google_iam_policy" "admin" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "policy" {
  location    = google_cloud_run_service.cloudrun.location
  project     = google_cloud_run_service.cloudrun.project
  service     = google_cloud_run_service.cloudrun.name
  policy_data = data.google_iam_policy.admin.policy_data
}
```
This configuration sets an IAM policy to grant the run.invoker role to all users for the cloudrun service.

### Cloud SQL Configuration
#### Global Address for VPC Peering
```hcl
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}
```
This resource reserves an internal global IP address named private-ip-address for VPC peering, with a prefix length of 16.

#### Service Networking Connection
```hcl
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}
```
This resource establishes a private VPC connection to the servicenetworking.googleapis.com service using the reserved peering range.

#### SQL Instance
```hcl
resource "google_sql_database_instance" "sql_instance" {
  name             = "sql-instance"
  region           = var.region
  database_version = "POSTGRES_10"
  depends_on       = [google_service_networking_connection.private_vpc_connection]
  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = "false"
      private_network = google_compute_network.vpc_network.id
    }
  }

  deletion_protection = "true"
}
```
This resource creates a Cloud SQL instance named sql-instance with PostgreSQL version 10, in the specified region, using the private VPC connection. IPv4 is disabled, and the instance is linked to the private network.

#### SQL User
```hcl
resource "google_sql_user" "users" {
  name     = "myuser"
  instance = google_sql_database_instance.sql_instance.name
  password = "password"
}
```
This resource creates a SQL user named myuser for the SQL instance with a specified password.

### Outputs
```hcl
output "vpc_network" {
  value = google_compute_network.vpc_network.name
}

output "public_subnet" {
  value = google_compute_subnetwork.public_subnet.name
}

output "private_subnet" {
  value = google_compute_subnetwork.private_subnet.name
}

output "my_firewall" {
  value = google_compute_firewall.my_firewall.name
}

output "sql_instance" {
  value = google_sql_database_instance.sql_instance.name
}

output "cloudrun" {
  value = google_cloud_run_service.cloudrun.name
}

output "lambda_cloudrun" {
  value = google_cloud_run_service.lambda_cloudrun
}
```
These outputs provide the names of the created resources for easy reference.

## Applying the Configuration
To apply this Terraform configuration, follow these steps:

1. Initialize Terraform:
   ```sh
   terraform init
	```
2. Review the plan:
   ```sh
   terraform plan
	```
3. Apply the configuration:
   ```sh
   terraform apply
	```
Confirm the apply step when prompted.

## Conclusion
This Terraform configuration sets up a Google Cloud infrastructure with a VPC network, subnets, firewall rules, NAT configuration, Cloud SQL instance, Cloud Run services, and IAM policies. Modify the variables and resources as needed to fit your specific requirements.




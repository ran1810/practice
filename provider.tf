terraform {
 required_providers {
 google = {
 source = "hashicorp/google"
 version = "4.23.0"
 }
 }
}
provider "google" {
 # Configuration options
project = var.project_id
region = var.region
}

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


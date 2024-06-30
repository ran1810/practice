resource "google_sql_database" "sql_database" {
  name     = "sql-database"
  instance = google_sql_database_instance.sql_instance.name
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

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

resource "google_sql_user" "users" {
  name     = "myuser"
  instance = google_sql_database_instance.sql_instance.name
  password = "password"
}
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

data "google_iam_policy" "admin" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "policy" {
  location = google_cloud_run_service.cloudrun.location
  project = google_cloud_run_service.cloudrun.project
  service = google_cloud_run_service.cloudrun.name
  policy_data = data.google_iam_policy.admin.policy_data
}

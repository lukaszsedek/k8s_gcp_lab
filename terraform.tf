terraform {
  backend "gcs" {
    bucket = "##PROJECT_ID##-state"
    prefix = "terraform/state"
  }
}

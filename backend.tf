terraform {
  backend "gcs" {
    # Using the centralized Terraform state project
    bucket = "pm-tf-states"
    prefix = "ev-tracker/terraform"
  }
}
terraform {
  backend "gcs" {
    # Using a dedicated bucket for ev-cost-tracker in the pm-tf-states project
    bucket = "ev-cost-tracker-tfstate"
    prefix = "terraform"
  }
}
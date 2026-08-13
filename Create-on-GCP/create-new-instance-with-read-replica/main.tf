resource "google_sql_database_instance" "uat-read_replica" {
  name                 = "app-uat-readreplica"
  master_instance_name = google_sql_database_instance.app-uat.name
  region               = "asia-south2"
  database_version     = "SQLSERVER_2022_ENTERPRISE"
  replica_configuration {
    failover_target = false
  }

  settings {
    tier              = "db-custom-2-7680"
    availability_type = "ZONAL"
    disk_size         = "10"
  }
  # set `deletion_protection` to true, will ensure that one cannot accidentally delete this instance by
  # use of Terraform whereas `deletion_protection_enabled` flag protects this instance at the GCP level.
  deletion_protection = false
}
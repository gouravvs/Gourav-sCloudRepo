resource "google_sql_database_instance" "app-dev" {

  name             = "app-dev"
  region           = "asia-south2"
  database_version = "SQLSERVER_2019_EXPRESS"
  root_password = "123!"

  deletion_protection = false

  settings {

    tier              = "db-custom-1-3840"
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"

    disk_type         = "PD_SSD"
    disk_size         = 10
    disk_autoresize   = true

    pricing_plan = "PER_USE"

    collation = "SQL_Latin1_General_CP1_CI_AS"

    time_zone = "UTC"

    connector_enforcement = "NOT_REQUIRED"

    deletion_protection_enabled = false

    enable_dataplex_integration  = true
    enable_google_ml_integration = false

    retain_backups_on_delete = false

    backup_configuration {

      enabled                        = true
      start_time                     = "00:00"
      location                       = "asia"
      point_in_time_recovery_enabled = false
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {

      ipv4_enabled = true

      ssl_mode = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"

      server_ca_mode = "GOOGLE_MANAGED_INTERNAL_CA"

      authorized_networks {
        name  = "dxc"
        value = "223.235.102.0/24"
      }
    }

    location_preference {
      zone = "asia-south2-b"
    }

    maintenance_window {
      day          = 7
      hour         = 0
      update_track = "canary"
    }

    insights_config {
      query_plans_per_minute = 5
      query_string_length    = 1
    }

    sql_server_audit_config {
      retention_interval = "0s"
      upload_interval    = "0s"
    }
  }
}
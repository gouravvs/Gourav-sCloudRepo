# Cloud SQL Upgrade - Required Permissions and FAQ
Author: Gourav

# Custom IAM Role

Role Name -- UpgradeCloudSQL

---

# Permissions Assigned to Custom Role

The following permissions were assigned to the custom IAM role used for Cloud SQL upgrade, backup/restore, Terraform operations, and Database Migration Service (DMS) activities.

## Cloud SQL Permissions

cloudsql.backupRuns.create
cloudsql.backupRuns.delete
cloudsql.backupRuns.export
cloudsql.backupRuns.get
cloudsql.backupRuns.list
cloudsql.instances.create
cloudsql.instances.get
cloudsql.instances.restoreBackup
cloudsql.instances.update

---

## Database Migration Service (DMS) Permissions

datamigration.connectionprofiles.create
datamigration.connectionprofiles.update
datamigration.migrationjobs.create
datamigration.migrationjobs.start
datamigration.migrationjobs.update

---

## Service Usage Permissions

serviceusage.services.enable
---

## Cloud Storage Permissions

storage.buckets.create
storage.buckets.getIamPolicy
storage.buckets.setIamPolicy
storage.objects.create
storage.objects.delete
---

# Common GCloud Commands FAQ

## Login to GCloud

```bash
gcloud auth login
```

Used to authenticate the current user account with Google Cloud.

---

## Verify Active Account

```bash
gcloud auth list
```

Displays authenticated accounts and the active account.

---

## Set Active Project

```bash
gcloud config set project PROJECT_ID
```

Example:

```bash
gcloud config set project my-gcp-project
```

---

## Verify Active Project

```bash
gcloud config get-value project
```

---

## Authenticate Application Default Credentials (ADC)

```bash
gcloud auth application-default login
```

Used by Terraform, SDKs, and APIs requiring Application Default Credentials.

---

## Remove / Unset Application Default Credentials

### Windows

```powershell
Remove-Item "$env:APPDATA\gcloud\application_default_credentials.json"
```

### Linux / macOS

```bash
rm ~/.config/gcloud/application_default_credentials.json
```

---

## Revoke GCloud Authentication

```bash
gcloud auth revoke
```

Removes authenticated user credentials.

---

## Initialize GCloud Configuration

```bash
gcloud init
```

Used to configure:

* Account
* Project
* Region/Zone defaults

---

# Terraform Commands

## Initialize Terraform

```bash
terraform init
```

---

## Validate Terraform Configuration

```bash
terraform validate
```

---

## Review Planned Changes

```bash
terraform plan
```

---

## Apply Terraform Changes

```bash
terraform apply
```

---

## Destroy Terraform Resources

```bash
terraform destroy
```

---

# Cloud SQL Backup Commands

## Create On-Demand Backup

```bash
gcloud sql backups create --instance=INSTANCE_NAME
```

---

## List Backups

```bash
gcloud sql backups list --instance=INSTANCE_NAME
```

---

## Describe Backup

```bash
gcloud sql backups describe BACKUP_ID --instance=INSTANCE_NAME
```

---

## Restore Backup to Another Instance

```bash
gcloud sql backups restore BACKUP_ID \
    --restore-instance=TARGET_INSTANCE \
    --backup-instance=SOURCE_INSTANCE
```

---

# Cloud SQL Operations Monitoring

## List Operations

```bash
gcloud sql operations list --instance=INSTANCE_NAME
```

---

## Describe Instance

```bash
gcloud sql instances describe INSTANCE_NAME
```

---

# SQL Server Validation Commands

## Verify SQL Server Version

```sql
SELECT @@VERSION;
```

---

## Verify Database Compatibility Level

```sql
SELECT name, compatibility_level
FROM sys.databases;
```

---

# Important Notes

* Always take backups before upgrade activities.
* Validate Terraform plan before apply.
* Ensure upgrades show `update-in-place`.
* Avoid modifying unrelated Terraform parameters during upgrade activities.
* Perform application validation after upgrade completion.

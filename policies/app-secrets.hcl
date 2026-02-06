# Application secrets policy
# Allows full access to application secrets

# KV v2 secrets engine - application path
path "secret/data/app/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/app/*" {
  capabilities = ["read", "list", "delete"]
}

#Database credentials for application
path "database/creds/app-role" {
  capabilities = ["read"]
}

# PKI certificate for application
path "pki/issue/app-role" {
  capabilities = ["create", "update"]
}

# Read application configuration
path "secret/data/config/app" {
  capabilities = ["read"]
}
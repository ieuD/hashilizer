ui = true
disable_mlock = true

storage "raft" {
  path    = "/vault/data"
  node_id = "vault-3"
}

listener "tcp" {
  address         = "0.0.0.0:8300"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = 1
}

api_addr     = "http://vault-3:8300"
cluster_addr = "http://vault-3:8201"

retry_join {
  leader_api_addr = "http://vault-1:8300"
}

log_level  = "Info"
log_format = "standard"

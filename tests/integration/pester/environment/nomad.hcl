client {
    enabled = false
}

consul {
    address = "127.0.0.1:8500"
    auto_advertise = true
    client_auto_join = true
    server_auto_join = true
    server_service_name = "jobs"
}

data_dir = "/test/nomad/data"

disable_update_check = true

enable_syslog = false

leave_on_interrupt = true
leave_on_terminate = true

log_level = "INFO"

server {
    enabled = true
    bootstrap_expect = 1
}

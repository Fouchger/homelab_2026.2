# DNS module

Provisions **two** DNS containers: `dns01` and `dns02`.

## Notes

- Installation and configuration of DNS software (BIND9, AdGuard Home, CoreDNS, Technitium) is handled by Ansible.
- Containers are created as **privileged** with Docker-capable features enabled.

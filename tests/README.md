# Smoke tests

Run static safety and completeness checks without installing packages:

```bash
./tests/smoke.sh
```

After installation, perform an HTTP and database smoke check:

```bash
curl -fsS http://127.0.0.1:8080/ | grep -F 'Northstar Outfitters'
curl -fsS 'http://127.0.0.1:8080/?route=diagnostics' | grep -F 'System status'
sudo mysql vulnforge -Nse 'SELECT COUNT(*) FROM flags' | grep -x 20
```

Use the configured private IP instead of loopback when the vhost was deliberately installed for an isolated second VM.

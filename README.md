# OpenVPN Bulk Tester

A Linux bash script to automatically test multiple `.ovpn` config files and find which servers are working.

### [English Guide](https://github.com/siniorone/ovpn-bulk-tester/blob/main/README.md)|[راهنمای فارسی](https://github.com/siniorone/ovpn-bulk-tester/blob/main/README.fa.md)
<img width="515" height="349" alt="Screenshot From 2026-05-31 22-37-37" src="https://github.com/user-attachments/assets/a2b52bb1-9081-488d-9b3d-4c1ccd1b3c95" />

## Features

- Bulk test hundreds of `.ovpn` configs automatically
- Live log output per connection attempt
- Detailed failure reason detection (TLS error, Auth failed, DNS, Timeout, etc.)
- Speed test after each successful connection
- External IP check through the tunnel
- Saves working configs with full details
- Two log levels: summary log + full debug log
- Dependency install/uninstall via interactive menu
- Clean progress bar and colored UI

## Requirements

- Linux (tested on Ubuntu/Debian)
- `sudo` access (required by OpenVPN)
- `openvpn`, `curl`, `ip` — installed via the built-in menu if missing

## Installation

```bash
git clone https://github.com/siniorone/ovpn-bulk-tester
cd ovpn-bulk-tester
chmod +x ovpn_tester.sh
```

## Usage

1. Put your `.ovpn` files in a folder named `configs/`
2. Run the script:

```bash
./ovpn_tester.sh
```

Or specify a custom config directory:

```bash
./ovpn_tester.sh /path/to/configs
```

Credentials can also be passed via environment variables:

```bash
OVPN_USER="youruser" OVPN_PASS="yourpass" ./ovpn_tester.sh
```

## Menu Options

| Option | Description |
|--------|-------------|
| 1 | Run bulk tester |
| 2 | Check & install dependencies |
| 3 | Remove openvpn |
| 4 | View working configs |
| 5 | View logs |
| q | Quit |

## Output Files

| File | Description |
|------|-------------|
| `working.txt` | All successful configs with IP and speed info |
| `test.log` | Summary log of all tests |
| `detail.log` | Full debug log including raw OpenVPN output |
| `results/working_names.txt` | Plain list of working config filenames |

## Failure Reasons

The script detects and reports these failure causes:

- `Timeout` — Server did not respond within the timeout window
- `Authentication Failed` — Wrong credentials
- `TLS Handshake Error` — Certificate/TLS issue
- `Connection Refused` — Server actively refused the connection
- `DNS Resolution Failed` — Hostname could not be resolved
- `Network Unreachable` — No route to the server
- `Certificate Verification Failed` — CA mismatch
- `Config Options Error` — Invalid option in the `.ovpn` file

## Configuration

Edit the variables at the top of `ovpn_tester.sh`:

```bash
CONNECT_TIMEOUT=20     # seconds to wait per config
SPEED_TEST_MB=5        # MB to download for speed test
SPEED_TEST=true        # set to false to skip speed test
```

## License

MIT

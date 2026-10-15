<p align="center">
  <img src="assets/logo.svg" alt="podman-healthcheckd" width="480">
</p>
<p align="center">
  A lightweight Rust daemon that schedules Podman healthchecks without relying on systemd timers. Works on any Linux distribution.
</p>

## Why

Podman normally depends on systemd timers to run container healthchecks. On systems without systemd (Guix, Alpine, Void, etc.), healthchecks simply never execute. This daemon replaces that functionality with a standalone process.

## How it works

1. On startup, enumerates running containers and inspects each for a healthcheck config
2. Spawns an async timer per container that has a healthcheck defined
3. Watches `podman events` for container start/stop/remove events and adjusts timers accordingly
4. On SIGINT/SIGTERM, cancels all timers and exits cleanly

The daemon only acts as a clock — `podman healthcheck run` handles retries, failing streaks, and on-failure actions internally.

## Install

| Method | Command |
|--------|---------|
| Cargo | `cargo install podman-healthcheckd` |
| Debian/Ubuntu | Download [`.deb`](https://github.com/franzos/podman-healthcheckd/releases) — `sudo dpkg -i podman-healthcheckd_*_amd64.deb` |
| Fedora/RHEL | Download [`.rpm`](https://github.com/franzos/podman-healthcheckd/releases) — `sudo rpm -i podman-healthcheckd-*.x86_64.rpm` |
| Alpine | Download [`.apk`](https://github.com/franzos/podman-healthcheckd/releases) — `sudo apk add --allow-untrusted podman-healthcheckd-*.apk` |
| Guix | `guix install -L <panther> podman-healthcheckd` ([Panther channel](https://github.com/franzos/panther)) |

Pre-built binaries for Linux (x86_64) on [GitHub Releases](https://github.com/franzos/podman-healthcheckd/releases).

Alpine packages are signed with a release key. To verify the signature instead of using `--allow-untrusted`, copy the release's `podman-healthcheckd.rsa.pub` into `/etc/apk/keys` before installing.

### Guix service

A Guix service definition is available in the [Panther channel](https://github.com/franzos/panther) for running podman-healthcheckd as a managed system service.

## Build

```bash
cargo build --release
```

On Guix:

```bash
guix shell rust rust:cargo gcc-toolchain -- sh -c "CC=gcc cargo build --release"
```

## Usage

```bash
RUST_LOG=info ./target/release/podman-healthcheckd
```

Log levels: `error`, `warn`, `info`, `debug`, `trace` (via `RUST_LOG`).

## Running as a service

The packages ship service definitions for the common non-systemd inits, but
they never enable or start anything — that is your choice. The definitions live
in `/usr/share/podman-healthcheckd/services/` and the matching one is symlinked
into place at install time based on the detected init.

OpenRC:

```sh
rc-update add podman-healthcheckd default   # enable at boot
rc-service podman-healthcheckd start
```

runit (enabling also starts it):

```sh
ln -s /etc/sv/podman-healthcheckd /var/service/
sv status podman-healthcheckd
```

dinit:

```sh
dinitctl enable podman-healthcheckd
dinitctl start podman-healthcheckd
```

SysVinit (Devuan, antiX, MX, ...):

```sh
update-rc.d podman-healthcheckd defaults    # enable at boot
service podman-healthcheckd start
```

s6 definitions are provided under `services/s6/` but not wired up automatically,
because the s6 service directory differs between distributions.

On a systemd system no service is installed — run the daemon directly:

```sh
RUST_LOG=info podman-healthcheckd
```

## License

MIT

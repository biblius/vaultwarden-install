# Vaultwarden Install

This document provides scripts that can be utilised to easily set up a [Vaultwarden](https://github.com/dani-garcia/vaultwarden) instance with sqlite directly on a linux machine (without docker).

Additionally, it provides a guide that can be followed step by step for building and deploying a Vaultwarden instance. The guide assumes you already have an instance of a Pi you can connect to and assumes you are using linux.
Parts of it are taken from [this guide](https://gist.github.com/avoidik/9f12ef4feae6ccf7a5801a520931c5d1) for which I am forever grateful.

We will primarily focus on the `aarch64` architecture, but the same principles apply for any.

Tested on Orange Pi Zero2.

## Compiling the binary

We'll be compiling the binary on our main machine, for which we will need [rust. 🦀](https://www.rust-lang.org/tools/install)

Since we are focusing on `aarch64`, we have to add it to `rustup`'s target list as well as make sure we have the necessary compilation plumbing for it.

The first command adds the target, the second one installs dependencies needed to cross compile

```bash
rustup target add aarch64-unknown-linux-gnu
sudo apt install gcc-aarch64-linux-gnu
```

After this, there should be a new directory at `/usr/lib/aarch64-linux-gnu`. This directory contains the necessary libraries
for the target architecture and we have to tell cargo to use it. We do this by pasting the following in `~/.cargo/config.toml`:

```toml
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"
rustflags = [
    "-L/usr/lib/aarch64-linux-gnu",
    "-Ctarget-feature=+crt-static",
]
```

This makes sure the compiler will use the new directory as the [sysroot](https://autotools.info/pkgconfig/cross-compiling.html) during compilation - it is the equivalent of setting `PKG_CONFIG_SYSROOT_DIR=/usr/lib/aarch64-linux-gnu` when running `cargo build`.
Additionally, we are linking everything statically, which ensures the binary does not need any dependencies when it's run on the target system.

We have the plumbing set up, time to clone

```bash
git clone git@github.com:dani-garcia/vaultwarden.git
cd vaultwarden
```

Now we have to cross our fingers and run

```bash
cargo build -F sqlite -F vendored_openssl --target=aarch64-unknown-linux-gnu --release 
```

This builds the binary with sqlite as the database backend (adjust it accordingly) and more importantly uses the vendored feature of OpenSSL which
makes sure it is statically compiled.

If all we see is green messages and then a "finished", it means we have successfully built vaultwarden! It's smooth sailing from here.

## Infrastructure

Time to switch to the pie.

We assume we are root.

Create necessary directories
  
```bash
mkdir -p /opt/vaultwarden/bin /opt/vaultwarden/data
```

From the main machine, copy the binary to the pie (assuming we are in the directory where we built vaultwarden)

```bash
scp target/aarch64-unknown-linux-gnu/release/vaultwarden root@<PIE_IP>:/opt/vaultwarden/bin/vaultwarden
```

Back to the pie, download and unpack web vault (check latest available version [here](https://github.com/dani-garcia/bw_web_builds/releases))

```bash
curl -fsSLO https://github.com/dani-garcia/bw_web_builds/releases/download/v2023.12.0/bw_web_v2023.12.0.tar.gz 
tar -zxf bw_web_v2023.12.0.tar.gz -C /opt/vaultwarden/
rm -f bw_web_v2023.12.0.tar.gz
```

Create `/opt/vaultwarden/.env` (see more options [here](https://github.com/dani-garcia/vaultwarden/blob/main/.env.template) or in the admin panel)

TODO add admin token
```.env
DATA_FOLDER=/opt/vaultwarden/data/
DATABASE_MAX_CONNS=10
WEB_VAULT_FOLDER=/opt/vaultwarden/web-vault/
WEB_VAULT_ENABLED=true
ROCKET_ADDRESS=0.0.0.0
ROCKET_PORT=6060
WEBSOCKET_ENABLED=true
WEBSOCKET_ADDRESS=<PIE_IP>
WEBSOCKET_PORT=3012
DOMAIN=https://<PIE_IP>:6060
```

Add the user and group

```bash
addgroup --system vaultwarden
adduser --system --home /opt/vaultwarden --shell /usr/sbin/nologin --no-create-home --gecos 'vaultwarden' --ingroup vaultwarden --disabled-login --disabled-password vaultwarden
```

Assign the necessay permissions

```bash
chown -R vaultwarden:vaultwarden /opt/vaultwarden/
chmod +x /opt/vaultwarden/bin/vaultwarden
```

Create a systemd service in `/etc/systemd/system/vaultwarden.service`

```service
[Unit]
Description=Vaultwarden Server
Documentation=https://github.com/dani-garcia/vaultwarden
After=network.target

[Service]
User=vaultwarden
Group=vaultwarden
EnvironmentFile=-/opt/vaultwarden/.env
ExecStart=/opt/vaultwarden/bin/vaultwarden
LimitNOFILE=65535
LimitNPROC=4096
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
DevicePolicy=closed
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
RestrictNamespaces=yes
RestrictRealtime=yes
MemoryDenyWriteExecute=yes
LockPersonality=yes
WorkingDirectory=/opt/vaultwarden
ReadWriteDirectories=/opt/vaultwarden/data
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
```

Enable systemd service

```bash
systemctl daemon-reload
systemctl enable vaultwarden.service
systemctl start vaultwarden.service
systemctl status vaultwarden.service
```

If it failed, check with

```bash
journalctl -xeu vaultwarden.service
```

If the rocket has launched we're good to go! Head on over to `<PIE_IP>:<VW_PORT>/admin`.

# Create secure Admin Token
TODO: make the script read this from a user
echo -n "MySecretPassword" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4r

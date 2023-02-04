# docker-smokeping

## Difference from linuxserver.io
- add new probes: TraceroutePingPlus, FPingPlus, FPingContinuousPlus
- add noto font and emoji support
- modify linuxserver.io default config

## New probes extra options:
### TraceroutePingPlus:
- host: now ip resolve by `host`, taceroute target is same as host, original `desthost` option not available.
- port: `80`, `443`, default `80` for tcp, `53` for udp (usually block by firewall, unreachable).
- mode: `icmp`, `tcp`, `udp`, `dccp`, default `icmp`.
- iptype: `4`, `6`, default `4`, if `host` is numberic, it will be overwrite.
- interface: `eth0`, default not set.

### FPingPlus:
- iptype: `4`, `6`, default `4`.
- interface: `eth0`, default not set.

### FPingContinuousPlus:
- iptype: `4`, `6`, default `4`.
- interface: `eth0`, default not set.
## Build
```
make dev
```

## Run
```
mkdir -p /docker/smokeping/config
mkdir -p /docker/smokeping/data

cat>/docker/smokeping/start.sh<<EOF
docker run -d --restart unless-stopped \\
  --name=smokeping \\
  --hostname=smokeping \\
  -e PUID=1000 \\
  -e PGID=1000 \\
  -e TZ=Asia/Shanghai \\
  -p 3300:80 \\
  -v /docker/smokeping/config:/config \\
  -v /docker/smokeping/data:/data \\
shiharuharu/smokeping:latest
EOF

chmod +x /docker/smokeping/start.sh
bash /docker/smokeping/start.sh
```
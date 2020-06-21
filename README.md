# How to reproduce the problem of losing logs on in_systemd

Environment

- OS: AmazonLinux 2 (vagrant) (originaly I noticed it in AWS EKS)
  - `Linux vagrant 4.14.181-140.257.amzn2.x86_64 #1 SMP Wed May 27 02:17:36 UTC 2020 x86_64 x86_64 x86_64 GNU/Linux`
- Docker: 19.03.6-ce


## How to use


### Configure journald

Edit `/etc/systemd/journald.conf` (disable rate limit).

```
sed -i -r \
  -e 's/^#?RateLimitInterval=.*/RateLimitInterval=0/' \
  -e 's/^#?RateLimitBurst=.*/RateLimitBurst=0/' \
  -e 's/^#?MaxLevelSyslog=.*/MaxLevelSyslog=warning/' \
  /etc/systemd/journald.conf
```

and restart journald.

```
sudo systemctl restart systemd-journald
```


### Set docker daemon log-driver to journald

Edit `/etc/docker/daemon.json`

```
"log-driver": "journald"
```

and restart docker daemon.

```
sudo systemctl restart docker.service
```


### Execute experiment

```
./run.sh
```


## Output

```
# ./run.sh 1.4.6
Using FluentBit 1.4.6
2020-06-21T18:44:00 Started fluent-bit container-id: 8fd52152ed19e2e8e4e1339c4c7f6990f676b2db1d839ec0155fd36238766a96
2020-06-21T18:44:03 Started loggen container-id: c8a520ff1ad86d3f373e2b34787e7da1ee4c6fdf9ffc560cf94dbf31fdc87c9e
2020-06-21T18:44:13 Stopping fluent-bit
fluent-bit

=== FluentBit Container log BEGIN ===
-- Logs begin at Sun 2020-06-21 01:13:16 JST, end at Sun 2020-06-21 18:44:19 JST. --
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: Fluent Bit v1.4.6
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: * Copyright (C) 2019-2020 The Fluent Bit Authors
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: * Copyright (C) 2015-2018 Treasure Data
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: * Fluent Bit is a CNCF sub-project under the umbrella of Fluentd
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: * https://fluentbit.io
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]:
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:00] [ info] [storage] version=1.0.3, initializing...
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:00] [ info] [storage] root path '/fluent-bit/log/buffers'
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:00] [ info] [storage] normal synchronization mode, checksum disabled, max_chunks_up=128
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:00] [ info] [storage] backlog input plugin: storage_backlog.1
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:00] [ info] [engine] started (pid=1)
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:00] [ info] [input:systemd:systemd.0] seek_cursor=s=fbcf373a45fe4f6682db37f893aa0eef;i=109... OK
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:00] [ info] [input:storage_backlog:storage_backlog.1] queue memory limit: 4.8M
Jun 21 18:44:00 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:00] [ info] [sp] stream processor started
Jun 21 18:44:13 vagrant 8fd52152ed19[3169]: [engine] caught signal (SIGTERM)
Jun 21 18:44:13 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:13] [ info] [input] pausing systemd.0
Jun 21 18:44:13 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:13] [ info] [input] pausing storage_backlog.1
Jun 21 18:44:13 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:13] [ warn] [engine] service will stop in 5 seconds
Jun 21 18:44:18 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:18] [ info] [engine] service stopped
Jun 21 18:44:18 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:18] [ info] [input] pausing systemd.0
=== FluentBit Container log END ===

2020-06-21T18:44:19 Get cursor from SQLite DB
2020-06-21T18:44:19 Saved Cursor: s=fbcf373a45fe4f6682db37f893aa0eef;i=10ce89;b=f85d22109c59482d93c6dcce890574f4;m=c55e9eb29;t=5a894f859f034;x=29dd7e7fb12b6e21
2020-06-21T18:44:19 Saved At: Sun Jun 21 18:44:18 JST 2020

ls -l log-1.4.6/buffers/systemd.0/
total 2576
-rw------- 1 root root 2048485 Jun 21 18:44 1-1592732654.835203388.flb
-rw------- 1 root root  583905 Jun 21 18:44 1-1592732657.944823700.flb

2020-06-21T18:44:19 Restarting fluent-bit container
2020-06-21T18:44:29 Stopping loggen1 container
loggen1
2020-06-21T18:44:31 Stopping fluent-bit container
fluent-bit

2020-06-21T18:44:37 Checking difference between journald and fluentbit out
8885d8884
< 2020-06-21T09:44:13.892840 8884

< : only in journalctl output
> : only in FluentBit out_file

LOST RECORDS FOUND

{
  "__CURSOR": "s=fbcf373a45fe4f6682db37f893aa0eef;i=10bd7a;b=f85d22109c59482d93c6dcce890574f4;m=c559eb10e;t=5a894f80eb619;x=b66ceefe619d5f37",
  "__REALTIME_TIMESTAMP": "1592732653893145",
  "__MONOTONIC_TIMESTAMP": "52976070926",
  "_BOOT_ID": "f85d22109c59482d93c6dcce890574f4",
  "PRIORITY": "6",
  "CONTAINER_NAME": "loggen1",
  "IMAGE_NAME": "loggen:1.0.0",
  "_TRANSPORT": "journal",
  "_PID": "3169",
  "_UID": "0",
  "_GID": "0",
  "_COMM": "dockerd",
  "_EXE": "/usr/bin/dockerd",
  "_CMDLINE": "/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock --default-ulimit nofile=1024:4096",
  "_CAP_EFFECTIVE": "3fffffffff",
  "_SYSTEMD_CGROUP": "/system.slice/docker.service",
  "_SYSTEMD_UNIT": "docker.service",
  "_SYSTEMD_SLICE": "system.slice",
  "_MACHINE_ID": "ba0c60e2c1a44ac28199cf7d69d8e431",
  "_HOSTNAME": "vagrant",
  "CONTAINER_ID_FULL": "c8a520ff1ad86d3f373e2b34787e7da1ee4c6fdf9ffc560cf94dbf31fdc87c9e",
  "CONTAINER_TAG": "c8a520ff1ad8",
  "SYSLOG_IDENTIFIER": "c8a520ff1ad8",
  "CONTAINER_ID": "c8a520ff1ad8",
  "MESSAGE": "2020-06-21T09:44:13.892840 8884",
  "_SOURCE_REALTIME_TIMESTAMP": "1592732653892978"
}


records in log-1.4.6/buffers.saved/systemd.0/1-1592732654.835203388.flb
 2020-06-21T09:44:15.195106 10000
  ...
 2020-06-21T09:44:17.942668 12458

records in log-1.4.6/buffers.saved/systemd.0/1-1592732657.944823700.flb
 2020-06-21T09:44:17.943726 12459
  ...
 2020-06-21T09:44:18.822730 13247

  22387 journald.out
  22386 fluentbit.out
  44773 total
```

- SIGTERM received at `18:44:13`. (_SOURCE_REALTIME_TIMESTAMP=2020-06-21T18:44:13.901429)

```
_SOURCE_REALTIME_TIMESTAMP=2020-06-21T18:44:13.901429 Jun 21 18:44:13 vagrant 8fd52152ed19[3169]: [engine] caught signal (SIGTERM)
_SOURCE_REALTIME_TIMESTAMP=2020-06-21T18:44:13.901435 Jun 21 18:44:13 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:13] [ info] [input] pausing systemd.0
_SOURCE_REALTIME_TIMESTAMP=2020-06-21T18:44:13.901441 Jun 21 18:44:13 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:13] [ info] [input] pausing storage_backlog.1
_SOURCE_REALTIME_TIMESTAMP=2020-06-21T18:44:13.925372 Jun 21 18:44:13 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:13] [ warn] [engine] service will stop in 5 seconds
_SOURCE_REALTIME_TIMESTAMP=2020-06-21T18:44:18.827553 Jun 21 18:44:18 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:18] [ info] [engine] service stopped
_SOURCE_REALTIME_TIMESTAMP=2020-06-21T18:44:18.827558 Jun 21 18:44:18 vagrant 8fd52152ed19[3169]: [2020/06/21 09:44:18] [ info] [input] pausing systemd.0
```

- Lost record generated at `2020-06-21T09:44:13.892840`
- Buffer file contains logs generated in following time range.
  - 2020-06-21T09:44:15.195106 .. 2020-06-21T09:44:18.822730

I think lost logs at receiving SIGTERM.

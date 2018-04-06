#!/bin/bash
set -exo pipefail

# Ensure defaults
export PORT=${PORT:-8090}

cd /gammarf

cat <<EOF > gammarf.conf
[modules]
modules = scanner, adsb, freqwatch, remotetask, p25rx, snapshot, ism433, single

[connector]
station_id = ${GAMMARF_STATION_ID}
station_pass = ${GAMMARF_STATION_PASS}
server_host = gammarf.io
data_port = 9090
cmd_port = 9091
server_web_proto = http
server_web_port = 8080

[startup]
#startup_1010 = tdoa
#startup_ADSB0001 = adsb
#startup_9000 = p25rx 50000
#startup_virtual = scanner, freqwatch

[location]
usegps = 1
lat = 28.0
lng = -82.4

[scanner]
# squelch (above avg.) for interesting freqs, must be float
hit_db = 15.0

[rtldevs]
rtl_path = /usr/local/bin
rtl_2freq_path = /gammarf/3rdparty/librtlsdr-2freq/build/src

gain_1000 = 23
ppm_1000 = 0
offset_1000 = 0
range_1000 = 30 1600

#gain_1001 = 23
ppm_1001 = 0
offset_1001 = 0
range_1001 = 30 1600

gain_1007 = 23
ppm_1007 = 0
offset_1007 = 0
range_1007 = 30 1600

gain_1008 = 23
ppm_1008 = 0
offset_1008 = 0
range_1008 = 30 1600

[hackrfdevs]
hackrf_path = /usr/local/bin
lna_gain = 32
vga_gain = 40
EOF

# Fail fast, including pipelines
set -exo pipefail

cat > /etc/supervisor/conf.d/supervisord.conf <<EOF
[unix_http_server]
file=/var/run/supervisor.sock   ; (the path to the socket file)
chmod=0700                  ; sockef file mode (default 0700)

[supervisord]
logfile=/var/log/supervisor/supervisord.log ; (main log file;default $CWD/supervisord.log)
pidfile=/var/run/supervisord.pid ; (supervisord pidfile;default supervisord.pid)
childlogdir=/var/log/supervisor            ; ('AUTO' child log dir, default $TEMP)
nodaemon = true
autostart = true
autorestart = true
user = root

; the below section must remain in the config file for RPC
; (supervisorctl/web interface) to work, additional interfaces may be
; added by defining them in separate rpcinterface: sections
[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock ; use a unix:// URL  for a unix socket

[include]
files = /etc/supervisor/conf.d/*.conf
EOF

env | grep -v 'HOME\|PWD\|PATH' | while read line; do
   key="$(echo $line | cut -d= -f1)"
   value="$(echo $line | cut -d= -f2-)"
   echo "export $key=\"$value\"" >> /.bashrc
done

cat <<EOF > /tmp/gammarf.sh
#!/bin/bash
cd /gammarf
source /.bashrc
exec screen -D -m -S gammarf ./gammarf.py
EOF

chmod 755 /tmp/gammarf.sh

cat <<EOF > /tmp/gotty.sh
#!/bin/bash
cd /gammarf
source /.bashrc
exec gotty -w --port ${PORT:-8090} screen -r -d gammarf
EOF

chmod 755 /tmp/gotty.sh

cat > /etc/supervisor/conf.d/gammarf.conf <<EOF
[program:gammarf]
command=/tmp/gammarf.sh
priority=10
directory=/gammarf
process_name=%(program_name)s
autostart=true
autorestart=true
stopsignal=TERM
stopwaitsecs=1
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

cat > /etc/supervisor/conf.d/gotty.conf <<EOF
[program:gotty]
command=/tmp/gotty.sh
priority=10
directory=/gammarf
process_name=%(program_name)s
autostart=true
autorestart=true
stdout_events_enabled=true
stderr_events_enabled=true
stopsignal=TERM
stopwaitsecs=1
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

chown daemon:daemon /etc/supervisor/conf.d/ /var/run/ /var/log/supervisor/

# reset any hackrf attached
./reset_hackrf.sh

# start supervisord
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf

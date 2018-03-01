#!/bin/bash
set -exo pipefail

cd /gammarf

cat <<EOF > gammarf.conf
[modules]
modules = scanner, adsb, freqwatch, remotetask, p25rx, snapshot, tpms

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

./reset_hackrf.sh
exec gotty -w --port ${PORT:-8090} tmux new -A -s gotty ./gammarf.py

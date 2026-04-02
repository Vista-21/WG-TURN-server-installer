#!/bin/bash
set -e

WG_CONF="/etc/wireguard/wg0.conf"

echo "Peers from $WG_CONF"
echo

awk '
  /^

\[Peer\]

/ {peer=1; name=""; pub=""; ip=""}
  /^# / && peer {name=substr($0,3)}
  /PublicKey =/ && peer {pub=$3}
  /AllowedIPs =/ && peer {ip=$3}
  NF==0 && peer {
    printf "Name: %-20s  IP: %-18s  PubKey: %s\n", name, ip, pub
    peer=0
  }
' "$WG_CONF"

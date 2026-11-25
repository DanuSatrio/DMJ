#!/usr/bin/env bash
# gen-configs.sh : membuat configs/leaf1.cfg, leaf2.cfg, spine1.cfg
# Lokasi: ~/repro/topology/gen-configs.sh
#
# Sintaks "set /" mengacu pada tutorial Tahap 3 dan lab referensi Nokia
# (srl-labs/srl-telemetry-lab, era SR Linux 23.3.1). Belum diuji di router
# kelompok: hasilnya harus divalidasi lewat langkah 5.3 tutorial.
#
# Desain overlay: iBGP EVPN antar-loopback dengan spine1 sebagai route reflector
# (menghindari masalah next-hop eBGP lewat spine, tutorial bagian 0 catatan 2).
#
# SNMP, sFlow, dan perbaikan lain: taruh barisnya di extra-all.cfg
# (satu file, sama untuk leaf1, leaf2, spine1), lalu jalankan ulang skrip ini.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p configs

# ---- parameter (asumsi kelompok, catat di ASUMSI.md) ----
SPINE_AS=65000
SPINE_LO=10.0.0.100
OVERLAY_AS=65100   # AS iBGP overlay (dipakai lewat local-as)
IP_MTU=9100        # ip-mtu subinterface underlay; harus >= 9050 agar frame 9000 B + VXLAN lewat
EVI=111
VNI=1000
RT="target:100:111"

# ---- Bagian B: routing policy (dipakai leaf dan spine) ----
emit_policy() {
cat <<EOF
set / routing-policy prefix-set loopbacks prefix 10.0.0.0/24 mask-length-range 32..32
set / routing-policy policy export-lo statement 10 match prefix-set loopbacks
set / routing-policy policy export-lo statement 10 action policy-result accept
set / routing-policy policy accept-all default-action policy-result accept
EOF
}

# ---- Bagian C: interface leaf ----
# $1 = prefix link ke spine (mis. 192.168.11), $2 = loopback leaf (mis. 10.0.0.1)
emit_leaf_interfaces() {
local LINK=$1 LO=$2
cat <<EOF
set / interface ethernet-1/1 admin-state enable
set / interface ethernet-1/1 subinterface 0 admin-state enable
set / interface ethernet-1/1 subinterface 0 ip-mtu ${IP_MTU}
set / interface ethernet-1/1 subinterface 0 ipv4 admin-state enable
set / interface ethernet-1/1 subinterface 0 ipv4 address ${LINK}.1/30
set / interface ethernet-1/10 admin-state enable
set / interface ethernet-1/10 subinterface 0 admin-state enable
set / interface ethernet-1/10 subinterface 0 type bridged
set / interface system0 admin-state enable
set / interface system0 subinterface 0 admin-state enable
set / interface system0 subinterface 0 ipv4 admin-state enable
set / interface system0 subinterface 0 ipv4 address ${LO}/32
set / network-instance default interface ethernet-1/1.0
set / network-instance default interface system0.0
EOF
}

# ---- Bagian D: BGP leaf (underlay eBGP + overlay iBGP EVPN) ----
# $1 = AS leaf, $2 = loopback leaf, $3 = prefix link ke spine
emit_leaf_bgp() {
local ASN=$1 LO=$2 LINK=$3
cat <<EOF
set / network-instance default protocols bgp admin-state enable
set / network-instance default protocols bgp autonomous-system ${ASN}
set / network-instance default protocols bgp router-id ${LO}
set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
set / network-instance default protocols bgp group underlay peer-as ${SPINE_AS}
set / network-instance default protocols bgp group underlay export-policy export-lo
set / network-instance default protocols bgp group underlay import-policy accept-all
set / network-instance default protocols bgp group underlay afi-safi ipv4-unicast admin-state enable
set / network-instance default protocols bgp neighbor ${LINK}.2 admin-state enable
set / network-instance default protocols bgp neighbor ${LINK}.2 peer-group underlay
set / network-instance default protocols bgp group overlay peer-as ${OVERLAY_AS}
set / network-instance default protocols bgp group overlay local-as as-number ${OVERLAY_AS}
set / network-instance default protocols bgp group overlay export-policy accept-all
set / network-instance default protocols bgp group overlay import-policy accept-all
set / network-instance default protocols bgp group overlay afi-safi evpn admin-state enable
set / network-instance default protocols bgp group overlay afi-safi ipv4-unicast admin-state disable
set / network-instance default protocols bgp neighbor ${SPINE_LO} admin-state enable
set / network-instance default protocols bgp neighbor ${SPINE_LO} peer-group overlay
set / network-instance default protocols bgp neighbor ${SPINE_LO} transport local-address ${LO}
EOF
}

# ---- Bagian E: VXLAN dan MAC-VRF (sama untuk kedua leaf) ----
emit_leaf_vxlan_macvrf() {
cat <<EOF
set / tunnel-interface vxlan1 vxlan-interface 1 type bridged
set / tunnel-interface vxlan1 vxlan-interface 1 ingress vni ${VNI}
set / network-instance mac-vrf-1 type mac-vrf
set / network-instance mac-vrf-1 admin-state enable
set / network-instance mac-vrf-1 interface ethernet-1/10.0
set / network-instance mac-vrf-1 vxlan-interface vxlan1.1
set / network-instance mac-vrf-1 protocols bgp-evpn bgp-instance 1 admin-state enable
set / network-instance mac-vrf-1 protocols bgp-evpn bgp-instance 1 vxlan-interface vxlan1.1
set / network-instance mac-vrf-1 protocols bgp-evpn bgp-instance 1 evi ${EVI}
set / network-instance mac-vrf-1 protocols bgp-vpn bgp-instance 1 route-target export-rt ${RT}
set / network-instance mac-vrf-1 protocols bgp-vpn bgp-instance 1 route-target import-rt ${RT}
EOF
}

# ---- Bagian F: perakit file leaf ----
# $1 = nama (leaf1), $2 = AS, $3 = loopback, $4 = prefix link ke spine
gen_leaf() {
local NAME=$1 ASN=$2 LO=$3 LINK=$4
{
emit_leaf_interfaces "$LINK" "$LO"
emit_policy
emit_leaf_bgp "$ASN" "$LO" "$LINK"
emit_leaf_vxlan_macvrf
if [ -f extra-all.cfg ]; then cat extra-all.cfg; fi
} > "configs/${NAME}.cfg"
}

# ---- Bagian G: spine (tanpa MAC-VRF dan tanpa port client; route reflector EVPN) ----
gen_spine() {
{
cat <<EOF
set / interface ethernet-1/1 admin-state enable
set / interface ethernet-1/1 subinterface 0 admin-state enable
set / interface ethernet-1/1 subinterface 0 ip-mtu ${IP_MTU}
set / interface ethernet-1/1 subinterface 0 ipv4 admin-state enable
set / interface ethernet-1/1 subinterface 0 ipv4 address 192.168.11.2/30
set / interface ethernet-1/2 admin-state enable
set / interface ethernet-1/2 subinterface 0 admin-state enable
set / interface ethernet-1/2 subinterface 0 ip-mtu ${IP_MTU}
set / interface ethernet-1/2 subinterface 0 ipv4 admin-state enable
set / interface ethernet-1/2 subinterface 0 ipv4 address 192.168.12.2/30
set / interface system0 admin-state enable
set / interface system0 subinterface 0 admin-state enable
set / interface system0 subinterface 0 ipv4 admin-state enable
set / interface system0 subinterface 0 ipv4 address ${SPINE_LO}/32
set / network-instance default interface ethernet-1/1.0
set / network-instance default interface ethernet-1/2.0
set / network-instance default interface system0.0
EOF
emit_policy
cat <<EOF
set / network-instance default protocols bgp admin-state enable
set / network-instance default protocols bgp autonomous-system ${SPINE_AS}
set / network-instance default protocols bgp router-id ${SPINE_LO}
set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
set / network-instance default protocols bgp group underlay export-policy export-lo
set / network-instance default protocols bgp group underlay import-policy accept-all
set / network-instance default protocols bgp group underlay afi-safi ipv4-unicast admin-state enable
set / network-instance default protocols bgp neighbor 192.168.11.1 admin-state enable
set / network-instance default protocols bgp neighbor 192.168.11.1 peer-as 65001
set / network-instance default protocols bgp neighbor 192.168.11.1 peer-group underlay
set / network-instance default protocols bgp neighbor 192.168.12.1 admin-state enable
set / network-instance default protocols bgp neighbor 192.168.12.1 peer-as 65002
set / network-instance default protocols bgp neighbor 192.168.12.1 peer-group underlay
set / network-instance default protocols bgp group overlay peer-as ${OVERLAY_AS}
set / network-instance default protocols bgp group overlay local-as as-number ${OVERLAY_AS}
set / network-instance default protocols bgp group overlay export-policy accept-all
set / network-instance default protocols bgp group overlay import-policy accept-all
set / network-instance default protocols bgp group overlay afi-safi evpn admin-state enable
set / network-instance default protocols bgp group overlay afi-safi ipv4-unicast admin-state disable
set / network-instance default protocols bgp group overlay route-reflector client true
set / network-instance default protocols bgp group overlay route-reflector cluster-id ${SPINE_LO}
set / network-instance default protocols bgp neighbor 10.0.0.1 admin-state enable
set / network-instance default protocols bgp neighbor 10.0.0.1 peer-group overlay
set / network-instance default protocols bgp neighbor 10.0.0.1 transport local-address ${SPINE_LO}
set / network-instance default protocols bgp neighbor 10.0.0.2 admin-state enable
set / network-instance default protocols bgp neighbor 10.0.0.2 peer-group overlay
set / network-instance default protocols bgp neighbor 10.0.0.2 transport local-address ${SPINE_LO}
EOF
if [ -f extra-all.cfg ]; then cat extra-all.cfg; fi
} > configs/spine1.cfg
}

# ---- Bagian H: eksekusi ----
#        nama  AS     loopback  prefix link
gen_leaf leaf1 65001 10.0.0.1 192.168.11
gen_leaf leaf2 65002 10.0.0.2 192.168.12
gen_spine
echo "Selesai: $(ls configs | tr '\n' ' ')"

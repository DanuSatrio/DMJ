## Tabel desain Tahap 2

| Node | Peran | AS | Loopback system0 | IP manajemen |
|---|---|---|---|---|
| spine1 | spine, route server EVPN | 65000 | 10.0.0.100/32 | 172.80.80.11 |
| leaf1 | leaf, VTEP | 65001 | 10.0.0.1/32 | 172.80.80.12 |
| leaf2 | leaf, VTEP | 65002 | 10.0.0.2/32 | 172.80.80.13 |
| client1 | sumber trafik | - | 192.168.100.1/24 | otomatis |
| client2 | tujuan trafik | - | 192.168.100.2/24 | otomatis |

| Link | Subnet | Alamat |
|---|---|---|
| spine1:e1-1 ke leaf1:e1-1 | 192.168.11.0/30 | spine .2, leaf1 .1 |
| spine1:e1-2 ke leaf2:e1-1 | 192.168.12.0/30 | spine .2, leaf2 .1 |
| leaf1:e1-10 ke client1:eth1 | LAN 192.168.100.0/24 | client1 .1 |
| leaf2:e1-10 ke client2:eth1 | LAN 192.168.100.0/24 | client2 .2 |

Layanan L2: MAC-VRF mac-vrf-1, VNI 1000, EVI 111, route-target target:100:111.
Semua nilai di atas adalah keputusan kelompok (paper tidak menyebutnya).

## Environment (Tahap 1)

| Item | Nilai | Alasan | Sumber |
|---|---|---|---|
| Socket buffer host (net.core.rmem_max) | 33554432 (32 MB), permanen lewat /etc/sysctl.d/99-rmem.conf | paper II.D menyebut 32 MB tetapi tidak menyebut parameter sysctl-nya | keputusan kelompok (M7) |

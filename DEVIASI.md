| Item | Paper/M7 | Yang dipakai | Alasan |
|---|---|---|---|
| SR Linux image | 23.2.2 | 23.3.1 | tag 23.2.2 tidak tersedia di ghcr.io/nokia/srlinux (pull: not found) |
| gNMIc | 2.3.0 | 0.31.4 | kemungkinan salah ketik di paper |
| Docker | 20.10.21 | Docker Engine terbaru di dalam WSL Ubuntu | Docker Desktop tidak kompatibel dengan Containerlab di WSL (deploy gagal: Link not found); 20.10.21 tidak tersedia di Ubuntu ini |
| Docker min-api-version | default | 1.24 (daemon.json) | agar Containerlab 0.42.0 terhubung ke Docker baru |
| Spesifikasi host (Tahap 2, 3, 6) | VM VirtualBox 8 GB RAM, 4 core, Linux Mint 20.2 | WSL2 Ubuntu, batas memori 5 GB, swap 8 GB (laptop 8 GB) | RAM laptop terbatas; dipakai hanya untuk tahap membangun, Tahap 7 di mesin sesuai spesifikasi paper |

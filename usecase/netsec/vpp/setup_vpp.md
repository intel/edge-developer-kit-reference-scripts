# VPP (Vector Packet Processing)
The Fast Data Project (FD.io) is an open-source project aimed at providing the world's 
fastest and most secure networking data plane through Vector Packet Processing (VPP).

## Steps
### 1. Build VPP
Build VPP
```bash
sudo ./setup_vpp.sh
```
Installation is completed when you see this message:
> ✓ VPP Build Complete 

### 2. Identify NIC PCI Address and Mac Address for VPP/DPDK and TRex Port

```bash

+----------------+         +----------------+
|          Port 0|---------|Port 0          |
|   DUT          |         |         TRex   |
|          Port 1|---------|Port 1          |
+----------------+         +----------------+

lshw -c network -businfo

#Example Output:
Bus info          Device          Class          Description
============================================================
pci@0000:01:00.0  enp1s0f0        network        Ethernet Controller X710 for 10GbE SFP+
pci@0000:01:00.1  enp1s0f1        network        Ethernet Controller X710 for 10GbE SFP+
pci@0000:01:00.2  enp1s0f2        network        Ethernet Controller X710 for 10GbE SFP+
pci@0000:01:00.3  enp1s0f3        network        Ethernet Controller X710 for 10GbE SFP+
pci@0000:04:00.0  enp4s0          network        Intel Corporation
pci@0000:05:00.0  enp5s0          network        Intel Corporation
pci@0000:06:00.0  enp6s0          network        Intel Corporation
pci@0000:07:00.0  enp7s0          network        Intel Corporation
pci@0000:08:00.0  enp8s0          network        Intel Corporation
pci@0000:09:00.0  enp9s0          network        Intel Corporation
pci@0000:0a:00.0  enp10s0         network        Intel Corporation
pci@0000:0b:00.0  enp11s0         network        Intel Corporation
pci@0000:00:1f.6  eno1            network        Ethernet Connection (17) I219-LM
```


### 3.a (Test 1) VPP IPSec Test 
DUT
```bash
service vpp stop
#Please change PCI address
#For I226
    modprobe uio_pci_generic
    /root/dpdk/usertools/dpdk-devbind.py -b uio_pci_generic 01:00.0
    /root/dpdk/usertools/dpdk-devbind.py -b uio_pci_generic 02:00.0
#For X710
    modprobe vfio
    echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
    modprobe vfio-pci
    /root/dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.2
    /root/dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.3
    #Unbind unused port
    /root/dpdk/usertools/dpdk-devbind.py -u 01:00.0
    /root/dpdk/usertools/dpdk-devbind.py -u 01:00.1
mkdir /mnt/huge
echo 16 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
mount -t hugetlbfs -o pagesize=1G nodev /mnt/huge
echo 16000 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
mount -t hugetlbfs nodev /mnt/huge
#Change Line 15 and Line 25 to <TRex Port 0 Mac Addr> in /root/VPP-IPSec-UD_2p1c1t2f_s0_1loss_gcm128_native-mb-I0-ep0.cfg
#Change Line 42 and Line 52 to <TRex Port 1 Mac Addr> in /root/VPP-IPSec-UD_2p1c1t2f_s0_1loss_gcm128_native-mb-I0-ep0.cfg
#Optional: Set different crypto handler in Line 55 /root/VPP-IPSec-UD_2p1c1t2f_s0_1loss_gcm128_native-mb-I0-ep0.cfg  
# (Option A SW-QAT (default))    set crypto handler aes-128-gcm ipsecmb
# (Option B)                     set crypto handler aes-128-gcm openssl
vpp -c /root/VPP-IPSec-UD_2p1c1t2f_s0_1loss_gcm128_native-mb-I0-ep0.startup

```

TRex
```bash
#Terminal 1
service vpp stop
#Change PCI Address
#For X710
    modprobe vfio
    echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
    modprobe vfio-pci
    /root/dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.2
    /root/dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.3
    #Unbind unused port
    /root/dpdk/usertools/dpdk-devbind.py -u 01:00.0
    /root/dpdk/usertools/dpdk-devbind.py -u 01:00.1
cd /opt/trex-core/scripts
#Change trex_cfg.yaml PCI Address
./t-rex-64 -i --no-scapy-server --cfg /etc/trex_cfg.yaml  -c 2

#Terminal 2
cd /opt/trex-core/scripts
./trex-console
#Change the speed
start -p 0 -f /opt/trex-core/scripts/stl/IPSEC_1420B_1000f_port0.py  -m 100% --force
start -p 1 -f /opt/trex-core/scripts/stl/IPSEC_1420B_1000f_port1.py  -m 100% --force

start -p 0 -f /opt/trex-core/scripts/stl/IPSEC_64B_1000f_port0.py  -m 100% --force
start -p 1 -f /opt/trex-core/scripts/stl/IPSEC_64B_1000f_port1.py  -m 100% --force

tui
```

### 3.b (Test 2) DPDK L3FWD Test 
DUT
```bash
service vpp stop
#Change PCI Address
#For I226
    modprobe uio_pci_generic
    /root/dpdk/usertools/dpdk-devbind.py -b uio_pci_generic 01:00.0
    /root/dpdk/usertools/dpdk-devbind.py -b uio_pci_generic 02:00.0
#For X710
    modprobe vfio
    echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
    modprobe vfio-pci
    /root/dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.2
    /root/dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.3
    #Unbind unused port
    /root/dpdk/usertools/dpdk-devbind.py -u 01:00.0
    /root/dpdk/usertools/dpdk-devbind.py -u 01:00.1
mkdir /mnt/huge
echo 16 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
mount -t hugetlbfs -o pagesize=1G nodev /mnt/huge
echo 16000 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
mount -t hugetlbfs nodev /mnt/huge
cd /root/dpdk/build/examples
#Change MAC Address eth-dest=0,<TRex Port 0 Mac Addr>  eth-dest=1,<TRex Port 1 Mac Addr>
./dpdk-l3fwd -l 1,2 -- -p 0xf --config="(0,0,1),(1,0,1)" -P --eth-dest=0,aa:aa:aa:aa:aa:aa --eth-dest=1,bb:bb:bb:bb:bb:bb
```

TRex
```bash
#Terminal 1
service vpp stop
#Change PCI Address
#For X710
    modprobe vfio
    echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
    modprobe vfio-pci
    /root/dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.2
    /root/dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.3
    #Unbind unused port
    /root/dpdk/usertools/dpdk-devbind.py -u 01:00.0
    /root/dpdk/usertools/dpdk-devbind.py -u 01:00.1
cd /opt/trex-core/scripts
#Change trex_cfg.yaml PCI Address
./t-rex-64 -i --no-scapy-server --cfg /etc/trex_cfg.yaml  -c 2

#Terminal 2
cd /opt/trex-core/scripts
./trex-console

#Modify the speed
start -p 0 -f /opt/trex-core/scripts/stl/VPP_1420B_1000f_port0.py  -m 100% --force
start -p 1 -f /opt/trex-core/scripts/stl/VPP_1420B_1000f_port1.py  -m 100% --force
tui
```

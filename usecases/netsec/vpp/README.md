# VPP (Vector Packet Processing)
The latest Intel Atom and Core processors support Intel® Advanced Vector Extensions 2.0 (Intel® AVX2) instruction set that can accelerate cryptographic operations.
Intel® AVX2 uses 256-bit registers, doubling the data width of predecessor technologies, helping reduce the number of CPU cycles required to handle incoming traffic. This instruction set increases throughput of cryptographic workloads without the use of additional hardware accelerators. These latest platforms thus match the performance and security requirements of  businesses especially at the edge or branch locations including SD-WAN, uCPE, etc.

Intel® Multi-buffer Crypto for IPsec Library (Intel® IPsec_mb) simplifies the implementation of multi-buffer processing for authentication and encryption algorithms.
Multi-buffer processing enables the use of Intel AVX2 instructions to process multiple independent buffers at the same time, so that multiple encrypt and decrypt operations can be executed in one execution cycle thus improving overall throughput.

Vector Packet Processor (VPP) is a fast, scalable layer 2-4 multi-platform network stack. It runs in Linux Userspace. VPP is continually being enhanced through the extensive use of plugins. The Data Plane Development Kit (DPDK) is a great example of this. It provides some important features and drivers for VPP. Some VPP Use-cases include vSwitches, vRouters, Gateways, Firewalls and Load-Balancers, to name a few. DPDK is the open-source software for packet processing and provides set of data plane libraries and network interface PMD (Poll Mode Drivers) for offloading packet processing from OS to user space. AES-NI Multi Buffer Crypto Poll Mode Driver (DPDK aesni_mb PMD)is one such interface to utilize Intel ipsec-mb.The PMD constantly polls the network interface for new packets, so that the NIC does not need to raise a CPU interrupt each time it receives a new packet. This approach is more efficient in the context of large numbers of small packets associated with authentication and encryption of IPsec.

# Software Architecture
![Architecture](./images/intel-ipsec-mb.png)
*Figure 1: IPSec software stack*

# System Requirements
Processors:
- 12th or 13th generation or 14th generation Intel® Core™ processors
- Intel® Atom x7000RE Processors

Network Interface Card:
- Intel® I226
- Intel® I350
- Intel® X710

At least 8GB of system RAM
At least 32GB of available hard drive space
Internet Connection
Ubuntu Desktop 22.04

# Validated Hardware
[Enterprise Edge Networking Developer Kits](https://www.intel.com/content/www/us/en/developer/topic-technology/edge-5g/hardware/netsec-sd-wan-dev-kit.html)

Lanner NCA-4240 1U 19” Rackmount Appliance

Senao Networks SA9820 Series

Silicom Ibiza Commercial 1U Edge Gateway Router


## Steps
### 1. Install operating system
Install the latest [Ubuntu* 22.04 LTS Desktop](https://releases.ubuntu.com/jammy/). Refer to [Ubuntu Desktop installation tutorial](https://ubuntu.com/tutorials/install-ubuntu-desktop#1-overview) if needed.

### 2. Download scripts
This step will download all reference scripts from the repository.
```
git clone https://github.com/intel/edge-developer-kit-reference-scripts
```

### 3. Go to specific setup directory
This step will redirect user to the current setup directory
```
cd edge-developer-kit-reference-scripts/usecases/netsec/vpp
```

### 4. Run setup script
```bash
./setup_vpp.sh
```
Installation is completed when you see this message:
> ✓ VPP Build Complete

### 5. Identify NIC PCI Address and Mac Address for VPP/DPDK and TRex Port

Example setup and config
```bash

I226
+----------------------------------+         +---------------------------------------------------------------------+
|          Port 0 PCI Addr: 04:00.0|---------|       Port 0  PCI Addr: 04:00.0, Mac Addr: aa:aa:aa:aa:aa:aa        |
|   DUT                            |         |  TRex                                                               |
|          Port 1 PCI Addr: 05:00.0|---------|       Port 1  PCI Addr: 05:00.0, Mac Addr: bb:bb:bb:bb:bb:bb        |
+----------------------------------+         +---------------------------------------------------------------------+

X710
+----------------------------------+         +---------------------------------------------------------------------+
|          Port 0 PCI Addr: 01:00.2|---------|       Port 0  PCI Addr: 01:00.2, Mac Addr: aa:aa:aa:aa:aa:aa        |
|   DUT                            |         |  TRex                                                               |
|          Port 1 PCI Addr: 01:00.3|---------|       Port 1  PCI Addr: 01:00.3, Mac Addr: bb:bb:bb:bb:bb:bb        |
+----------------------------------+         +---------------------------------------------------------------------+

sudo lshw -c network -businfo

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

#Check connected NIC, disconnect and connect the LAN cable and check
dmesg |grep Link
[1186832.578400] igc 0000:04:00.0 enp4s0: NIC Link is Down
[1186835.774717] igc 0000:04:00.0 enp4s0: NIC Link is Up 2500 Mbps Full Duplex, Flow Control: RX
[451059.999854] i40e 0000:01:00.2 enp1s0f2: NIC Link is Down
[451060.579095] i40e 0000:01:00.2 enp1s0f2: NIC Link is Up, 10 Gbps Full Duplex, Flow Control: None

#Obtain Mac Addr
ip a

```


### 6.a (Test 1) VPP IPSec Test
DUT
```bash
#cd to <user> home dir
cd ~
sudo su
service vpp stop
#Change PCI address
#For I226
    modprobe uio_pci_generic
    ./dpdk/usertools/dpdk-devbind.py -b uio_pci_generic 04:00.0
    ./dpdk/usertools/dpdk-devbind.py -b uio_pci_generic 05:00.0
#For X710
    modprobe vfio
    echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
    modprobe vfio-pci
    ./dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.2
    ./dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.3
    #Unbind unused port
    ./dpdk/usertools/dpdk-devbind.py -u 01:00.0
    ./dpdk/usertools/dpdk-devbind.py -u 01:00.1
mkdir /mnt/huge
echo 4096 >/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
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
#cd to <user> home dir
cd ~
sudo su
service vpp stop
mkdir /mnt/huge
echo 4096 >/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
mount -t hugetlbfs nodev /mnt/huge
#Change PCI Address
#For I226, No action
#For X710
    modprobe vfio
    echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
    modprobe vfio-pci
    ./dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.2
    ./dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.3
    #Unbind unused port
    ./dpdk/usertools/dpdk-devbind.py -u 01:00.0
    ./dpdk/usertools/dpdk-devbind.py -u 01:00.1
cd ./trex-core/scripts
#Change trex_cfg.yaml PCI Address
./t-rex-64 -i --no-scapy-server --cfg /root/trex_cfg.yaml  -c 1

#Terminal 2
#cd to <user> home dir
cd ~
sudo su
cd ./trex-core/scripts
./trex-console
#Change the speed, 0.95gbps, 2.45gbps, 9.95gbps
start -p 0 -f ./stl/IPSEC_1420B_1000f_port0.py  -m 2.45gbps --force
start -p 1 -f ./stl/IPSEC_1420B_1000f_port1.py  -m 2.45gbps --force

start -p 0 -f ./stl/IPSEC_64B_1000f_port0.py  -m 2.45gbps --force
start -p 1 -f ./stl/IPSEC_64B_1000f_port1.py  -m 2.45gbps --force

tui
```

### 6.b (Test 2) DPDK L3FWD Test
DUT
```bash
#cd to <user> home dir
cd ~
sudo su
service vpp stop
#Change PCI Address
#For I226
    modprobe uio_pci_generic
    ./dpdk/usertools/dpdk-devbind.py -b uio_pci_generic 04:00.0
    ./dpdk/usertools/dpdk-devbind.py -b uio_pci_generic 05:00.0
#For X710
    modprobe vfio
    echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
    modprobe vfio-pci
    ./dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.2
    ./dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.3
    #Unbind unused port
    ./dpdk/usertools/dpdk-devbind.py -u 01:00.0
    ./dpdk/usertools/dpdk-devbind.py -u 01:00.1
mkdir /mnt/huge
echo 4096 >/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
mount -t hugetlbfs nodev /mnt/huge
cd ./dpdk/build/examples
#Change MAC Address eth-dest=0,<TRex Port 0 Mac Addr>  eth-dest=1,<TRex Port 1 Mac Addr>
./dpdk-l3fwd -l 1,2 -- -p 0xf --config="(0,0,1),(1,0,1)" -P --eth-dest=0,aa:aa:aa:aa:aa:aa --eth-dest=1,bb:bb:bb:bb:bb:bb
```

TRex
```bash
#Terminal 1
#cd to <user> home dir
cd ~/
sudo su
service vpp stop
mkdir /mnt/huge
echo 4096 >/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
mount -t hugetlbfs nodev /mnt/huge
#Change PCI Address
#For I226, No action
#For X710
    modprobe vfio
    echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
    modprobe vfio-pci
    ./dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.2
    ./dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.3
    #Unbind unused port
    ./dpdk/usertools/dpdk-devbind.py -u 01:00.0
    ./dpdk/usertools/dpdk-devbind.py -u 01:00.1
cd ./trex-core/scripts
#Change trex_cfg.yaml PCI Address
./t-rex-64 -i --no-scapy-server --cfg /root/trex_cfg.yaml  -c 1

#Terminal 2
#cd to <user> home dir
cd ~
sudo su
cd ./trex-core/scripts
./trex-console

#Change the speed, 0.95gbps, 2.45gbps, 9.95gbps
start -p 0 -f ./stl/VPP_1420B_1000f_port0.py  -m 2.45gbps --force
start -p 1 -f ./stl/VPP_1420B_1000f_port1.py  -m 2.45gbps --force
tui
```

### 6.c (Test 3) 2 NIC  VPP IPSec Test
DUT
```bash
#cd to <user> home dir
cd ~
sudo su
service vpp stop
#Change PCI address
#For I226
    modprobe uio_pci_generic
    ./dpdk/usertools/dpdk-devbind.py -b uio_pci_generic 04:00.0
    ./dpdk/usertools/dpdk-devbind.py -b uio_pci_generic 05:00.0
#For X710
    modprobe vfio
    echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
    modprobe vfio-pci
    ./dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.2
    ./dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.3
    #Unbind unused port
    ./dpdk/usertools/dpdk-devbind.py -u 01:00.0
    ./dpdk/usertools/dpdk-devbind.py -u 01:00.1

mkdir /mnt/huge
echo 2 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
mount -t hugetlbfs -o pagesize=1G nodev /mnt/huge
echo 2000 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
#Change Line 15 and Line 25 to <TRex Port 0 Mac Addr> in /root/VPP-IPSec-UD_2p1c1t2f_s0_1loss_gcm128_native-mb-I0-ep0.cfg
#Change Line 42 and Line 52 to <TRex Port 1 Mac Addr> in /root/VPP-IPSec-UD_2p1c1t2f_s0_1loss_gcm128_native-mb-I0-ep0.cfg
#Optional: Set different crypto handler in Line 55 /root/VPP-IPSec-UD_2p1c1t2f_s0_1loss_gcm128_native-mb-I0-ep0.cfg
# (Option A SW-QAT (default))    set crypto handler aes-128-gcm ipsecmb
# (Option B)                     set crypto handler aes-128-gcm openssl
vpp -c /root/VPP-IPSec-UD_2p1c1t2f_s0_1loss_gcm128_native-mb-I0-ep0.startup &

#Change Line 15 and Line 25 to <TRex Port 0 Mac Addr> in /root/VPP-IPSec-UD_2p1c1t2f_s0_1loss_gcm128_native-mb-I1-ep1.cfg
#Change Line 42 and Line 52 to <TRex Port 1 Mac Addr> in /root/VPP-IPSec-UD_2p1c1t2f_s0_1loss_gcm128_native-mb-I1-ep1.cfg
#Optional: Set different crypto handler in Line 55 /root/VPP-IPSec-UD_2p1c1t2f_s0_1loss_gcm128_native-mb-I0-ep1.cfg
# (Option A SW-QAT (default))    set crypto handler aes-128-gcm ipsecmb
# (Option B)                     set crypto handler aes-128-gcm openssl
vpp -c /root/VPP-IPSec-UD_2p1c1t2f_s0_1loss_gcm128_native-mb-I1-ep1.startup &
```

TRex
```bash
#Terminal 1
#cd to <user> home dir
cd ~
sudo su
service vpp stop
mkdir /mnt/huge
echo 4096 >/sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
mount -t hugetlbfs nodev /mnt/huge
#Change PCI Address
#For I226, No action
#For X710
    modprobe vfio
    echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
    modprobe vfio-pci
    ./dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.2
    ./dpdk/usertools/dpdk-devbind.py -b vfio-pci 01:00.3
    #Unbind unused port
    ./dpdk/usertools/dpdk-devbind.py -u 01:00.0
    ./dpdk/usertools/dpdk-devbind.py -u 01:00.1
cd ./trex-core/scripts
#Change trex_cfg.yaml PCI Address
./t-rex-64 -i --no-scapy-server --cfg /root/trex_cfg.yaml  -c 1

#Terminal 2
cd ~
sudo su
cd ./trex-core/scripts
./t-rex-64 -i --no-scapy-server --cfg /root/trex_cfg2.yaml  -c 1


#Terminal 3
#cd to <user> home dir
cd ~
sudo su
cd ./trex-core/scripts
./trex-console
#Change the speed, 0.95gbps, 2.45gbps, 9.95gbps
start -p 0 -f ./stl/IPSEC_1420B_1000f_port0.py  -m 2.45gbps --force
start -p 1 -f ./stl/IPSEC_1420B_1000f_port1.py  -m 2.45gbps --force

start -p 0 -f ./stl/IPSEC_64B_1000f_port0.py  -m 2.45gbps --force
start -p 1 -f ./stl/IPSEC_64B_1000f_port1.py  -m 2.45gbps --force

tui


#Terminal 4
#cd to <user> home dir
cd ~
sudo su
cd ./trex-core/scripts
./trex-console -p 4503
#Change the speed, 0.95gbps, 2.45gbps, 9.95gbps
start -p 0 -f ./stl/IPSEC_1420B_1000f_port0.py  -m 2.45gbps --force
start -p 1 -f ./stl/IPSEC_1420B_1000f_port1.py  -m 2.45gbps --force

start -p 0 -f ./stl/IPSEC_64B_1000f_port0.py  -m 2.45gbps --force
start -p 1 -f ./stl/IPSEC_64B_1000f_port1.py  -m 2.45gbps --force

tui

```
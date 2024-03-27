# VPP (Vector Packet Processing)
The Fast Data Project (FD.io) is an open-source project aimed at providing the world's 
fastest and most secure networking data plane through Vector Packet Processing (VPP).

# Validated Hardware
[Lanner NCA-4240](https://www.lannerinc.com/products/network-appliances/x86-rackmount-network-appliances/nca-4240)


## Steps
### 1. Build VPP
Build VPP
```bash
./setup_vpp.sh
```
Installation is completed when you see this message:
> ✓ VPP Build Complete 

### 2. Identify NIC PCI address for VPP
```bash
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

### 3. VPP Config
Create startup.conf in ~/vpp. Refer to the sample below
For more info please refer to [Configuring VPP](https://fd.io/docs/vpp/v2101/gettingstarted/users/configuring/)

```
unix {
  nodaemon
  #nobanner
  log /var/log/vpp/vpp.log
  cli-listen /run/vpp/cli.sock
  interactive
}

api-trace {
  on
}

socksvr {
  default

}

memory {
  main-heap-size 2G
  main-heap-page-size default-hugepage
}

statseg {
  size 128M
}

cpu {
        main-core 0
        corelist-workers 1
}

dpdk {
        no-multi-seg
        no-tx-checksum-offload
        dev 0000:01:00.0 {
             name eth0
             num-rx-queues 1
             workers 0
        }
        dev 0000:04:00.0 {
             name eth4
             num-rx-queues 1
             workers 0
        }
    }

plugins {
        plugin default { enable }
        plugin oddbuf_plugin.so { enable }
}
```

### 4. VPP Steps
For more info please refer to [Running VPP](https://s3-docs.fd.io/vpp/24.06/)

Run VPP
```bash
sudo su
echo 16 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
echo 16000 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

modprobe vfio
echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode

cd ~/
#For I226 use uio_pci_generic
modprobe uio_pci_generic
./vpp/build/external/downloads/dpdk-23.11/usertools/dpdk-devbind.py -b uio_pci_generic 04:00.0
#For X710 use vfio-pci
modprobe vfio-pci
./vpp/build/external/downloads/dpdk-23.11/usertools/dpdk-devbind.py -b vfio-pci 01:00.0
./vpp/build-root/install-vpp-native/vpp/bin/vpp -c ./vpp/startup.conf


#Example output, run `show int` to confirm device is loaded
unix_config:388: couldn't open log '/var/log/vpp/vpp.log'
vat-plug/load        [error ]: vat_plugin_register: idpf plugin not loaded...
    _______    _        _   _____  ___
 __/ __/ _ \  (_)__    | | / / _ \/ _ \
 _/ _// // / / / _ \   | |/ / ___/ ___/
 /_/ /____(_)_/\___/   |___/_/  /_/

vpp# show int
              Name               Idx    State  MTU (L3/IP4/IP6/MPLS)     Counter          Count
eth0                              1     down         2026/0/0/0
eth4                              2     down         2026/0/0/0
local0                            0     down          0/0/0/0
```

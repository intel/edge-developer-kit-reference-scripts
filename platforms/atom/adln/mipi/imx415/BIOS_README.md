# LEOPARD IMX415 MIPI BIOS Setup Guide

This is BIOS setup guide for enabling LEOPARD IMX415 MIPI for Intel® Alder-Lake N processor.

## Requirements

- BIOS Version 2.4 (UNADAM24)
- BIOS can be downloaded from [AAEON UP SQUARED Pro 7000 Website](https://newdata.aaeon.com.tw/DOWNLOAD/BIOS/UP%20Squared%20Pro%207000,%207000%20EDGE(UPN-ADLN01)/UNADAM24.zip)

#### Validated Hardware
- [AAEON UP Squared Pro 7000 (UPN-ADLNI3-A10-1664)](https://www.aaeon.com/en/p/up-board-up-squared-pro-7000)
- LEOPARD IMX415 MIPI Camera

## BIOS Setup

1. Go to **CRB Setup** from BIOS main page.
![BIOS main page](./images/1.png)

2. Select **CRB Chipset**.
![Select CRB Chipset](./images/2.png)

### 1. System Agent (SA) Configuration Setup

1. Select **System Agent (SA) Configuration**.
![Select System Agent (SA) Configuration](./images/3.png)

2. Disable **VT-d**, enable **IPU Device** and **IPU 1181 Dash Camera**. Select **MIPI Camera Configuration**.
![Enable IPU Device and IPU 1181 Dash Camera](./images/4.png)

4. Enable **Control Logic 1** and **Control Logic 2**. Enable **Camera 1** and **Camera 2**.
![Enable Control Logic and Camera](./images/5.png)

5. Set **Control Logic 1** based on the configuration shown below.
![Control Logic 1 Setting](./images/6.png)

6. Set **Control Logic 2** based on the configuration shown below.
![Control Logic 2 Setting](./images/7.png)

7. Set **Camera 1** based on the configuration shown below.
![Camera 1 - 1 Setting](./images/8.png)
![Camera 1 - 2 Setting](./images/9.png)

8. Set **Camera 2** based on the configuration shown below.
![Camera 2 - 1 Setting](./images/10.png)
![Camera 2 - 2 Setting](./images/11.png)

### 2. PCH-IO Configuration Setup

1. Select **PCH-IO Configuration**.
![Select PCH-IO Configuration](./images/12.png)

2. Go to **SerialIO Configuration**.
![Select SerialIO Configuration](./images/13.png)

3. Enable **I2C1 Controller** and **I2C5 Controller**.
![Enable I2C controller](./images/14.png)

After all the steps are completed, press **F4** key to **save and exit**.
   
## Next Steps

Refer to the available use cases and examples below

1. [Run LEOPARD IMX415 MIPI on ADL-N Board](./README.md) 


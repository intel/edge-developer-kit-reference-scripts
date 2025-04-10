#! /bin/bash

##############################################################################################
# Import auto-install yaml and grub.cfg to load autoinstaller
# This will help to create a custom iso installation on the raw image 
# called disk image. This disk image can be flashed directly using bmaptool on platform 
# and bootup can be done without additional installation steps.
#
# Reference: https://github.com/intel-innersource/os.linux.ubuntu-integration.build-automation/blob/main/autoinstall_scripts/inject_auto_install_script.sh
##############################################################################################

# uncomment the below lines to see the each command execution
# set -x

usage() {
  echo "Usage : $(basename "$0") -i <iso_link> "
  echo "Downloads the iso file and extract it to /mnt and install autoinstall specific files"
  echo "Options are below"
  echo "  -h, --help   | print usage information and exit"
  echo "  -i , --isolink  | provide the iso artifactory link"
}

while getopts "i:h" option
do
  case "$option" in
  i) iso_file="$OPTARG" ;;
  h|?) usage
	 exit
     ;;
 esac
done

echo "$iso_file"
file_name=$(basename "$iso_file")

if test "$iso_file" != ""
then
    if [ -e "$file_name" ]
    then
        echo "The file '$file_name' exists."
    else
        echo "Downloading the ISO "
        wget "$iso_file" --no-check-certificate
    fi
else
    echo "ERROR: iso file link not given"
    usage
    exit 1
fi

workspace=$(pwd)
downloaded_file=$(echo "$iso_file" | awk -F"/" '{ print $NF }')

if test -e "$downloaded_file" 
then
    echo "Downloaded file successfully"
else
    echo "Issue downloading iso file"
    exit 1
fi

is_mounted() {
    mount | awk -v DIR="$1" '{if ($3 == DIR) { echo "mounted alredy" }} ENDFILE{ echo "Not mounted" }'
}

echo "Mounting iso file to /mnt directory"

if is_mounted "/mnt/"
then
    echo "/mnt/ already mounted.unmounting it "
    umount /mnt
    echo "remounting with iso file"
    mount -o loop "$downloaded_file" /mnt
else
    mount -o loop "$downloaded_file" /mnt
fi

if test $? = 0
then
    echo "Mounting iso file to /mnt successful"
else
    echo "Mounting iso file to /mnt failed. Please check the directory"
    umount /mnt
    exit 1
fi

shopt -s dotglob

echo "Removing temporary custom_iso directory if exists"
if test -z /tmp/custom_iso
then
    rm -rf /tmp/custom_iso
    if test $? = 0
    then
        echo "Deleted the existing /tmp/custom_iso directory"
    else
        echo "ERROR: Failed deleting the existing /tmp/custom_iso directory"
	exit 1
    fi
fi

echo "Creating /tmp/custom_iso directory and copy iso files"

mkdir /tmp/custom_iso

if test -d /tmp/custom_iso
then
    echo "temp directory /tmp/custom_iso created successfully"
else
    echo "ERROR: issue creating /tmp/custom_iso directory"
    exit 1
fi

echo "Copying ISO contents to /tmp/custom_iso directory"
cp -avRf  /mnt/.  /tmp/custom_iso

if test $? = 0
then
    echo "Copying ISO files to /tmp/custom_iso done"
else
    echo "ERROR: Copying files to /tmp/custom_iso directory"
    exit 1
fi

blkid "$downloaded_file"

echo "Copying auto install scripts to /tmp/custom_iso directory"
cp -rf "$workspace"/autoinstall_24.04.yaml /tmp/custom_iso/autoinstall.yaml
cp -rf "$workspace"/grub.cfg /tmp/custom_iso/boot/grub/grub.cfg
cp -rf "$workspace"/\[BOOT\]/ /tmp/custom_iso/


check_file=$(ls /tmp/custom_iso/autoinstall.yaml)
if test $? = 0 
then
    echo "$check_file - File exists."
else
    echo "ERROR: Kickstart File does not exists."
    exit 1
fi

echo "Generating new iso file /tmp/ubuntu-24.04-custom.iso file from custom_iso directory"
cd /tmp/custom_iso/ || exit
mkisofs -o /tmp/ubuntu-24.04-custom.iso -b \[BOOT\]/1-Boot-NoEmul.img -J -R -l -iso-level 3 -J -joliet-long -input-charset utf-8 -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e \[BOOT\]/2-Boot-NoEmul.img -no-emul-boot -graft-points -V "OS" .
if test $? = 0 
then
    echo "Generation of iso is success"
else
    echo "ERROR: Generating iso file. Please check the command is correct"
    exit 1
fi

cd - || exit
if test -e /mnt
then
    echo "Unmounting the /mnt partition mounted to extract"
else
    echo "Already unmounted /mnt folder"
fi

echo "ISO Generation with auto install script Done . Custom ISO files are at /tmp/ubuntu-24.04-custom.iso"
#echo "Deleting the Downloaded ISO files to avoid uploading it"

cd "$workspace" || exit
#if test -e $downloaded_file
#then
#    rm -rf $downloaded_file
#fi

echo "Copying generated custom iso and renaming"
if test -f /tmp/ubuntu-24.04-custom.iso
then
    mv /tmp/ubuntu-24.04-custom.iso "$workspace"/
else
    echo "ERROR: custom iso generation has issues"
    exit 1
fi
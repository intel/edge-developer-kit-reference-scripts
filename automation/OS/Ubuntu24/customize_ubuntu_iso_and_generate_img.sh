#! /bin/bash
###############################################################################
# This bash script is used to create a custom iso by adding autoinstall and
# required boot files. Later same custom iso is used to install on the raw 
# filesystem and generate img using QEMU 
#
# usage: ./customize_ubuntu_iso_and_generate_img.sh -i <iso_link>
# Reference: https://github.com/intel-innersource/os.linux.ubuntu-integration.build-automation/blob/main/autoinstall_scripts/customize_ubuntu_iso_and_generate_img.sh
###############################################################################

# uncomment the below lines to see the each command execution
# set -x

usage() {
  echo "Usage : $(basename "$0") -i <iso_link> "
  echo "Downloads the iso file and extract it to /mnt and install autoinstall \
	specific files. Later the generation of disk image script called to \
	install the custom iso into raw image called disk image."
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

echo "ubuntu iso download link: $iso_file"


if test "$iso_file" != ""
then
    echo "Calling the injector script which will generate the custom iso for installation support with qemu"
    if test -f inject_auto_install_script.sh
    then
		echo "Injector script present in the workspace"
		echo "changing the injector script to execute mode"
		sudo chmod +x inject_auto_install_script.sh
		echo "Executing the injector script"
		if ./inject_auto_install_script.sh -i "$iso_file"; then
			echo "Injected script executed successfully"
			echo "calling the generator script to install custom iso to disk image"
			if test -f generate-ubuntu-img-from-iso.sh
			then
				echo "generator script is present in the workspace"
				echo "changing the generator script to execute mode"
				sudo chmod +x generate-ubuntu-img-from-iso.sh
				echo "Executing the generator script"
				processor=$(nproc)
				core_use=$((processor / 2))
				memory_available=$(grep -i MemA /proc/meminfo | awk -F " " '{ print $2 }')
				memory_use=$(echo "$memory_available * 0.7 / 1024" | bc) #Use 70% of memory available in the system
				echo "$core_use"
				echo "$memory_use"
				if test -f ubuntu-24.04-custom.iso; then
					if ./generate-ubuntu-img-from-iso.sh ubuntu-24.04-custom ubuntu-24.04-custom.iso "$memory_use" "$core_use"; then
						echo "ubuntu-24.04-custom.iso created successfully"
					else
						echo "ERROR: in generating custom img"
						exit 1
					fi
				else
					echo "ERROR: ubuntu-24.04-custom.iso file is missing"
					exit 1
				fi
			else
				echo "ERROR: generate-ubuntu-img-from-iso.sh is missing"
				exit 1
			fi
		else
			echo "ERROR: custom iso generation failed"
			exit 1
		fi
    else
		echo "ERROR: injector script is missing. Exiting"
		exit 1
    fi
else
    echo "ERROR: iso file link not given"
    usage
    exit 1
fi
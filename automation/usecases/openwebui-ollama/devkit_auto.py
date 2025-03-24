"""
Copyright (C) 2019 - 2024 Intel Corporation
This software and the related documents are Intel copyrighted materials, and
your use of them is governed by the express license under which they were
provided to you ("License"). Unless the License provides otherwise, you may not
use, modify, copy, publish, distribute, disclose or transmit this software or
the related documents without Intel's prior written permission.
This software and the related documents are provided as is, with no express or
implied warranties, other than those that are expressly stated in the License.
-------------------------------------------------------------------------------

"""

import os
import sys
import time
import argparse
import subprocess
import logging
import paramiko
import re


THM_SCRIPT_PATH = "/home/devkit_auto"
SUT_SCRIPT_PATH = "/home/user"
PASS_MSG = '"status":true'

# Enable logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def establish_ssh_connection(ip, username, password):
    """
    Establish SSH connection to the SUT.

    Args:
        ip (str): SUT IP address.
        username (str): SUT username.
        password (str): SUT password.

    Returns:
        ssh (paramiko.SSHClient): SSH connection object.

    """

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, username=username, password=password)
    return ssh


def run_command(ssh, command, ignore_stderr=False):
    """
    Executes command on remote SUT via SSH.

    Args:
        ssh (paramiko.SSHClient): The SSH client connected to the remote SUT.
        command (str): The command to be executed on the remote SUT.
        ignore_stderr (bool, optional): If True, ignores standard error output. Defaults to False.

    Returns:
        stdout_output (str): The standard output from the command.
        stderr_output (str): The standard error output from the command.

    Raises:
        RuntimeError: If the command execution fails and ignore_stderr is False.
    """

    stdin, stdout, stderr = ssh.exec_command(command)

    stdout_lines =[]
    stderr_lines = []

    logger.info("Run command: %s", command)

    # Read and print the command standard output and standard error output
    # to the SSH terminal
    while not stdout.channel.exit_status_ready():
        try:
            if stdout.channel.recv_ready():
                line = stdout.readline().strip()
                if line:
                    stdout_lines.append(line)
                    print(f"OUT:{line}")                
                
            if stderr.channel.recv_stderr_ready():
                line = stderr.readline().strip()
                if line:
                    stderr_lines.append(line)
                    print(f"OUT:{line}")
        except UnicodeDecodeError:
            stdout_lines.append("")
            stderr_lines.append("")
                                         

    stdout_output = "\n".join(stdout_lines)
    stderr_output = "\n".join(stderr_lines)
    last_stdout_line = stdout_output.split("\n")[-1]
    
    if stderr_output and not ignore_stderr:
        raise RuntimeError(f"Command Error: {stderr_output}")
    
    # if PASS_MSG in last_stdout_line:
    if PASS_MSG in last_stdout_line:
        # Close the channels
        stdout.channel.close()
        stderr.channel.close()
        stdin.channel.close()
        logger.info("Command execution completed.\n")
        return last_stdout_line, stderr_output
    else:
        # Read the remaining standard output and standard error output
        # stdout_output = stdout.read().decode().strip()
        # stderr_output = stderr.read().decode().strip()
        try:
            stdout_output = stdout.read().decode().strip()
            stderr_output = stderr.read().decode().strip()
        except UnicodeDecodeError:
            # For escape special symbol that unable to decode
            stdout_output = ""
            stderr_output = ""
        # Close the channels
        stdout.channel.close()
        stderr.channel.close()
        stdin.channel.close()
        logger.info("Command execution completed.\n")
        return stdout_output, stderr_output
    

def ping_test(ip, timeout=60):
    """
    Perform a ping test to check if a remote host is reachable.

    Args:
        ip (str): The IP address of the remote host to ping.
        timeout (int, optional): The maximum time in seconds to wait for the host to respond. 
                                Defaults to 60 seconds.

    Returns:
       True: The host is reachable within the timeout period.
       False: The host is not reacheable within the timeout period.
    """

    for _ in range(timeout):
        response = subprocess.run(['ping', '-c', '1', ip], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        if response.returncode == 0:
            return True
        time.sleep(1)
    return False

def remove_redundant_slashes(input):
    return re.sub(r'/{2,}','/',input)

def copy_script_to_remote(ssh, thm_path, remote_path):
    """
    Copy a script from the local machine to the remote SUT using SFTP.

    Args:
        ssh (paramiko.SSHClient): SSH connection object.
        thm_path (str): The path to the thm script.
        remote_path (str): The path on the remote SUT where the script will be copied.
    """
    sftp = ssh.open_sftp()

    sftp.chdir(remote_path)

    for file in os.listdir(thm_path):
        local_file_path = os.path.join(thm_path,file)
        if os.path.isfile(local_file_path):
            remote_file_path = os.path.join(remote_path,file)
            sftp.put(local_file_path,remote_file_path)
            
    sftp.close()

        
    return False

def copy_folder_to_remote(sftp, thm_path, sut_path):
    """
    Copy a script from the local machine to the remote SUT using SFTP.

    Args:
        ssh (paramiko.SSHClient): SSH connection object.
        thm_path (str): The path to the thm script.
        remote_path (str): The path on the remote SUT where the script will be copied.
    """

    for item in os.listdir(thm_path):
        local_path = os.path.join(thm_path, item)
        remote_path = os.path.join(sut_path, item)

        if os.path.isdir(local_path):
            try:
                sftp.mkdir(remote_path)
            except OSError:
                #directory already exists
                pass
            copy_folder_to_remote(sftp,local_path,remote_path)
        else:
            sftp.put(local_path,remote_path)

        
    return False


def cleanup(ssh, script_path,openwebui_script_path):
    """
    Perform post-test cleanup on the remote SUT.

    Args:
        ssh (paramiko.SSHClient): SSH connection object.
        script_path (str): The script path to be removed on the remote SUT.
        openwebui_script_path (str): The usecase script path for bringing down the containers. 

    """
    try:
        logger.info("Post-test cleanup...")   
        run_command(ssh, f"cd {openwebui_script_path} && \
                    docker compose down -v && \
                    sleep 45s && \
                    cd /home/ && \
                    rm -rf {SUT_SCRIPT_PATH}{script_path} && \
                    docker rmi ghcr.io/open-webui/open-webui:main intel-ipex-ollama:latest stt_service:latest tts_service:latest")
                   
        logger.info("Successfully removed related docker images on SUT.")
        # run_command(ssh, f"rm -rf {SUT_SCRIPT_PATH}{script_path}")
        logger.info("Successfully removed %s%s on SUT.", SUT_SCRIPT_PATH, script_path)
        
    except Exception as e:
        logger.error("Failed to remove %s%s on SUT: %s", SUT_SCRIPT_PATH, script_path, e)

def main():
    """
    Main function to run the devkit BKC installation test.

    This function parses command-line arguments, establishes an SSH connection to the SUT,
    runs the necessary commands on the SUT, handles reboots if required, and performs a ping
    test to check if the SUT is back online after a reboot.

    Command-line Arguments:
        --sut_ip (str): SUT IP address.
        --sut_username (str): SUT username.
        --sut_password (str): SUT password.
        --script_path (str): SUT script path.
        --script (str): Script to run on SUT.
    """

    parser = argparse.ArgumentParser(description="Run devkit BKC installation test")
    
    # Define arguments for SUT
    parser.add_argument('--sut_ip', required=True, help='SUT IP address')
    parser.add_argument('--sut_username', required=True, help='SUT username')
    parser.add_argument('--sut_password', required=True, help='SUT password')
    parser.add_argument('--openwebui_script_path', required=True, help='SUT script path.'
                        ' NOTE:The script path must start and end with "/", e.g. /home/user/')
    parser.add_argument('--stt_device', required=True, help='Select device to run stt_service. e.g. CPU,GPU')
    parser.add_argument('--tts_device', required=True, help='Select device to run tts_service. e.g. CPU,GPU,NPU')
    parser.add_argument('--bert_device', required=True, help='Select device to run tts_service bert_device. e.g. CPU,GPU,NPU')
    
    
    tts_test = False
    stt_test = False
    ollama_test = False
    # Parse arguments and store in args object
    args = parser.parse_args()

    # Extract the base directory from the script path for post-test cleanup
    base_path = os.path.normpath(args.openwebui_script_path).split(os.sep)[1]

    # Connect to SUT
    sut_ssh = establish_ssh_connection(args.sut_ip, args.sut_username, args.sut_password)
    
    if sut_ssh:
        logger.info("Successfully SSH to SUT")
        thm_script_folder = THM_SCRIPT_PATH + args.openwebui_script_path

        sut_script_folder = SUT_SCRIPT_PATH + args.openwebui_script_path
        thm_microservice_folder = THM_SCRIPT_PATH + "/usecases/ai/microservices/"
        sut_microservice_folder = SUT_SCRIPT_PATH + "/usecases/ai/microservices/"
        
        remove_redundant_slashes(thm_script_folder)
        remove_redundant_slashes(sut_script_folder)
        remove_redundant_slashes(thm_microservice_folder)
        remove_redundant_slashes(sut_microservice_folder)

        # Run command on SUT
        run_command(sut_ssh, f"cd {SUT_SCRIPT_PATH}")
        run_command(sut_ssh, f"mkdir -p {sut_script_folder}")
        run_command(sut_ssh, f"mkdir -p {sut_microservice_folder}")
        # Copy the script to the remote SUT
        copy_script_to_remote(sut_ssh, f"{thm_script_folder}", 
                              f"{sut_script_folder}")
        copy_script_to_remote(sut_ssh, f"{thm_script_folder}", 
                              f"{sut_script_folder}")
        sftp = sut_ssh.open_sftp()
        copy_folder_to_remote(sftp, f"{thm_microservice_folder}", 
                              f"{sut_microservice_folder}")
        sftp.close()
        
        export_env_cmd = "export RENDER_GROUP_ID=$(getent group render | cut -d: -f3)"

        if args.stt_device=="GPU":
            export_env_cmd += " && export STT_DEVICE=GPU"
        elif args.stt_device=="NPU":
            export_env_cmd += " && export STT_DEVICE=NPU"
        else:
            export_env_cmd += " && export STT_DEVICE=CPU"
        
        if args.tts_device=="GPU":
            export_env_cmd += " && export TTS_DEVICE=GPU"
        elif args.tts_device=="NPU":
            export_env_cmd += " && export TTS_DEVICE=NPU"
        else:
            export_env_cmd += " && export TTS_DEVICE=CPU"

        if args.bert_device=="GPU":
            export_env_cmd += " && export BERT_DEVICE=GPU"
        elif args.bert_device=="NPU":
            export_env_cmd += " && export BERT_DEVICE=NPU"
        else:
            export_env_cmd += " && export BERT_DEVICE=CPU"


        # run_command(sut_ssh, f"{export_env_cmd} && cd {sut_script_folder} && docker compose build")
        while True:
            # Run BKC installation script on SUT                               
            
            stdout, _ = run_command(sut_ssh, f"{export_env_cmd} && \
                                    cd {sut_script_folder} && \
                                    docker compose build && \
                                    docker compose up -d && \
                                    sleep 30s && \
                                    curl http://localhost:80/health" , ignore_stderr=True)

            if stdout:
                last_stdout_line = stdout.split("\n")[-1]
                logger.info("Last line of stdout: %s", last_stdout_line)
                
                if PASS_MSG in last_stdout_line:
                    logger.info(f"Openwebui-Ollama Use Case Installation Test Pass.")
                    cleanup(sut_ssh, f"/{base_path}",sut_script_folder) # Perform post-test cleanup
                    sut_ssh.close() 
                    sys.exit(0)  # Exit the script with a success status code

            else:
                logger.error("Use Case Installation Test Fail.")
                cleanup(sut_ssh, f"/{base_path}",sut_script_folder)
                sut_ssh.close()
                sys.exit(1)
    else:
        logger.error("Fail to SSH to SUT")
        cleanup(sut_ssh, f"/{base_path}",sut_script_folder)
        sut_ssh.close()
        sys.exit(1)

if __name__ == "__main__":
	main()
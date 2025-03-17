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
import chardet


THM_SCRIPT_PATH = "/home/devkit_auto"
SUT_SCRIPT_PATH = "/home/user"
PASS_MSG = "OK"

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
            # For escape special symbol that unable to decode
            stdout_lines.append("")
            stderr_lines.append("")                               

    stdout_output = "\n".join(stdout_lines)
    stderr_output = "\n".join(stderr_lines)
    last_stdout_line = stdout_output.split("\n")[-1]
    
    if stderr_output and not ignore_stderr:
        raise RuntimeError(f"Command Error: {stderr_output}")
    
    if PASS_MSG in last_stdout_line:
        # Close the channels
        stdout.channel.close()
        stderr.channel.close()
        stdin.channel.close()
        logger.info("Command execution completed.\n")
        return last_stdout_line, stderr_output
    else:
        # Read the remaining standard output and standard error output
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
    
def run_command_no_output(ssh, command, ignore_stderr=False):
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

    ssh.exec_command(command)


    logger.info("Run command: %s", command)

   

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

def cleanup(ssh, script_path):
    """
    Perform post-test cleanup on the remote SUT.

    Args:
        ssh (paramiko.SSHClient): SSH connection object.
        script_path (str): The script path to be removed on the remote SUT.
    """
    try:
        logger.info("Post-test cleanup...")
        run_command(ssh, f"rm -rf {SUT_SCRIPT_PATH}{script_path}")
        logger.info("Successfully removed %s%s on SUT.", SUT_SCRIPT_PATH, script_path)
        run_command(ssh, "docker stop tts_app && docker rm tts_app")
        run_command(ssh,"docker rmi -f tts_app")
        logger.info("Successfully removed related docker images on SUT.")
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
        --usecase_script_path_tts (str): SUT script path.
        --tts_device (str): Device to run.
    """

    parser = argparse.ArgumentParser(description="Run devkit BKC installation test")
    
    # Define arguments for SUT
    parser.add_argument('--sut_ip', required=True, help='SUT IP address')
    parser.add_argument('--sut_username', required=True, help='SUT username')
    parser.add_argument('--sut_password', required=True, help='SUT password')
    parser.add_argument('--usecase_script_path_tts', required=True, help='SUT script path.'
                        ' NOTE:The script path must start and end with "/", e.g. /home/user/')
    parser.add_argument('--tts_device', required=True, help='Select device to run stt_service. e.g. CPU,GPU')
    parser.add_argument('--bert_device', required=True, help='Select device to run tts_service bert_device. e.g. CPU,GPU,NPU')
    

    # Parse arguments and store in args object
    args = parser.parse_args()

    # Extract the base directory from the script path for post-test cleanup
    base_path = os.path.normpath(args.usecase_script_path_tts).split(os.sep)[1]

    # Connect to SUT
    sut_ssh = establish_ssh_connection(args.sut_ip, args.sut_username, args.sut_password)
    
    if sut_ssh:
        logger.info("Successfully SSH to SUT")
        thm_script_folder = THM_SCRIPT_PATH + args.usecase_script_path_tts

        sut_script_folder = SUT_SCRIPT_PATH + args.usecase_script_path_tts
        remove_redundant_slashes(thm_script_folder)
        remove_redundant_slashes(sut_script_folder)


        # Run command on SUT
        run_command(sut_ssh, f"cd {SUT_SCRIPT_PATH}")
        run_command(sut_ssh, f"mkdir -p {sut_script_folder}")
        # Copy the script to the remote SUT
        copy_script_to_remote(sut_ssh, f"{thm_script_folder}", 
                              f"{sut_script_folder}")
        if args.tts_device == "GPU":
            docker_run_cmd =f"docker run -it --rm \
                --name tts_app \
                --group-add $RENDER_GROUP_ID \
                --device /dev/dri:/dev/dri \
                -p 5995:5995 \
                -e TTS_DEVICE=GPU \
                -e BERT_DEVICE={args.bert_device} \
                tts_app"
        elif args.tts_device == "NPU":
            docker_run_cmd = f"docker run -d \
                --name tts_app \
                --group-add $RENDER_GROUP_ID \
                --device /dev/dri:/dev/dri \
                --device /dev/accel:/dev/accel \
                -p 5995:5995 \
                -e TTS_DEVICE=CPU \
                -e BERT_DEVICE={args.bert_device} \
                tts_app"
        else:
            docker_run_cmd =f"docker run -d \
                --name tts_app \
                -p 5995:5995 \
                -e TTS_DEVICE=CPU \
                -e BERT_DEVICE={args.bert_device} \
                tts_app"
        export_env_cmd = "export RENDER_GROUP_ID=$(getent group render | cut -d: -f3)"
        # run_command_no_output(sut_ssh, f"{export_env_cmd} && cd {sut_script_folder} && docker build -t tts_app . ")
        # run_command(sut_ssh, f"{export_env_cmd} && cd {sut_script_folder} && docker build -t tts_app . ")
        while True:
            # Run BKC installation script on SUT                               
            get_health_check_cmd = "curl http://localhost:5995/healthcheck"
            
            stdout, _ = run_command(sut_ssh, f"{export_env_cmd} && cd {sut_script_folder} && docker build -t tts_app . && {docker_run_cmd} && sleep 5m && {get_health_check_cmd}", ignore_stderr=True)
            # stdout, _ = run_command(sut_ssh, f"{export_env_cmd} && cd {sut_script_folder} && {docker_run_cmd} && sleep 5m && {get_health_check_cmd}", ignore_stderr=True)
            
            if stdout:
                last_stdout_line = stdout.split("\n")[-1]
                logger.info("Last line of stdout: %s", last_stdout_line)
                if PASS_MSG in last_stdout_line:
                    print("speech-to-text usecase successfully executed")

                    logger.info("Use Case Installation Test Pass.")
                    cleanup(sut_ssh, f"/{base_path}") # Perform post-test cleanup
                    sut_ssh.close() 
                    sys.exit(0)  # Exit the script with a success status code
            else:
                logger.error("Use Case Installation Test Fail.")
                cleanup(sut_ssh, f"/{base_path}")
                sut_ssh.close()
                sys.exit(1)
    else:
        logger.error("Fail to SSH to SUT")
        cleanup(sut_ssh, f"/{base_path}")
        sut_ssh.close()
        sys.exit(1)

if __name__ == "__main__":
	main()
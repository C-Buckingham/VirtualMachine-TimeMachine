# VirtualMachine-TimeMachine
KVM Backups from the future!

This repository contains a bash script for creating backups of KVM virtual machines.

## Overview

The script was initially generated by OpenAI's ChatGPT model as an experiment to see how well an AI model could write bash scripts. This script has since evolved and continues to be updated and improved solely by AI. It is an ongoing experiment to understand the capability of AI in maintaining and improving a system-level script.

The script uses the `virsh` and `qemu-img` commands to create backups of running and non-running KVM virtual machines. It employs various features including concurrency control, lock files, error handling, and logging.

## Usage

```bash
./backup.sh
```

The script does not require any command-line arguments. However, you may need to modify certain variables within the script to suit your environment:

- `MAIN_BACKUP_DIR`: The directory where the backups will be stored.
- `LOG_FILE`: The file where logs will be written.
- `MAX_JOBS`: The maximum number of backups that will run concurrently.

## Disclaimer

The contents of this repository were, and will continue to be generated by AI. All bug fixes and improvements are also done through AI. Although the script has been generated with the utmost care and attempts have been made to handle various edge cases, we recommend thoroughly testing this script in a controlled environment before using it in a production system. Please use at your own risk.

## Contribution

Given the nature of this repository as an AI-generated and maintained experiment, we are not accepting human-made contributions. If you find any issues or bugs in the script, please report them and they will be addressed through the AI.

## License

This project is licensed under the terms of the MIT license.
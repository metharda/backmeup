# BackMeUp
<div align="center">

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Shell](https://img.shields.io/badge/shell-bash-green.svg)
![Platform](https://img.shields.io/badge/platform-linux-lightgrey.svg)

</div>

BackMeUp is a simple yet powerful backup automation tool that helps you schedule and manage directory backups with ease. It provides an intuitive CLI interface, automatic rotation, flexible scheduling options, and remote backup support via SSH.

## Features

**Smart Backup Management**
- Automatic backup rotation with configurable retention
- Duplicate detection and prevention
- Multi-destination support for the same source
- Multiple compression formats (tar.gz, zip, tar.bz2, tar.xz)

**Remote Backup Support**
- SSH-based remote transfers
- Local-only, remote-only, or both backup modes
- Interactive SSH key setup and authentication
- Automatic host key management
- Optional local cleanup after remote transfer

**Flexible Scheduling**
- Preset schedules (hourly, daily, weekly, monthly)
- Custom cron expressions for advanced scheduling
- Easy schedule updates without recreating backups

**Organized Storage**
- Scripts stored in source directory's `.backmeup` folder
- Timestamped backup archives
- Automatic cleanup of old backups
- `.backmeup` excluded from backups automatically

**User-Friendly Interface**
- Interactive mode with step-by-step guidance
- Flag-based CLI for automation
- Comprehensive backup listing and management

## Installation

### One-Line Install

Install BackMeUp with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/metharda/backmeup/main/scripts/install.sh | bash
```

Or using wget:

```bash
wget -qO- https://raw.githubusercontent.com/metharda/backmeup/main/scripts/install.sh | bash
```

This will:
- Download all required scripts to `/usr/local/lib/backmeup`
- Install main binary to `/usr/local/bin/backmeup`
- Make the command available system-wide

### Manual Install from Repository

If you prefer to install from a cloned repository:

```bash
git clone https://github.com/metharda/backmeup.git
cd backmeup/scripts
chmod +x install.sh
./install.sh
```

The installer will detect it's running from the repository and install all files properly.

### Verification

Verify the installation:

```bash
backmeup help
```

## Quick Start

### Interactive Mode

The easiest way to create your first backup:

```bash
backmeup backup start -i
```

Follow the prompts to configure:
1. Source directory to backup
2. Backup type (local/remote/both)
3. Destination directory or remote server
4. Compression format
5. Backup schedule
6. Number of backups to keep

### Command Line Mode

Create a backup with a single command:

```bash
backmeup backup start -d ~/Documents -o ~/Backups -t daily -b 7 -c tar.gz
```

## Uninstallation

### Using Command

```bash
backmeup uninstall
```

### Direct Script

```bash
curl -fsSL https://raw.githubusercontent.com/metharda/backmeup/main/scripts/uninstall.sh | bash
```

The uninstaller will:
- Remove the binary from `/usr/local/bin`
- Delete library files from `/usr/local/lib/backmeup`
- Optionally remove backup configurations
- Clean up `.backmeup` directories
- Remove associated cron jobs

## Usage

### Commands

```bash
backmeup backup <command> [options]
```

**Available Commands:**
- `start` - Create a new backup schedule
- `update` - Modify an existing backup
- `delete` - Remove a backup and its schedule
- `list` - Display all configured backups
- `help` - Show usage information

### Options

| Flag | Description | Example |
|------|-------------|---------|
| `-d, --directory` | Source directory to backup | `-d ~/Documents` |
| `-o, --output` | Backup destination directory | `-o ~/Backups` |
| `-t, --time-period` | Backup schedule | `-t daily` or `-t "0 3 * * *"` |
| `-b, --backup-count <num>` | Number of backups to keep (default: 5) | `-b 10` |
| `-c, --compression <type>` | Compression method (tar.gz/zip/tar.bz2/tar.xz) | `-c zip` |
| `-i, --interactive` | Launch interactive mode | `-i` |

### Schedule Presets

| Preset | Description | Cron Expression |
|--------|-------------|-----------------|
| `hourly` | Every hour | `0 * * * *` |
| `daily` | Every day at 2:00 AM | `0 2 * * *` |
| `weekly` | Every Sunday at 2:00 AM | `0 2 * * 0` |
| `monthly` | First day of month at 2:00 AM | `0 2 1 * *` |

## Examples

### Basic Backup

Create a daily backup of your documents:

```bash
backmeup backup start -d ~/Documents -o ~/Backups -t daily
```

### Remote Backup

Interactive mode with remote backup:

```bash
backmeup backup start -i
# Choose option 2 (Remote only) or 3 (Both)
# Follow prompts for SSH configuration
```

### Multiple Backups of Same Source

Backup documents to multiple locations with different schedules:

```bash
# Daily backup to local drive
backmeup backup start -d ~/Documents -o ~/Backups -t daily

# Weekly backup to external drive
backmeup backup start -d ~/Documents -o /mnt/external/backups -t weekly
```

These will create `Documents` and `Documents-1` backups automatically.

### Custom Schedule

Backup every 6 hours:

```bash
backmeup backup start -d ~/Projects -o ~/Backups -t "0 */6 * * *"
```

### High-Retention Backup

Keep 30 backups for critical data:

```bash
backmeup backup start -d ~/Important -o ~/Archives -t daily -b 30
```

### Different Compression Formats

Use `zip` for compatibility or `tar.xz` for better compression:

```bash
backmeup backup start -d ~/Photos -o ~/Backups -t weekly -c tar.xz
```

### Update Existing Backup

Change schedule or retention:

```bash
# Update schedule
backmeup backup update Documents -t weekly

# Update retention count
backmeup backup update Documents -b 15

# Update both
backmeup backup update Documents -t monthly -b 20
```

### List All Backups

```bash
backmeup backup list
```

Output:
```
=== Configured Backups ===

Name:       Documents
Source:     /home/user/Documents
Output:     /home/user/Backups
Schedule:   daily
Keep:       7 backups
Format:     tar.gz
Script:     /home/user/Documents/.backmeup/backup_Documents.sh
---
```

### Delete Backup

Remove backup configuration and cron job:

```bash
backmeup backup delete Documents
```

### Run Manual Backup

Execute a backup immediately without waiting for schedule:

```bash
/path/to/source/.backmeup/backup_Documents.sh
```

### Test Installation

Run the test suite:

```bash
backmeup test
```

## File Structure

```
backmeup/
├── backmeup.sh              # Main entry point
├── scripts/
│   ├── backup.sh            # Core backup logic
│   ├── cron.sh              # Cron management
│   ├── ssh_utils.sh         # SSH utilities
│   ├── install.sh           # Installer
│   └── uninstall.sh         # Uninstaller
├── test/
│   └── test.sh              # Test suite
└── README.md

User files:
~/.config/backmeup/
└── backups.conf             # Backup configurations

Source directory:
~/Documents/
└── .backmeup/
    └── backup_Documents.sh  # Generated backup script

Output directory:
~/Backups/
├── Documents_20241118_140523.tar.gz
├── Documents_20241117_140502.tar.gz
└── ...
```

## How It Works

1. **Configuration**: BackMeUp stores backup metadata in `~/.config/backmeup/backups.conf`
2. **Script Generation**: Creates executable backup scripts in the source directory's `.backmeup` folder
3. **Cron Integration**: Automatically adds cron jobs with descriptive markers
4. **Execution**: Cron runs the backup script, which creates timestamped archives (excluding `.backmeup`)
5. **Rotation**: Automatically removes old backups based on retention count
6. **Remote Transfer** (optional): Transfers backups to remote server via SSH/SCP

## Backup Format

Archives are created with the following naming convention:
```
{source_name}_{YYYYMMDD}_{HHMMSS}.{extension}
```

Example: `Documents_20241118_140523.tar.gz` or `Photos_20241118_140523.zip`

## Requirements

- **OS**: Linux (Ubuntu, Debian, CentOS, etc.)
- **Shell**: Bash 4.0+
- **Tools**: tar, gzip, cron
- **Optional**: zip, bzip2, xz (for additional compression formats)
- **Remote Backups**: ssh, scp, ssh-keygen, ssh-copy-id
- **Permissions**: Write access to source and destination directories

## Troubleshooting

### Check Cron Jobs

View all BackMeUp cron jobs:
```bash
crontab -l | grep -i backmeup
```

### Verify Backup Script

Check if the backup script exists and is executable:
```bash
ls -la ~/Documents/.backmeup/
```

### Test Manual Execution

Run a backup script manually to check for errors:
```bash
bash -x ~/Documents/.backmeup/backup_Documents.sh
```

### View Configuration

Check your backup configurations:
```bash
cat ~/.config/backmeup/backups.conf
```

### SSH Connection Issues

Test SSH connection manually:
```bash
ssh -v user@host
```

Check SSH key:
```bash
ls -la ~/.ssh/
```

### Run Tests

Execute the test suite:
```bash
backmeup test
```

<div align="center">
A simple backup script for Linux
</div>

# BackMeUp
<div align="center">

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Shell](https://img.shields.io/badge/shell-bash-green.svg)
![Platform](https://img.shields.io/badge/platform-linux-lightgrey.svg)

</div>


BackMeUp is a simple yet powerful backup automation tool that helps you schedule and manage directory backups with ease. It provides an intuitive CLI interface, automatic rotation, and flexible scheduling options through cron integration.

## Features

**Smart Backup Management**
- Automatic backup rotation with configurable retention
- Duplicate detection and prevention
- Multi-destination support for the same source
- Multiple compression formats (tar.gz, zip, tar.bz2, tar.xz)

**Flexible Scheduling**
- Preset schedules (hourly, daily, weekly, monthly)
- Custom cron expressions for advanced scheduling
- Easy schedule updates without recreating backups

**Organized Storage**
- Hidden `.backmeup` directory for scripts
- Timestamped backup archives
- Automatic cleanup of old backups

**User-Friendly Interface**
- Interactive mode for guided setup
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

## Uninstallation

### Using Command

The easiest way to uninstall:

```bash
backmeup uninstall
```

### Direct Script

Or run the uninstaller directly:

```bash
curl -fsSL https://raw.githubusercontent.com/metharda/backmeup/main/scripts/uninstall.sh | bash
```

The uninstaller will:
- Remove the binary from `/usr/local/bin`
- Delete library files from `/usr/local/lib/backmeup`
- Optionally remove backup configurations
- Clean up `.backmeup` directories
- Remove associated cron jobs

You'll be prompted to confirm each step.
git clone https://github.com/metharda/backmeup.git
cd backmeup
chmod +x backmeup.sh scripts/*.sh
```

### Add to PATH (Optional)

```bash
sudo ln -s "$(pwd)/backmeup.sh" /usr/local/bin/backmeup
```

## Quick Start

### Interactive Mode

The easiest way to create your first backup:

```bash
./backmeup.sh backup start -i
```

Follow the prompts to configure:
1. Source directory to backup
2. Destination directory
3. Backup schedule
3. Backup schedule
4. Number of backups to keep
5. Compression method

### Command Line Mode

Create a backup with a single command:

```bash
./backmeup.sh backup start -d ~/Documents -o ~/Backups -t daily -b 7 -c tar.gz
```

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
./backmeup.sh backup start -d ~/Documents -o ~/Backups -t daily
```

### Multiple Backups of Same Source

Backup documents to multiple locations with different schedules:

```bash
# Daily backup to external drive
./backmeup.sh backup start -d ~/Documents -o /mnt/external/backups -t daily

# Weekly backup to NAS
./backmeup.sh backup start -d ~/Documents -o /mnt/nas/backups -t weekly
```

These will create `Documents` and `Documents-1` backups automatically.

### Custom Schedule

Backup every 6 hours:

```bash
./backmeup.sh backup start -d ~/Projects -o ~/Backups -t "0 */6 * * *"
```

### High-Retention Backup

Keep 30 backups for critical data:

```bash
./backmeup.sh backup start -d ~/Important -o ~/Archives -t daily -b 30
```

### Different Compression Formats

Use `zip` for compatibility or `tar.xz` for better compression:

```bash
./backmeup.sh backup start -d ~/Photos -o ~/Backups -t weekly -c tar.xz
```

### Update Existing Backup

Change schedule or retention:

```bash
# Update schedule
./backmeup.sh backup update Documents -t weekly

# Update retention count
./backmeup.sh backup update Documents -b 15

# Update both
./backmeup.sh backup update Documents -t monthly -b 20
```

### List All Backups

```bash
./backmeup.sh backup list
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
Script:     /home/user/Backups/.backmeup/backup_Documents.sh
---
```

### Delete Backup

Remove backup configuration and cron job:

```bash
./backmeup.sh backup delete Documents
```

### Run Manual Backup

Execute a backup immediately without waiting for schedule:

```bash
/path/to/output/.backmeup/backup_Documents.sh
```

## File Structure

```
backmeup/
├── backmeup.sh              # Main entry point
├── scripts/
│   ├── backup.sh            # Core backup logic
│   └── cron.sh             # Cron management
└── README.md

User files:
~/.config/backmeup/
└── backups.conf            # Backup configurations

Output directory:
~/Backups/
├── .backmeup/              # Hidden scripts directory
│   └── backup_Documents.sh # Generated backup script
├── Documents_20241118_140523.tar.gz
├── Documents_20241117_140502.tar.gz
└── ...
```

## How It Works

1. **Configuration**: BackMeUp stores backup metadata in `~/.config/backmeup/backups.conf`
2. **Script Generation**: Creates executable backup scripts in the output directory's `.backmeup` folder
3. **Cron Integration**: Automatically adds cron jobs with descriptive markers
4. **Execution**: Cron runs the backup script, which creates timestamped archives
5. **Rotation**: Automatically removes old backups based on retention count

## Backup Format

Archives are created with the following naming convention:
```
{source_name}_{YYYYMMDD}_{HHMMSS}.{extension}
```

Example: `Documents_20241118_140523.tar.gz` or `Photos_20241118_140523.zip`

## Requirements

- **OS**: Linux (Ubuntu, Debian, CentOS, etc.)
- **Shell**: Bash 4.0+
- **Tools**: tar, gzip, cron (optional: zip, bzip2, xz)
- **Optional**: zip, bzip2, xz (for additional compression formats)
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
ls -la ~/Backups/.backmeup/
```

### Test Manual Execution

Run a backup script manually to check for errors:
```bash
bash -x ~/Backups/.backmeup/backup_Documents.sh
```

### View Configuration

Check your backup configurations:
```bash
cat ~/.config/backmeup/backups.conf
```


<div align="center">
a small backup script
</div>

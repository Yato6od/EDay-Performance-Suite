# E-Day Performance Suite — Universal Edition

Performance configuration profiles and helper scripts for **Gears of War: E-Day** on Windows.

> **Unofficial community project.** This project is not affiliated with, endorsed by, or supported by NVIDIA or the game's developers/publisher.

## Features

- Windows batch (`.bat`) menu for launching the PowerShell installer.
- PowerShell script for applying performance profiles and diagnosing configuration paths.
- Available profiles:
  - **PERF** — performance-focused profile intended to retain functional smoke/fog.
  - **ULTRA** — more aggressive performance-focused profile; intended to retain functional smoke/fog.
  - **RT** — alternative RT-compatible profile.
- Backup-based configuration restoration, when valid backups are available.
- Spanish-language PDF user manual.

## Requirements

- Windows with Windows PowerShell.
- A compatible installation of Gears of War: E-Day.
- Keep the `.bat`, `.ps1`, five `.ini` profile files, and PDF manual together in the same folder unless you have updated the script paths accordingly.
- NVIDIA RTX hardware is the intended target for DLSS-related recommendations. DLSS availability and modes depend on the GPU, game version, and driver. The profiles may apply configuration tweaks independently of DLSS availability.

## Files

- `EDay_Performance_Suite.bat` — launcher/menu.
- `EDay_Performance_Suite.ps1` — installer, diagnostic, and restoration logic.
- `Engine_Performance_SmokeSafe.ini`
- `Engine_Performance_Plus_SmokeSafe.ini`
- `Engine_RT_SmokeSafe.ini`
- `Scalability_Low_SmokeSafe.ini`
- `Scalability_Enhanced.ini`
- `Manual_EDay_Performance_Suite.pdf` — user manual.

## Installation

1. Download the repository (Code → Download ZIP) and extract it.
2. Keep the `.bat`, `.ps1`, profile `.ini` files, and PDF manual together in one folder.
3. Close the game before applying or restoring profiles.
4. Run `EDay_Performance_Suite.bat`.
5. Read the on-screen messages and follow the selected action.
6. For the ULTRA profile, check the in-game graphics menu manually. Start with 1920×1080 if appropriate for your display, and compare DLSS modes for image clarity and performance if DLSS is available.

## Restoration and backups

The PowerShell script has restoration logic that attempts to restore available backups. Restoration is only as reliable as the backup files and installation-state record on the user's computer.

- Keep `.eds-original.bak`, `.melly-stock-backup`, and `.eds-install-state.json` files created on your own system.
- Do not upload personal backups or machine-specific configuration state to this public repository.
- Close the game before restoring.
- Review the script output to see which files were restored or could not be restored.

Restoring configuration files does not necessarily reset every graphics option stored internally by the game.

## Performance expectations

Results vary with GPU, CPU, RAM, driver version, game build, resolution, and scene. **No specific FPS, minimum FPS, or performance improvement is guaranteed.** Test profiles under comparable conditions and keep a copy of your original configuration.

DLSS Ultra Performance may reduce image sharpness at 1080p. Compare Performance or Balanced if the image is too blurry.

## Safety notes

- Review scripts before running them.
- Keep personal backups outside the public repository.
- Do not combine profiles with other mods that conflict with the same configuration variables.
- The project is provided “as is”, without warranty.

## Contributing

Issues and suggestions are welcome. Include your GPU, CPU, game version, driver version, resolution, selected profile, and reproducible test results. Do not attach personal configuration backups or sensitive logs.

## License

No license has been selected yet. Unless a license is added, the code remains protected by its applicable copyright; public visibility alone does not grant permission to reuse, modify, or redistribute it.

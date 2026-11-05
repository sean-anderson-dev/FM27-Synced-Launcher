# FM27 Synced Launcher

Play the same Football Manager 27 save on more than one PC (e.g. a desktop and a laptop) using OneDrive, without corrupted or conflicting saves.

## Why

Steam Cloud saves for FM are unreliable for multi-device play:

- Steam Cloud known for erros and issues (hence my quick solution to never having my save available on my laptop)
- Only saves made with **Save Game As → Cloud** are synced. Normal saves aren't synced.
- Syncing only happens when you exit, and failures are easy to miss.
- Large saves have hit size limits on cloud sync after a few seasons normally, which stops you saving at all.

Syncing your normal save folder with OneDrive has a different problem. OneDrive starts uploading a save while FM is still writing it, which leads to corrupted saves and conflict copies.

This launcher fixes that by pausing OneDrive while FM is running, so the save is only uploaded once it's finished. It also takes local backups before and after every session just in case.

## What it does

Each time you launch FM through the shortcut:

1. Finds your FM27 saves folder automatically.
2. Checks every save is fully downloaded (not cloud-only).
3. Shows the newest save and its timestamp, and asks you to confirm.
4. Backs up that save locally (outside OneDrive).
5. Pauses OneDrive and launches FM27 through Steam.
6. Waits for you to quit FM.
7. Backs up the save you just played.
8. Restarts OneDrive, which uploads the finished save in one go.
9. Waits until OneDrive confirms the upload has finished, then tells you it's safe to play on another PC.

## Requirements

- Windows, with the **Steam** version of FM27. Game Pass and Epic aren't supported without editing the config.
- FM27 saving to the default `Documents\Sports Interactive\Football Manager 27\games` folder.
- Your `Documents\Sports Interactive\Football Manager 27\games` folder set to **Always keep on this device** on every device you play on: OneDrive → Folder → Right-Click → Always keep on this device.
- **Steam Cloud turned off for FM27**: Steam → right-click FM27 → Properties → General.

## Setup

Do this on each PC:

1. **Take a manual copy of your saves first.**
2. Put both scripts in the same permanent folder. Inside OneDrive works well, e.g. `Documents\scripts\`, because it then syncs to your other PCs.
3. Open PowerShell in that folder and run:

   `New-FM27Shortcut.ps1`

   This creates an **FM27 (Synced)** desktop shortcut with the FM27 icon.
   
4. Delete or rename your normal Steam FM27 shortcut so you don't launch through it by habit.

If you move the scripts later, run the shortcut script again.

## Rules

- **Always launch from the FM27 (Synced) shortcut**, never directly from Steam or an old shortcut.
- **Never have FM open on two PCs at once.**
- **Leave the PowerShell window open while you play.** It restarts OneDrive when you quit. If it gets closed, OneDrive stays off until you start it or reboot.
- **After quitting, wait for "Upload complete"** before playing on another PC. If the window can't confirm the upload, it offers to open your saves folder so you can check for the green tick yourself.
- **If the newest save shown isn't the one you expect, answer N.** Wait for OneDrive to finish syncing, then try again.

## Recovery

**Local backups** are kept in `%USERPROFILE%\Saved Games\FM27 Cloud Saves`, named like:

20261104-210512 - post - DESKTOP-ABC123 - My Save.fm

- `pre` is the save as it was before a session.
- `post` is the save as it was right after a session, before OneDrive touched it.

To restore one, copy it into your FM27 `games` folder, remove everything before the save name, and load it in FM. The script only manages its own timestamped files, so anything else you put in that folder is left alone.

**OneDrive version history** keeps previous versions of each save for 30 days. Right-click the save in your `games` folder and choose **Version history**.

## Config

The settings are at the top of `FM27-Launch.ps1`:

| Setting | Default | Notes |
|---|---|---|
| `$SaveDir` | auto-detect | Set a full path if your saves are somewhere non-standard |
| `$BackupDir` | `Saved Games\FM27 Cloud Saves` | Keep this outside OneDrive |
| `$KeepBackups` | `6` | 2 per session (pre and post), so 6 covers the last 3 sessions |
| `$SteamAppId` | `4530370` | FM27's Steam ID |
| `$GameProcess` | `fm` | FM27's process name |
| `$SyncTimeoutMins` | `15` | How long to wait for the upload after you quit before giving up |

## Notes

- If your saves folder isn't in OneDrive, the launcher still takes backups but leaves OneDrive alone, and your saves won't sync.
- While FM is running, none of your other OneDrive files sync either. Everything catches up when you quit.
- Use at your own risk, and keep a manual copy of any save you care about.

Hopefully this helps someone else as it is certainly better than my experience with FM and Steam Cloud Saves!

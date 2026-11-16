# Unzip Latest Download

You just downloaded a zip and you're in the folder where it should go. Press **Ctrl+Shift+U** in
File Explorer and the newest `.zip` in your Downloads folder is unzipped right there. You don't
need to open the Downloads folder, right-click "Extract All" or browse to the destination.

## Install

1. Install [AutoHotkey v2](https://www.autohotkey.com/) (v2.0 or later).
2. Download [`UnzipLatestDownload.ahk`](UnzipLatestDownload.ahk) and put it anywhere you like.
3. Double-click it. The first time, a settings window opens:
   - **Downloads folder**: filled in with your Windows Downloads folder (including one you have
     moved). Change it if your browser saves somewhere else.
   - **Hotkey**: Ctrl+Shift+U unless you pick another.
   - **Unzip with**: [7-Zip](https://www.7-zip.org/) if it is installed, otherwise Windows' own
     zip support.
   - **Start automatically when I sign in to Windows**: tick this to keep it running.

The script then sits in the tray (the green **H** icon). Right-click that icon and choose
**Settings...** to change anything later.

## Use

1. Open the folder you want the files in, in File Explorer (or click the desktop).
2. Press **Ctrl+Shift+U**.

The newest zip in your Downloads folder is unzipped there, and the result is selected in
Explorer. 7-Zip (or Windows) shows its usual progress window for big zips.

The hotkey only works in File Explorer and on the desktop. In every other program, Ctrl+Shift+U
does whatever it normally does.

## Where the files go

| The zip holds | You get (the default, "Smart") |
| --- | --- |
| one folder, e.g. `project-main\...` | `project-main\` in the current folder |
| one file | that file in the current folder |
| several files and folders | a new folder named after the zip with everything inside |

Settings has two other choices: **always** a new folder named after the zip, or **always**
straight into the current folder.

Nothing already there is overwritten. If a name is taken, the new copy gets a number, the way
Windows names copies: `project-main (2)`, `notes (2).txt`.

## Which zip counts as the newest

The `.zip` in the Downloads folder with the most recent date, whether that's when it was
downloaded (created) or last modified. Zips still downloading in Firefox (a `.part` file next to
them) and empty zips are skipped. Chrome and Edge give a download its real name only once it is
finished, so a zip still downloading in those browsers isn't counted either.

## 7-Zip or Windows

If [7-Zip](https://www.7-zip.org/) is installed, it does the unzipping. It is faster and also
opens zips that Windows can't, such as password-protected ones (7-Zip asks for the password).
Without 7-Zip, Windows' built-in zip support is used, the same as "Extract All". The
notification after each unzip says which one was used.

7-Zip is found wherever it is installed (it is looked up in the registry). Installing or
removing it takes effect on the next unzip; there's nothing to restart. To always use Windows,
choose **Always Windows' built-in zip support** in Settings.

Either way, files from the internet stay marked as downloaded, so Windows still warns before
running them (for 7-Zip this needs version 22 or later).

## Good to know

- Zips are unzipped into a temporary `Unzipping <name>` folder first, which you may see briefly
  for big zips. The files are then moved into place.
- It works in a real folder, such as on your PC, a USB drive or a network share. It can't unzip
  into *This PC*, *Home*, a library, search results or the inside of another zip; it shows a
  notice instead.
- It reads only `.zip` files. 7z, rar and other formats are not supported.
- Settings are saved in `%APPDATA%\Unzip Latest Download\settings.ini`. Delete that file to see
  the first-run window again.
- Windows 10 and 11, including File Explorer tabs.

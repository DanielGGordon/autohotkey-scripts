; Unzip Latest Download
; ---------------------
; Press Ctrl+Shift+U in any File Explorer window (or on the desktop) and the newest .zip in your
; Downloads folder is unzipped into the folder you are looking at.
;
; AutoHotkey v2.0 or later. No other dependencies.
; Settings (Downloads folder, hotkey, where the files go) are in the tray icon's "Settings..." and
; are saved to %APPDATA%\Unzip Latest Download\settings.ini.
; https://github.com/DanielGGordon/autohotkey-scripts

#Requires AutoHotkey v2.0
#SingleInstance Force

App := {
    Name: "Unzip Latest Download",
    Ini: A_AppData "\Unzip Latest Download\settings.ini",
    DefaultHotkey: "^+u",          ; Ctrl+Shift+U
    StartupLink: A_Startup "\Unzip Latest Download.lnk",
}

; Current settings (loaded below).
global DownloadsFolder := ""
global ExtractMode := "auto"       ; auto | folder | here (see ShowSettings)
global CurrentHotkey := ""

Main()

Main() {
    global DownloadsFolder, ExtractMode
    DownloadsFolder := IniRead(App.Ini, "Settings", "DownloadsFolder", "")
    ExtractMode := IniRead(App.Ini, "Settings", "ExtractMode", "auto")
    if !(ExtractMode ~= "i)^(auto|folder|here)$")
        ExtractMode := "auto"

    hk := NormalizeHotkey(IniRead(App.Ini, "Settings", "Hotkey", App.DefaultHotkey))
    if !SetHotkey(hk)
        SetHotkey(App.DefaultHotkey)

    BuildTrayMenu()

    ; First run (or the saved folder is gone): ask where the downloads are.
    if DownloadsFolder = "" || !DirExist(DownloadsFolder)
        ShowSettings(true)
}

; ---------------------------------------------------------------------------------------------
; The hotkey
; ---------------------------------------------------------------------------------------------

; The hotkey is only active in File Explorer and on the desktop; everywhere else the key
; combination goes to the app as usual.
ExplorerIsActive(*) {
    return WinActive("ahk_class CabinetWClass") || WinActive("ahk_class ExploreWClass")
        || WinActive("ahk_class Progman") || WinActive("ahk_class WorkerW")
}

SetHotkey(hk) {
    global CurrentHotkey
    HotIf ExplorerIsActive
    try {
        Hotkey hk, UnzipLatestDownload, "On"
    } catch {
        HotIf
        return false
    }
    if CurrentHotkey != "" && CurrentHotkey != hk
        try Hotkey CurrentHotkey, "Off"
    HotIf
    CurrentHotkey := hk
    A_IconTip := App.Name " (" HotkeyText(hk) " in File Explorer)"
    return true
}

UnzipLatestDownload(*) {
    target := GetExplorerFolder()
    if !target {
        Notify("Can't unzip here", "Open a normal folder in File Explorer (not This PC, a library, "
            . "a search or the inside of a zip) and try again.", "Icon!")
        return
    }

    folder := DownloadsFolder != "" ? DownloadsFolder : DefaultDownloadsFolder()
    if !DirExist(folder) {
        MsgBox "The Downloads folder`n`n" folder "`n`ndoes not exist any more. Please choose it again.",
            App.Name, "Icon!"
        ShowSettings()
        return
    }

    zip := NewestZip(folder)
    if zip = "" {
        Notify("No zip files found", "There are no .zip files in " folder, "Iconi")
        return
    }

    SplitPath zip, &zipName
    try {
        result := ExtractZip(zip, target.path)
    } catch as err {
        MsgBox "Could not unzip`n`n" zip "`n`n" err.Message, App.Name, "Icon!"
        return
    }

    if target.view && result.select != ""
        SelectInExplorer(target.view, result.select)
    Notify("Unzipped " zipName, "into " result.dest, "Iconi")
}

; ---------------------------------------------------------------------------------------------
; Finding the folder, finding the zip, unzipping
; ---------------------------------------------------------------------------------------------

; The folder shown in the active File Explorer window (the active tab on Windows 11), or the
; desktop. Returns {path, view} or "" when the window shows no real folder (This PC, a library,
; search results, the inside of a zip, ...).
GetExplorerFolder() {
    static IID_IShellBrowser := "{000214E2-0000-0000-C000-000000000046}"
    hwnd := WinActive("A")
    if !hwnd
        return ""
    cls := WinGetClass(hwnd)
    if cls = "Progman" || cls = "WorkerW"
        return {path: A_Desktop, view: ""}
    if cls != "CabinetWClass" && cls != "ExploreWClass"
        return ""

    activeTab := 0
    try activeTab := ControlGetHwnd("ShellTabWindowClass1", hwnd)
    for window in ComObject("Shell.Application").Windows {
        try {
            if window.HWND != hwnd
                continue
            if activeTab {
                ; Windows 11 tabs: every tab is its own entry with the same HWND; keep the
                ; one whose tab window is the active one.
                browser := ComObjQuery(window, IID_IShellBrowser, IID_IShellBrowser)
                ComCall(3, browser, "Ptr*", &tab := 0)     ; IOleWindow::GetWindow
                if tab != activeTab
                    continue
            }
            path := window.Document.Folder.Self.Path
            return DirExist(path) ? {path: path, view: window} : ""
        }
    }
    return ""
}

; The newest .zip in the folder: the one with the latest creation or modification time (a
; download is created when it arrives, but a copied-in zip keeps its old creation date).
; Skips zips that are still downloading.
NewestZip(folder) {
    newest := "", newestTime := 0
    Loop Files folder "\*.zip", "F" {
        if A_LoopFileExt != "zip"                    ; "*.zip" also matches e.g. ".zipx" via 8.3 names
            continue
        if A_LoopFileSize = 0 || FileExist(A_LoopFileFullPath ".part")   ; Firefox still downloading
            continue
        t := Max(A_LoopFileTimeCreated, A_LoopFileTimeModified)
        if t > newestTime
            newest := A_LoopFileFullPath, newestTime := t
    }
    return newest
}

; Unzips with Windows' own zip support, so you get Explorer's progress window and files
; downloaded from the internet stay marked as such (Windows still warns before running them).
; The zip is first unzipped into a new "Unzipping <name>" folder and its contents are then moved
; into place, so nothing that is already there is ever overwritten: a name that is taken gets
; " (2)", " (3)", ... added.
; Returns {dest: folder the files went into, select: name to select in Explorer afterwards}.
ExtractZip(zipPath, destFolder) {
    shell := ComObject("Shell.Application")
    zipNs := shell.NameSpace(zipPath)
    if !IsObject(zipNs)
        throw Error("Windows could not open it as a zip file. It may be damaged or not a real zip.")
    items := zipNs.Items()
    if items.Count = 0
        throw Error("The zip file is empty.")

    SplitPath zipPath, , , , &baseName
    temp := UniquePath(destFolder, "Unzipping " baseName, true)
    DirCreate temp
    tempNs := shell.NameSpace(temp)
    if !IsObject(tempNs)
        throw Error("Windows could not open the folder " temp)
    tempNs.CopyHere(items, 0)        ; returns when the unzipping is done

    if ExtractMode = "folder" || (ExtractMode = "auto" && items.Count > 1) {
        ; Into a new folder named after the zip, so loose files don't spill everywhere.
        dest := UniquePath(destFolder, baseName, true)
        DirMove temp, dest
        return {dest: dest, select: LeafName(dest)}
    }

    ; Straight into the current folder. A zip that holds one folder (the usual case) ends up
    ; as that one folder.
    found := []
    Loop Files temp "\*", "FD"
        found.Push({path: A_LoopFileFullPath, name: A_LoopFileName, isDir: InStr(A_LoopFileAttrib, "D")})
    moved := []
    for f in found {
        target := UniquePath(destFolder, f.name, f.isDir)
        if f.isDir
            DirMove f.path, target
        else
            FileMove f.path, target
        moved.Push(LeafName(target))
    }
    try DirDelete temp               ; only if empty
    if moved.Length = 0
        throw Error("Nothing was unzipped.")
    return {dest: destFolder, select: moved.Length = 1 ? moved[1] : ""}
}

; folder\name, or "name (2)", "name (3)", ... if that is taken. For a file the number goes
; before the extension: "notes (2).txt".
UniquePath(folder, name, isDir) {
    folder := RTrim(folder, "\")
    stem := name, ext := ""
    if !isDir {
        SplitPath name, , , &ext, &stem
        if ext != ""
            ext := "." ext
    }
    path := folder "\" name, n := 1
    while FileExist(path) {
        n += 1
        path := folder "\" stem " (" n ")" ext
    }
    return path
}

LeafName(path) {
    SplitPath RTrim(path, "\"), &leaf
    return leaf
}

; Selects (and scrolls to) the unzipped item in the Explorer window.
SelectInExplorer(view, name) {
    loop 20 {
        try {
            item := view.Document.Folder.ParseName(name)
            if IsObject(item) {
                view.Document.SelectItem(item, 1 | 4 | 8 | 16)   ; select, deselect others, show, focus
                return
            }
        }
        Sleep 100
    }
}

; ---------------------------------------------------------------------------------------------
; Settings
; ---------------------------------------------------------------------------------------------

; Where Windows keeps the Downloads folder (it can be moved in its Properties > Location).
DefaultDownloadsFolder() {
    static FOLDERID_Downloads := "{374DE290-123F-4565-9164-39C4925E467B}"
    guid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "WStr", FOLDERID_Downloads, "Ptr", guid)
    if DllCall("shell32\SHGetKnownFolderPath", "Ptr", guid, "UInt", 0, "Ptr", 0, "Ptr*", &pPath := 0) = 0 {
        path := StrGet(pPath, "UTF-16")
        DllCall("ole32\CoTaskMemFree", "Ptr", pPath)
        if DirExist(path)
            return path
    }
    return EnvGet("USERPROFILE") "\Downloads"
}

ShowSettings(firstRun := false) {
    static g := ""
    if g {
        g.Show()
        return
    }

    modes := ["auto", "folder", "here"]
    g := Gui(, App.Name " - Settings")
    g.SetFont("s10", "Segoe UI")
    g.MarginX := 16, g.MarginY := 14

    intro := firstRun ? "Welcome! " : ""
    g.AddText("w470", intro "In File Explorer, press the hotkey below and the newest .zip in your "
        . "Downloads folder is unzipped into the folder you are looking at.")

    g.AddText("xm y+16", "Downloads folder (where to look for zips):")
    edFolder := g.AddEdit("xm w380 r1", DownloadsFolder != "" ? DownloadsFolder : DefaultDownloadsFolder())
    g.AddButton("x+8 yp-1 w82", "Browse...").OnEvent("Click", Browse)
    g.AddLink("xm y+6", '<a id="reset">Use the Windows Downloads folder</a>').OnEvent("Click", Reset)

    g.AddText("xm y+16", "Hotkey (works in File Explorer and on the desktop):")
    hk := g.AddHotkey("xm w200", CurrentHotkey)

    g.AddText("xm y+16", "Where the unzipped files go:")
    dd := g.AddDropDownList("xm w470", [
        "Smart: a new folder only if the zip has loose files (recommended)",
        "Always into a new folder named after the zip",
        "Always straight into the current folder",
    ])
    dd.Value := Max(1, IndexOf(modes, ExtractMode))

    cb := g.AddCheckbox("xm y+16", "Start automatically when I sign in to Windows")
    cb.Value := FileExist(App.StartupLink) ? 1 : 0

    g.AddButton("xm+290 y+20 w80 Default", "OK").OnEvent("Click", Save)
    g.AddButton("x+10 w80", "Cancel").OnEvent("Click", Close)
    g.OnEvent("Close", Close)
    g.OnEvent("Escape", Close)
    g.Show()

    Browse(*) {
        g.Opt("+OwnDialogs")
        start := DirExist(edFolder.Value) ? edFolder.Value : DefaultDownloadsFolder()
        picked := DirSelect("*" start, 1, "Choose the folder your browser downloads to")
        if picked != ""
            edFolder.Value := picked
    }

    Reset(*) => edFolder.Value := DefaultDownloadsFolder()

    Save(*) {
        global DownloadsFolder, ExtractMode
        g.Opt("+OwnDialogs")
        folder := Trim(edFolder.Value)
        if folder ~= "\\$" && StrLen(folder) > 3
            folder := RTrim(folder, "\")
        if folder = "" || !DirExist(folder) {
            MsgBox "That folder does not exist:`n`n" folder, App.Name, "Icon!"
            return
        }
        newHotkey := NormalizeHotkey(hk.Value)
        if newHotkey = "" {
            MsgBox "Please choose a hotkey.", App.Name, "Icon!"
            return
        }
        if newHotkey != CurrentHotkey && !SetHotkey(newHotkey) {
            MsgBox "That hotkey can't be used. Please choose another.", App.Name, "Icon!"
            return
        }

        DownloadsFolder := folder
        ExtractMode := modes[dd.Value]
        DirCreate RegExReplace(App.Ini, "\\[^\\]+$")
        IniWrite DownloadsFolder, App.Ini, "Settings", "DownloadsFolder"
        IniWrite CurrentHotkey, App.Ini, "Settings", "Hotkey"
        IniWrite ExtractMode, App.Ini, "Settings", "ExtractMode"

        if cb.Value
            CreateStartupLink()
        else if FileExist(App.StartupLink)
            FileDelete App.StartupLink

        wasFirstRun := firstRun
        g.Destroy(), g := ""
        if wasFirstRun
            Notify(App.Name " is running", "In File Explorer, press " HotkeyText(CurrentHotkey)
                . " to unzip your newest download there.", "Iconi")
    }

    Close(*) {
        ; Closing the first-run window without saving: use the Windows Downloads folder for now
        ; and ask again next time.
        g.Destroy(), g := ""
    }
}

CreateStartupLink() {
    if A_IsCompiled
        FileCreateShortcut A_ScriptFullPath, App.StartupLink, A_ScriptDir, , App.Name
    else
        FileCreateShortcut A_AhkPath, App.StartupLink, A_ScriptDir, '"' A_ScriptFullPath '"', App.Name
}

BuildTrayMenu() {
    tray := A_TrayMenu
    tray.Insert("1&", "Settings...", (*) => ShowSettings())
    tray.Insert("2&", "Open Downloads folder", OpenDownloads)
    tray.Insert("3&")
    tray.Default := "Settings..."

    OpenDownloads(*) {
        folder := DownloadsFolder != "" ? DownloadsFolder : DefaultDownloadsFolder()
        if DirExist(folder)
            Run folder
    }
}

; ---------------------------------------------------------------------------------------------
; Helpers
; ---------------------------------------------------------------------------------------------

Notify(title, text, icon := "Iconi") {
    TrayTip text, title, icon " Mute"
}

; "+^u" -> "^+u": modifiers always in the same order, so one key combination has one name.
NormalizeHotkey(hk) {
    mods := ""
    while StrLen(hk) > 1 && InStr("^+!#", SubStr(hk, 1, 1))
        mods .= SubStr(hk, 1, 1), hk := SubStr(hk, 2)
    out := ""
    for m in ["^", "+", "!", "#"]
        if InStr(mods, m)
            out .= m
    return out StrLower(hk)
}

; "^+u" -> "Ctrl+Shift+U"
HotkeyText(hk) {
    names := Map("^", "Ctrl+", "+", "Shift+", "!", "Alt+", "#", "Win+")
    out := ""
    while StrLen(hk) > 1 && names.Has(SubStr(hk, 1, 1)) {
        out .= names[SubStr(hk, 1, 1)]
        hk := SubStr(hk, 2)
    }
    return out StrUpper(hk)
}

IndexOf(arr, value) {
    for i, v in arr
        if v = value
            return i
    return 0
}

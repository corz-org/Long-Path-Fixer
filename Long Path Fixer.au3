global $app_version = "1.0.0.0"
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0

#cs

Long Path Fixer
from corz.org

https://corz.org/windows/software/accessories/Long-Path-Fixer-for-Windows.php

#ce

#include <Date.au3>
#include <GuiListBox.au3>
#include <Misc.au3>
#include <SendMessage.au3>
#include <String.au3>
#include <Timers.au3>
#include <TrayConstants.au3>
#include "Includes/LFN.au3"

; $app_name and $ini_path are declared global in Includes/corzShared.au3
$app_name = "Long Path Fixer"
global $win_title = $app_name
global $ini_filename = $app_name & ".ini"
global $app_url = "https://corz.org/windows/software/accessories/Long-Path-Fixer-for-Windows.php"
global $download_url = $app_url & "#section-Download"
global $version_check_url = "https://corz.org/inc/versions.php?app=LongPathFixer"

global const $EXPLORER_MENU_NAME = $app_name & ".."
global const $MSG_RENAME_FAILED = "Rename Failed!"
global const $MSG_DELETE_FAILED = "Delete Failed!"

; Parent folder marker shown at the top of the file list:
; Simply two U+25CF black circles: ●● which we click to go UP.
global const $PARENT_MARK = ChrW(9679) & ChrW(9679)

; Button styles for ShowAppMsg, the position-remembering message window.
global const $APP_MSG_OK = 0
global const $APP_MSG_YESNO = 1
; Longest path shown on the progress header line before middle truncation.
global const $PROGRESS_PATH_CHARS = 65

global $temp_dir = @TempDir & "\Long Path Fixer"
global $recycle_mirror = $temp_dir & "\recycle_mirror"
global $cmdline_arg1, $cmdline_arg2, $cmdline_arg3, $current_dir
global $win_x, $win_y, $win_width, $win_height, $min_width, $min_width_pad, $min_height, $min_height_pad
global $show_tips, $reserved_pref, $beep_pref, $taskbar_entry, $always_on_top, $explorer_context
global $tray_item_ontop, $tray_item_explorer_ctx, $tray_item_edit_ini, $tray_item_about, $fade_in_pref
global $hover_last_tick = 0, $window_visible, $hover_to_show, $hover_sensitivity
global $recycle_bin_pref, $tray_item_recycle_bin, $confirm_delete_pref, $tray_item_confirm_delete
global $single_click_pref, $tray_item_single_click
global $ctx_item_single_click
global $combo_ctrl
global $last_path, $unlocker_path, $unlocker_switches
global $dialog_font
global $list_ctrl, $context_menu
global $progress_window, $progress_bar, $progress_file_label, $progress_cancel_button
global $progress_old_event_mode, $progress_old_coord_mode

global $parent_GUI
global $lpf_GUI
global $exe_path, $ini_in_script_dir, $ini_dir, $ini_installed

AutoItSetOption("GUIOnEventMode", true)
AutoItSetOption("GUICoordMode", false)
AutoItSetOption("TrayMenuMode", 5)
AutoItSetOption("TrayOnEventMode", true)
HotKeySet("{Esc}", "OnHotkeyEsc")
TraySetOnEvent($TRAY_EVENT_PRIMARYDOWN, "OnMinimizeOrTrayClick")


if @Compiled then
  $exe_path = @ScriptFullPath
else
  $exe_path = ".\" & $app_name & ".exe"
endif

if $CMDLINE[0] then
  if $CMDLINE[0] > 1 then
    $cmdline_arg1 = StringStripWS($CMDLINE[1], $STR_STRIP_ENDS)
  endif
  if __LFN_Target_IsExistingFolder($CMDLINE[$CMDLINE[0]]) then
    $current_dir = StringStripWS($CMDLINE[$CMDLINE[0]], $STR_STRIP_ENDS)
  else
    $current_dir = StringStripWS(GetLongParent($CMDLINE[$CMDLINE[0]]), $STR_STRIP_ENDS)
  endif
endif

if FileExists(@ScriptDir & "\" & $ini_filename) then
  $ini_in_script_dir = true
  $ini_dir = @ScriptDir
  $ini_path = $ini_dir & "\" & $ini_filename
else
  $ini_dir = @AppDataDir & "\corz\" & $app_name
  if not FileExists($ini_dir) then DirCreate($ini_dir)
  $ini_path = $ini_dir & "\" & $ini_filename
endif

if not FileExists($ini_path) then $ini_installed = FileInstall("Resources\Long Path Fixer.ini", $ini_path)
CheckForUpgradeINI()

GetPrefs()
CreateTrayMenu()
CreateMainGui()
ApplyAlwaysOnTop()
RegisterHotkeys()
TraySetOnEvent($TRAY_EVENT_MOUSEOVER, "OnTrayHoverActivate")


; Idle arround..
while true
  Sleep(25)
wend

SaveAndExit(0)


; Fin!




func GetPrefs()
  $win_x = IniRead($ini_path, $app_name, "x", -1)
  $win_y = IniRead($ini_path, $app_name, "y", -1)
  $win_width = IniRead($ini_path, $app_name, "width", 800)
  $win_height = IniRead($ini_path, $app_name, "height", 500)
  $min_width = IniRead($ini_path, $app_name, "min_width", 240)
  $min_width_pad = 8
  $min_height = IniRead($ini_path, $app_name, "min_height", 196)
  $min_height_pad = 27
  $show_tips = IniReadCheckBoxValue($ini_path, $app_name, "show_tips", $GUI_CHECKED)
  $taskbar_entry = IniReadCheckBoxValue($ini_path, $app_name, "taskbar_entry", $GUI_CHECKED)
  $always_on_top = IniReadCheckBoxValue($ini_path, $app_name, "always_on_top", $GUI_UNCHECKED)
  $beep_pref = IniReadCheckBoxValue($ini_path, $app_name, "beep", $GUI_CHECKED)
  $hover_to_show = IniReadCheckBoxValue($ini_path, $app_name, "hover_to_show", $GUI_CHECKED)
  $hover_sensitivity = Abs(Int(IniRead($ini_path, $app_name, "hover_sensitivity", 8)))
  $fade_in_pref = IniReadCheckBoxValue($ini_path, $app_name, "fade_in", $GUI_CHECKED)
  $dialog_font = ReadFontPrefs("dialog_font", $DIALOG_FONT_DEFAULT)
  $last_path = IniRead($ini_path, $app_name, "last_path", "")
  if not $current_dir and $last_path <> "" then
    if _LFN_FileExists($last_path) then
      $current_dir = $last_path
    else
      local $location_drive = ""
      if StringMid($last_path, 2, 1) = ":" then $location_drive = StringUpper(StringLeft($last_path, 2)) & "\"
      if $location_drive <> "" and FileExists($location_drive) then $current_dir = $location_drive
    endif
  endif
  if $current_dir = "" then
    $current_dir = @HomeDrive & "\"
  else
    if StringMid($current_dir, 2, 1) = ":" and DriveStatus(StringLeft($current_dir, 2)) <> "READY" then $current_dir = @HomeDrive & "\"
  endif
  $unlocker_path = IniRead($ini_path, $app_name, "unlocker_path", "C:\Program Files\LockHunter\LockHunter.exe")
  $unlocker_switches = IniRead($ini_path, $app_name, "unlocker_switches", "-u -sm -x")
  $unlocker_switches &= " "
  $recycle_bin_pref = IniReadCheckBoxValue($ini_path, $app_name, "delete_to_recycle_bin", $GUI_UNCHECKED)
  $confirm_delete_pref = IniReadCheckBoxValue($ini_path, $app_name, "confirm_delete", $GUI_CHECKED)
  $single_click_pref = IniReadCheckBoxValue($ini_path, $app_name, "single_click", $GUI_UNCHECKED)
  $debug_level = IniReadCheckBoxValue($ini_path, $app_name, "debug_level", $GUI_UNCHECKED)
  $explorer_context = IniReadCheckBoxValue($ini_path, $app_name, "explorer_context", $GUI_CHECKED)
  ApplyExplorerContextMenu()
endfunc


func CreateTrayMenu()
  $tray_item_edit_ini = TrayCreateItem("Edit ini file (prefs)")
  TrayItemSetOnEvent(-1, "lpf_EditINIFile")
  TrayCreateItem("")
  $tray_item_ontop = TrayCreateItem("Always On Top")
  TrayItemSetState(-1, $always_on_top)
  TrayItemSetOnEvent(-1, "OnToggleAlwaysOnTop")
  $tray_item_explorer_ctx = TrayCreateItem("Keep in Explorer Context Menu")
  TrayItemSetState(-1, $explorer_context)
  TrayItemSetOnEvent(-1, "OnToggleExplorerContext")
  TrayCreateItem("")
  $tray_item_recycle_bin = TrayCreateItem("Always delete to Recycle Bin")
  TrayItemSetState(-1, $recycle_bin_pref)
  TrayItemSetOnEvent(-1, "OnToggleRecycleBinPref")
  $tray_item_confirm_delete = TrayCreateItem("Confirm Deletions")
  TrayItemSetState(-1, $confirm_delete_pref)
  TrayItemSetOnEvent(-1, "OnToggleConfirmDeletePref")
  $tray_item_single_click = TrayCreateItem("Single-Click Operation")
  TrayItemSetState(-1, $single_click_pref)
  TrayItemSetOnEvent(-1, "OnToggleSingleClick")
  TrayCreateItem("")
  $tray_item_about = TrayCreateItem("About " & $app_name)
  TrayItemSetOnEvent(-1, "ShowAboutDialog")
  TrayCreateItem("")
  TrayCreateItem("Exit")
  TrayItemSetOnEvent(-1, "OnTrayExit")
  TraySetClick($TRAY_CLICK_SECONDARYDOWN)
  TraySetState($TRAY_ICONSTATE_SHOW)
  TraySetIcon($exe_path, 0)
endfunc



; Create the main window.
func CreateMainGui()

  local $font_name = "Segeo UI"

  if StringInStr(@OSType, "XP") or StringInStr(@OSType, "2003") then
    $font_name = "Tahoma"
  endif

  if $taskbar_entry = $GUI_CHECKED then
    $lpf_GUI = GUICreate($win_title, $win_width, $win_height, $win_x, $win_y, BitOR($WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX, $WS_SIZEBOX), $WS_EX_ACCEPTFILES)
  else
    $parent_GUI = GUICreate("", -1, -1, 0, 0, 0, BitOR($WS_EX_ACCEPTFILES, $WS_EX_TOOLWINDOW))
    $lpf_GUI = GUICreate($win_title, $win_width, $win_height, $win_x, $win_y, BitOR($WS_CAPTION, $WS_POPUP, $WS_SYSMENU, $WS_MINIMIZEBOX, $WS_SIZEBOX), -1, $parent_GUI)
  endif

  GUISetIcon($exe_path, 0, $lpf_GUI)
  GUISetFont(10, $FW_NORMAL, default, $font_name, $lpf_GUI)
  GUIRegisterMsg($WM_COMMAND, "OnWmCommand")
  GUIRegisterMsg($WM_CONTEXTMENU, "OnContextMenu")
  GUISetOnEvent($GUI_EVENT_CLOSE, "OnClose")
  GUISetOnEvent($GUI_EVENT_DROPPED, "OnDragDrop")
  GUISetOnEvent($GUI_EVENT_RESIZED, "OnResized")
  GUISetOnEvent($GUI_EVENT_PRIMARYUP, "OnPrimaryUp")
  GUISetOnEvent($GUI_EVENT_MINIMIZE, "OnMinimizeOrTrayClick")
  $combo_ctrl = GUICtrlCreateCombo("", 10, 10, $win_width - 20, 23, -1, $WS_EX_ACCEPTFILES)
  GUICtrlSetResizing(-1, $GUI_DOCKTOP + $GUI_DOCKLEFT + $GUI_DOCKHEIGHT + $GUI_DOCKRIGHT)
  GUICtrlSetOnEvent(-1, "OnComboChange")
  GUICtrlSetState(-1, $GUI_DROPACCEPTED)
  GUICtrlSetTip(-1, " select a drive from this drop-down lost (or drag and drop a folder onto the list itself). ")
  local $drives = DriveGetDrive("all")

  for $i = 1 to $drives[0]
    GUICtrlSetData($combo_ctrl, StringUpper($drives[$i]) & "\")
  next

  ; Show the current drive as the combo selection
  if $current_dir <> "" then
    local $current_drive = $current_dir
    if StringMid($current_drive, 2, 1) = ":" then $current_drive = StringUpper(StringLeft($current_drive, 2)) & "\"
    ControlCommand($lpf_GUI, "", $combo_ctrl, "SelectString", $current_drive)
  endif

  GUISetCoord(0, 0)
  $list_ctrl = GUICtrlCreateList("", 10, 40, $win_width - 20, $win_height - 85, BitOR($LBS_NOTIFY, $WS_VSCROLL), $WS_EX_ACCEPTFILES)
  GUICtrlSetResizing(-1, $GUI_DOCKTOP + $GUI_DOCKLEFT + $GUI_DOCKRIGHT + $GUI_DOCKBOTTOM)
  GUICtrlSetState(-1, $GUI_DROPACCEPTED)
  GUICtrlSetTip(-1, " This is the list of files and folders in the current directory. You can drag stuff into here. ")
  CreateListContextMenu()
  GUISetCoord(0, 0)
  GUICtrlCreateButton("Move", 10, $win_height - 40, ($win_width / 3) - 12, 35)
  GUICtrlSetOnEvent(-1, "Moveselected")
  GUICtrlSetResizing(-1, $GUI_DOCKBOTTOM + $GUI_DOCKLEFT + $GUI_DOCKHEIGHT)
  GUICtrlSetTip(-1, " Click this to move the currently selected file or folder. ")
  GUICtrlCreateButton("Copy", ($win_width / 3) - 5, 0, ($win_width / 3) - 12, 35)
  GUICtrlSetOnEvent(-1, "Copyselected")
  GUICtrlSetResizing(-1, $GUI_DOCKBOTTOM + $GUI_DOCKHEIGHT)
  GUICtrlSetTip(-1, " Click this to move the currently selected file or folder. ")
  GUICtrlCreateButton("Delete", ($win_width / 3), 0, ($win_width / 3) - 12, 35)
  GUICtrlSetOnEvent(-1, "Deleteselected")
  GUICtrlSetResizing(-1, $GUI_DOCKBOTTOM + $GUI_DOCKRIGHT + $GUI_DOCKHEIGHT)
  GUICtrlSetTip(-1, " Click this to delete the currently selected file or folder. ")
  EnforceWindowBounds()
  RefreshFileList()
  if $fade_in_pref = $GUI_CHECKED then
    FadeInWindow($lpf_GUI)
  else
    GUISetState()
  endif
  $window_visible = true
endfunc



; Right-click menu for the main list.
func CreateListContextMenu()
  $context_menu = GUICtrlCreateContextMenu($list_ctrl)
  GUICtrlCreateMenuItem("Refresh", $context_menu)
  GUICtrlSetOnEvent(-1, "OnHotkeyF5")
  GUICtrlCreateMenuItem("", $context_menu)
  GUICtrlCreateMenuItem("Shell Open", $context_menu)
  GUICtrlSetOnEvent(-1, "ShellOpenselected")
  GUICtrlCreateMenuItem("", $context_menu)
  GUICtrlCreateMenuItem("Move", $context_menu)
  GUICtrlSetOnEvent(-1, "Moveselected")
  GUICtrlCreateMenuItem("Copy", $context_menu)
  GUICtrlSetOnEvent(-1, "Copyselected")
  GUICtrlCreateMenuItem("Rename", $context_menu)
  GUICtrlSetOnEvent(-1, "Renameselected")
  GUICtrlCreateMenuItem("", $context_menu)
  $ctx_item_single_click = GUICtrlCreateMenuItem("Single-Click Operation", $context_menu)
  GUICtrlSetState(-1, $single_click_pref)
  GUICtrlSetOnEvent(-1, "OnToggleSingleClick")
  GUICtrlCreateMenuItem("", $context_menu)
  GUICtrlCreateMenuItem("Delete", $context_menu)
  GUICtrlSetOnEvent(-1, "Deleteselected")
  if $recycle_bin_pref = $GUI_UNCHECKED then
    GUICtrlCreateMenuItem("Delete to Recycle Bin", $context_menu)
    GUICtrlSetOnEvent(-1, "DeleteselectedToRecycleBin")
  endif
  GUICtrlCreateMenuItem("", $context_menu)
  GUICtrlCreateMenuItem("Unlock", $context_menu)
  GUICtrlSetOnEvent(-1, "Unlockselected")
  GUICtrlCreateMenuItem("", $context_menu)
  GUICtrlCreateMenuItem("Copy Path", $context_menu)
  GUICtrlSetOnEvent(-1, "CopyLongPathToClipboard")
  GUICtrlCreateMenuItem("Copy Short (8.3) Path", $context_menu)
  GUICtrlSetOnEvent(-1, "CopyShortPathToClipboard")
endfunc

; User selects a new drive
func OnComboChange()
  $current_dir = GUICtrlRead($combo_ctrl)
  if StringRight($current_dir, 1) = "\" and StringLen($current_dir) > 3 then $current_dir = StringTrimRight($current_dir, 1)
  RefreshFileList()
endfunc


; Reads typed text from the drive combo when Enter is pressed inside it
; and opens the list at that folder. Reads $combo_ctrl text and the
; focused control, writes $current_dir on success, returns nothing.
; Enter pressed anywhere else passes through untouched via SetHotKey.
func OnComboEnter()
  if not WinActive($lpf_GUI) then
    SetHotKey("{ENTER}", "OnComboEnter")
    return
  endif
  if StringLeft(ControlGetFocus($lpf_GUI), 4) <> "Edit" then
    SetHotKey("{ENTER}", "OnComboEnter")
    return
  endif
  local $typed_path = StringStripWS(GUICtrlRead($combo_ctrl), $STR_STRIP_ENDS)
  if StringLen($typed_path) > 1 and StringLeft($typed_path, 1) = '"' and StringRight($typed_path, 1) = '"' then $typed_path = StringMid($typed_path, 2, StringLen($typed_path) - 2)
  if $typed_path = "" then return
  if StringRight($typed_path, 1) = "\" and StringLen($typed_path) > 3 then $typed_path = StringTrimRight($typed_path, 1)
  if StringMid($typed_path, 2, 1) = ":" and StringLen($typed_path) = 2 then $typed_path &= "\"
  if not __LFN_Target_IsExistingFolder($typed_path) then
    ShowAppMsg("Folder not found!", "I cannot find this folder: " & @LF & $typed_path, $APP_MSG_OK, 0)
    return
  endif
  $current_dir = $typed_path
  RefreshFileList()
endfunc


func OnDragDrop()
  local $dropped_path = false
  if @GUI_DragId = -1 then
    local $drag_file = @GUI_DragFile
    if not _IsPressed("11") and GetExtension($drag_file) = "lnk" then
      local $shortcut_info = FileGetShortcut($drag_file)
      $drag_file = $shortcut_info[0]
    endif
    if StringInStr(FileGetAttrib($drag_file), "D") then
      $dropped_path = $drag_file
    else
      $dropped_path = GetLongParent($drag_file)
    endif
    if $dropped_path then
      $current_dir = $dropped_path
      RefreshFileList()
    endif
  endif
endfunc


; TEMP-DIAG: trace every listing to diagnose short-list reports. Remove after.


func RefreshFileList()
  _GUICtrlListBox_ResetContent($list_ctrl)
  _GUICtrlListBox_AddString($list_ctrl, $PARENT_MARK)
  if StringMid($current_dir, 2, 1) = ":" and StringLen($current_dir) = 2 then $current_dir &= "\"
  while StringInStr($current_dir, "\\", 0, 1, 3)
    $current_dir = StringLeft($current_dir, 2) & StringReplace(StringTrimLeft($current_dir, 2), "\\", "\")
  wend
  local $found_paths = __LFN_FilesListToArray($current_dir & "\*.*")
  local $display_name
  for $i = 1 to $found_paths[0]
    $display_name = GetPathLeaf($found_paths[$i])
    if __LFN_Target_IsExistingFolder($current_dir & "\" & $display_name) then $display_name &= "\"
    _GUICtrlListBox_AddString($list_ctrl, $display_name)
  next
  ControlSetText($lpf_GUI, "", $combo_ctrl, $current_dir)
endfunc


func ShellOpenselected()
  local $selected_name = GetselectedItemName()
  if $selected_name = "" then return
  ShellExecute($current_dir & "\" & $selected_name)
endfunc


func Unlockselected()
  local $selected_name = GetselectedItemName()
  if $selected_name = "" then return
  if not FileExists($unlocker_path) then
    local $chosen_exe = FileOpenDialog("Please locate LockHunter", "C:\Program Files", "LockHunter (LockHunter.exe)", $FD_FILEMUSTEXIST, "LockHunter.exe", $lpf_GUI)
    if FileExists($chosen_exe) then
      $unlocker_path = $chosen_exe
      IniWrite($ini_path, $app_name, "unlocker_path", $unlocker_path)
    else
      ShowAppMsg("Couldn't Run LockHunter!", "Couldn't Run LockHunter! ", $APP_MSG_OK, 0)
      return
    endif
  endif
  if not FileExists($unlocker_path) then
    ShellExecute("http://www.lockhunter.com/index.htm")
    return
  else
    local $target_path = $current_dir & "\" & $selected_name
    if StringLen($target_path) >= $MAX_PATH_LEN - 1 then
      $target_path = _LFN_FileGetShortName(GetLongParent($current_dir)) & "\" & GetPathLeaf($current_dir) & "\" & $selected_name
    endif
    if StringLen($target_path) >= $MAX_PATH_LEN - 1 then
      $target_path = _LFN_FileGetShortName($current_dir) & "\" & $selected_name
    endif
    if StringLen($target_path) >= $MAX_PATH_LEN - 1 then
      $target_path = _LFN_FileGetShortName($current_dir & "\" & $selected_name)
    endif
    local $exit_code = ShellExecuteWait($unlocker_path, $unlocker_switches & '"' & $target_path & '"', $current_dir, "")
    if $exit_code = 0 then
      ShowAppMsg("Unlocked!", $current_dir & "\" & $selected_name & " has been unlocked! ", $APP_MSG_OK, 30)
    else
      ShowAppMsg("LockHunter Error!", "LockHunter exited with a non-zero status!! ", $APP_MSG_OK, 30)
    endif
  endif
endfunc


func CopyLongPathToClipboard()
  local $selected_name = GetselectedItemName()
  if $selected_name = "" then return
  local $long_path = _LFN_FileGetLongName($current_dir & "\" & $selected_name)
  if not $long_path then
    ShowAppMsg("Copy Failed!", "Could not resolve the full path of: " & @LF & @LF & $current_dir & "\" & $selected_name, $APP_MSG_OK, 0)
    return
  endif
  ClipPut($long_path)
endfunc


func CopyShortPathToClipboard()
  local $selected_name = GetselectedItemName()
  if $selected_name = "" then return
  local $short_path = _LFN_FileGetShortName($current_dir & "\" & $selected_name)
  if not $short_path then
    ShowAppMsg("Copy Failed!", "Could not resolve the short path of: " & @LF & @LF & $current_dir & "\" & $selected_name, $APP_MSG_OK, 0)
    return
  endif
  ClipPut($short_path)
endfunc


func Deleteselected()
  DeleteSelectedItem()
endfunc


func DeleteselectedToRecycleBin()
  $recycle_bin_pref = $GUI_CHECKED
  DeleteSelectedItem()
  $recycle_bin_pref = $GUI_UNCHECKED
endfunc


func Moveselected()
  MoveOrCopySelectedItem("move")
endfunc


func Copyselected()
  MoveOrCopySelectedItem("copy")
endfunc


func Renameselected()
  RenameSelectedItem()
endfunc


; Reads the selected list item and resolves its full path and kind.
; Reads the list selection and $current_dir. Writes the folder or
; file kind into $item_kind, which the caller declares first, and
; returns the full target path or "" when there is nothing to act on.
func GetSelectedTarget(byref $item_kind)
  local $selected_name = GetselectedItemName()
  if $selected_name = "" then return ""
  if StringRight($selected_name, 1) = "\" then $selected_name = StringTrimRight($selected_name, 1)
  local $target = $current_dir & "\" & $selected_name
  if not _LFN_FileExists($target) then return ""
  if __LFN_Target_IsExistingFolder($target) then
    $item_kind = "directory"
  else
    $item_kind = "file"
  endif
  return $target
endfunc


; Renames the selected file or folder after asking for a new name.
; Reads the selection, writes the renamed path, refreshes the list,
; returns nothing. Called from the Rename button and menu item.
func RenameSelectedItem()
  local $item_kind = ""
  local $target = GetSelectedTarget($item_kind)
  if $target = "" then return
  local $old_name = GetPathLeaf($target)
  SuspendMainWindow()
  local $new_name = RenameInput($old_name, $item_kind)
  ResumeMainWindow()
  if not $new_name or $new_name = $old_name then return
  local $ok = false
  if __LFN_Target_IsExistingFolder($target) then
    $ok = _LFN_DirMove($target, GetLongParent($target) & "\" & $new_name)
  else
    $ok = _LFN_FileMove($target, GetLongParent($target) & "\" & $new_name)
  endif
  RefreshFileList()
  if not $ok then ShowAppMsg($MSG_RENAME_FAILED, $MSG_RENAME_FAILED & @LF & @LF & _
                      "Possibly you don't have the correct permissions to Rename this " & $item_kind & ". ", $APP_MSG_OK, 0)
endfunc




; Custom rename input that selects only the file name parts..
func RenameInput($source_filename, $rename_type)

	local $dot_index = StringInStr($source_filename, ".", 0, -1)
	local $base_name = $source_filename

  local $old_event_mode = AutoItSetOption("GUIOnEventMode", 0)
  local $old_coord_mode = AutoItSetOption("GUICoordMode", 0)
  local $rename_width = 300 + (3.7 * StringLen($source_filename))

	if $dot_index > 1 then
		$base_name = StringLeft($source_filename, $dot_index - 1)
	endif

  SuspendMainWindow()
	local $rename_pos = GetDialogPos("rename")
	local $dialog_window = GUICreate("Rename this " & $rename_type, $rename_width, 65, $rename_pos[0], $rename_pos[1])

  GuiSetCoord(5, 5)
	local $name_input = GUICtrlCreateInput($source_filename, 0, 0, $rename_width-10, 22)
  
  GuiSetCoord($rename_width - 170, 32)
	local $cancel_button = GUICtrlCreateButton("Cancel", 0, 0, 80, 28)
	local $ok_button = GUICtrlCreateButton("OK", 85, 0, 80, 28)

	GUISetState(@SW_SHOW, $dialog_window)

	; Select characters 0 through the length of the base name (excludes the dot and extension)
	GUICtrlSendMsg($name_input, $EM_SETSEL, 0, StringLen($base_name))

	local $result = ""

	while true
		local $ui_message = GUIGetMsg()
		switch $ui_message
			case $GUI_EVENT_CLOSE, $cancel_button
				exitloop
			case $ok_button
				local $entered_text = GUICtrlRead($name_input)
				if $entered_text <> "" Then
					$result = $entered_text
					exitloop
				endif
		endswitch
	wend

	SaveDialogPos($dialog_window, "rename")
	GUIDelete($dialog_window)

  AutoItSetOption("GUICoordMode", $old_coord_mode)
  AutoItSetOption("GUIOnEventMode", $old_event_mode)

  ResumeMainWindow()
	return $result

endfunc















; Deletes the selected file or folder, honouring both preferences.
; Reads the selection, writes nothing, returns nothing. Called from
; the Delete button and menu items, with or without recycle bin.
func DeleteSelectedItem()
  local $item_kind = ""
  local $target = GetSelectedTarget($item_kind)
  if $target = "" then return
  local $confirm_choice
  if $confirm_delete_pref = $GUI_CHECKED then
    $confirm_choice = ShowAppMsg("Really Delete?", "Do you really wish to delete this " & $item_kind & "? " & @LF & @LF & "  " & $target, $APP_MSG_YESNO, 0)
  else
    $confirm_choice = $IDYES
  endif
  local $ok = false
  local $failed_count = 0
  local $first_failed = ""
  local $was_cancelled = false
  switch $confirm_choice
    case $IDYES
      local $is_dir = $item_kind = "directory"
      SuspendMainWindow()
      if $is_dir then
        local $folder_outcome
        if $recycle_bin_pref = $GUI_CHECKED then
          $folder_outcome = RecycleFolderWithProgress($target, "Recycle Folder")
        else
          $folder_outcome = DeleteFolderWithProgress($target, "Delete Folder")
        endif
        $failed_count = $folder_outcome[1]
        $first_failed = $folder_outcome[2]
        $was_cancelled = $folder_outcome[3]
        $ok = $failed_count = 0 and not $was_cancelled
      elseif $recycle_bin_pref = $GUI_CHECKED then
        SetBusyTitle("Recycling")
        $ok = MoveTargetToRecycleBin($target, GetPathLeaf($target), $is_dir)
        RestoreBusyTitle()
      else
        SetBusyTitle("Deleting")
        $ok = _LFN_FileDelete($target)
        RestoreBusyTitle()
      endif
      ResumeMainWindow()
    case $IDNO
      return
  endswitch
  local $recycle_note = ""
  if $recycle_bin_pref = $GUI_CHECKED then $recycle_note = @LF & @LF & "NOTE: Recycling items can fail if the file name is too long. " & @LF & "Either do a full delete, or first rename the file to something shorter."
  if $was_cancelled then
    ShowAppMsg("Stopped", "Stopped. Files already processed stay where they were put, the rest were left untouched. ", $APP_MSG_OK, 0)
  elseif $failed_count > 0 then
    ShowAppMsg($MSG_DELETE_FAILED, $MSG_DELETE_FAILED & @LF & @LF & $failed_count & " files could not be deleted. First trouble: " & @LF & $first_failed & $recycle_note, $APP_MSG_OK, 0)
  elseif not $ok then
    ShowAppMsg($MSG_DELETE_FAILED, $MSG_DELETE_FAILED & @LF & @LF & "Possibly you don't have the correct permissions to delete this " & $item_kind & ". " & $recycle_note, $APP_MSG_OK, 0)
  endif
  if $ok or $was_cancelled or $failed_count > 0 then RefreshFileList()
endfunc





; Moves one file or folder to the recycle bin via the temp folder.
; Reads $target, $selected_name and $is_dir, writes nothing, returns
; true when the item was recycled and false otherwise. Callers are
; the delete workflow only.
func MoveTargetToRecycleBin($target, $selected_name, $is_dir)
  EnsureTempFolder()
  local $op_ok = false
  if $is_dir then
    local $recycle_outcome = RecycleFolderWithProgress($target, "Recycle Folder")
    $op_ok = $recycle_outcome[1] = 0 and not $recycle_outcome[3]
  else
    $op_ok = _LFN_FileMove($target, $temp_dir & "\" & $selected_name, $FC_OVERWRITE)
  endif
  if $op_ok then return FileRecycle($temp_dir & "\" & $selected_name) <> 0
  return false
endfunc


; Moves or copies the selected item after asking for a destination.
; Reads the selection and the $action word, writes the moved or copied
; path, refreshes the list on success, returns nothing. Called from the
; Move and Copy buttons and menu items with "move" or "copy".
func MoveOrCopySelectedItem($action)
  local $item_kind = ""
  local $target = GetSelectedTarget($item_kind)
  if $target = "" then return
  local $action_title = _StringTitleCase($action)
  local $default_dest_root = IniRead($ini_path, $app_name, "save_dir", "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}")
  SuspendMainWindow()
  local $dest_folder = FileselectFolder("select a destination folder..", $default_dest_root, 7, "", $lpf_GUI)
  ResumeMainWindow()
  if $dest_folder = "" or not _LFN_FileExists($dest_folder) then return
  IniWrite($ini_path, $app_name, "save_dir", $dest_folder)
  local $is_dir = $item_kind = "directory"
  if _LFN_FileExists($dest_folder & "\" & GetPathLeaf($target)) then
    WarnTargetExists($item_kind, $action_title)
    return
  endif
  local $ok = false
  local $failed_count = 0
  local $first_failed = ""
  local $was_cancelled = false
  if $is_dir then
    SuspendMainWindow()
    local $folder_outcome = CopyOrMoveFolder($target, $dest_folder & "\" & GetPathLeaf($target), $action, $action_title & " Folder")
    ResumeMainWindow()
    $failed_count = $folder_outcome[1]
    $first_failed = $folder_outcome[2]
    $was_cancelled = $folder_outcome[3]
    $ok = $failed_count = 0 and not $was_cancelled
  else
    if $action = "move" then
      SetBusyTitle("Moving")
      $ok = _LFN_FileMove($target, $dest_folder, $FC_NOOVERWRITE)
    else
      SetBusyTitle("Copying")
      $ok = _LFN_FileCopy($target, $dest_folder, $FC_NOOVERWRITE)
    endif
    RestoreBusyTitle()
  endif
  if $was_cancelled then
    ShowAppMsg("Stopped", "Stopped. Files already processed stay where they were put, the rest were left untouched. ", $APP_MSG_OK, 0)
  elseif $failed_count > 0 then
    ShowAppMsg($action_title & " Partly Failed", $action_title & " finished with " & $failed_count & " files skipped. First trouble: " & @LF & $first_failed, $APP_MSG_OK, 0)
  elseif not $ok then
    ShowAppMsg($action_title & " Failed!", $action_title & " Failed!" & @LF & @LF & "Possibly you don't have the correct permissions to " & $action & " this " & $item_kind & ". ", $APP_MSG_OK, 0)
  endif
  if $ok or $was_cancelled or $failed_count > 0 then RefreshFileList()
endfunc


; Warns that the destination already holds the name.
; Reads $item_kind and $action_title, writes nothing, returns nothing.
; Called from the move-or-copy workflow before acting.
func WarnTargetExists($item_kind, $action_title)
  local $kind_title = "File"
  local $kind_body = "file"
  if $item_kind = "directory" then
    $kind_title = "Folder"
    $kind_body = "folder"
  endif
  ShowAppMsg($kind_title & " Already Exists!", $action_title & " Failed!" & @LF & @LF & "The " & $kind_body & " already exists in the target location! ", $APP_MSG_OK, 0)
endfunc


func EnsureTempFolder()
  local $op_ok
  if not FileExists($temp_dir) then
    $op_ok = DirCreate($temp_dir)
    if not $op_ok then ShowAppMsg("Temp Folder Error!", "I cannot create the temporary folder! " & @LF & "(" & $temp_dir & ") ", $APP_MSG_OK, 0)
  endif
  if __LFN_Target_IsExistingFolder($recycle_mirror) then _LFN_DirRemove($recycle_mirror, 3)
endfunc


func GetselectedItemName($warn = true)
  local $selected_index = _GUICtrlListBox_GetCurSel($list_ctrl)
  if $selected_index = -1 then
    if $warn then ShowAppMsg("Nothing selected!", "Please select something first! ", $APP_MSG_OK, 0)
    return ""
  endif
  return _GUICtrlListBox_GetText($list_ctrl, $selected_index)
endfunc


func OnWmCommand($hwnd, $msg, $wparam, $lparam)
  #forceref $hwnd, $msg
  local $lparam_val, $list_hwnd
  if not IsHWnd($list_ctrl) then $list_hwnd = GUICtrlGetHandle($list_ctrl)
  $lparam_val = $lparam
  local $notify_code = BitShift($wparam, 16)
  switch $lparam_val
    case $list_ctrl, $list_hwnd
      switch $notify_code
        case $LBN_DBLCLK
          if ListClickIndex() <> -1 then OpenSelectedItem()
        case $LBN_SELCHANGE
          if $single_click_pref = $GUI_CHECKED and ListClickIndex() <> -1 then OpenSelectedItem()
      endswitch
endswitch
  return $GUI_RUNDEFMSG
endfunc


; Returns the list index under the mouse cursor, or -1 over blank space.
; Reads the cursor position in list client coordinates, writes nothing.
; Used to ignore clicks that land on empty list area.
func ListClickIndex()
  local $cursor = _WinAPI_GetMousePos(true, GUICtrlGetHandle($list_ctrl))
  if @error then return -1
  return _GUICtrlListBox_ItemFromPoint($list_ctrl, DllStructGetData($cursor, "X"), DllStructGetData($cursor, "Y"))
endfunc


; Selects the list item under the cursor on right-click.
; Syncs right-clicks to the list selection and blocks the menu on the
; parent row. Reads the click position from the message, writes the
; list selection, returns 0 on the parent row so no menu opens and
; $GUI_RUNDEFMSG otherwise. Keyboard-invoked menus keep the current
; selection and are blocked the same way on the parent row.
func OnContextMenu($hwnd, $msg, $wparam, $lparam)
  #forceref $hwnd, $msg
  if $wparam <> GUICtrlGetHandle($list_ctrl) then return $GUI_RUNDEFMSG
  if $lparam <> -1 then
    local $point = DllStructCreate("int X;int Y")
    DllStructSetData($point, "X", BitAND($lparam, 0xFFFF))
    DllStructSetData($point, "Y", BitShift($lparam, 16))
    _WinAPI_ScreenToClient(GUICtrlGetHandle($list_ctrl), $point)
    local $index = _GUICtrlListBox_ItemFromPoint($list_ctrl, DllStructGetData($point, "X"), DllStructGetData($point, "Y"))
    if $index <> -1 then _GUICtrlListBox_SetCurSel($list_ctrl, $index)
  endif
  if GetselectedItemName(false) = $PARENT_MARK then return 0
  return $GUI_RUNDEFMSG
endfunc


; Opens the selected list item the same way for single and double click.
; Reads the list selection, writes $current_dir and refreshes for folders,
; launches files, returns nothing. Called from OnWmCommand.
func OpenSelectedItem()
  local $selected_name = GetselectedItemName(false)
  if $selected_name = "" then return
  if StringRight($selected_name, 1) = "\" then $selected_name = StringTrimRight($selected_name, 1)
  if $selected_name = $PARENT_MARK then
    $current_dir = GetLongParent($current_dir)
    RefreshFileList()
  elseif __LFN_Target_IsExistingFolder($current_dir & "\" & $selected_name) then
    $current_dir = $current_dir & "\" & $selected_name
    RefreshFileList()
  else
    ShellOpenselected()
  endif
endfunc


func SaveLastPath()
  local $last_path = $current_dir
  if StringMid($last_path, 2, 1) = ":" and StringLen($last_path) = 2 then $last_path &= "\"
  if not __LFN_Target_IsExistingFolder($last_path) then return
  IniWrite($ini_path, $app_name, "last_path", $last_path)
endfunc


func OnMinimizeOrTrayClick()
  ToggleWindowVisibility()
endfunc


func ToggleWindowVisibility()
  local $win_state = WinGetState($lpf_GUI)
  if BitAND($win_state, $WIN_STATE_VISIBLE) then
    UnregisterHotkeys()
    GUISetState(@SW_HIDE, $lpf_GUI)
    $window_visible = false
  else
    GUISetState(@SW_SHOW, $lpf_GUI)
    $window_visible = true
    RegisterHotkeys()
  endif
endfunc


func lpf_EditINIFile()
  local $editor_exe = IniRead($ini_path, $app_name, "editor", "notepad.exe")
  TrayItemSetState($tray_item_edit_ini, $GUI_UNCHECKED)
  Run($editor_exe & " " & $ini_path)
endfunc


func OnToggleRecycleBinPref()
  if BitAND(TrayItemGetState($tray_item_recycle_bin), $GUI_CHECKED) then
    $recycle_bin_pref = $GUI_CHECKED
  else
    $recycle_bin_pref = $GUI_UNCHECKED
  endif
  GUICtrlDelete($context_menu)
  CreateListContextMenu()
  IniWriteCheckBoxValue($ini_path, $app_name, "delete_to_recycle_bin", $recycle_bin_pref)
endfunc


func OnToggleConfirmDeletePref()
  if BitAND(TrayItemGetState($tray_item_confirm_delete), $GUI_CHECKED) then
    $confirm_delete_pref = $GUI_CHECKED
  else
    $confirm_delete_pref = $GUI_UNCHECKED
  endif
  IniWriteCheckBoxValue($ini_path, $app_name, "confirm_delete", $confirm_delete_pref)
endfunc


; Toggles single-click opening of list items from either menu.
; Flips $single_click_pref itself, mirrors the new state onto the tray
; and list items, writes the single_click ini key, returns nothing. Off
; by default; double-click keeps working either way.
func OnToggleSingleClick()
  if $single_click_pref = $GUI_CHECKED then
    $single_click_pref = $GUI_UNCHECKED
  else
    $single_click_pref = $GUI_CHECKED
  endif
  TrayItemSetState($tray_item_single_click, $single_click_pref)
  GUICtrlSetState($ctx_item_single_click, $single_click_pref)
  IniWriteCheckBoxValue($ini_path, $app_name, "single_click", $single_click_pref)
endfunc


func OnToggleAlwaysOnTop()
  local $prev_always_on_top = $always_on_top
  if BitAND(TrayItemGetState($tray_item_ontop), $GUI_CHECKED) then
    $always_on_top = $GUI_CHECKED
  else
    $always_on_top = $GUI_UNCHECKED
  endif
  if $prev_always_on_top <> $always_on_top then IniWriteCheckBoxValue($ini_path, $app_name, "always_on_top", $always_on_top)
  ApplyAlwaysOnTop()
endfunc


func ApplyAlwaysOnTop()
  if $always_on_top = $GUI_CHECKED then
    WinSetOnTop($lpf_GUI, "", 1)
  else
    WinSetOnTop($lpf_GUI, "", 0)
  endif
endfunc


func OnToggleExplorerContext()
  if $explorer_context = $GUI_UNCHECKED then
    $explorer_context = $GUI_CHECKED
  else
    $explorer_context = $GUI_UNCHECKED
  endif
  TrayItemSetState($tray_item_explorer_ctx, $explorer_context)
  IniWriteCheckBoxValue($ini_path, $app_name, "explorer_context", $GUI_CHECKED)
  ApplyExplorerContextMenu()
endfunc


func ApplyExplorerContextMenu()
  if $explorer_context = $GUI_CHECKED then
    if RegRead("HKEY_CLASSES_ROOT\Directory\shell\" & $app_name, "") = $EXPLORER_MENU_NAME then return
    if RegWrite("HKEY_CLASSES_ROOT\Directory\shell\" & $app_name, "", "REG_SZ", $EXPLORER_MENU_NAME) and RegWrite("HKEY_CLASSES_ROOT\Directory\shell\" & $app_name & "\command", "", "REG_SZ", '"' & $exe_path & '" ' & ' "%1"') then
      TrayItemSetState($tray_item_explorer_ctx, $explorer_context)
    else
      TrayItemSetState($tray_item_explorer_ctx, $GUI_DISABLE)
    endif
  else
    if RegDelete("HKEY_CLASSES_ROOT\Directory\shell\" & $app_name) then
      TrayItemSetState($tray_item_explorer_ctx, $explorer_context)
    else
      TrayItemSetState($tray_item_explorer_ctx, $GUI_DISABLE)
    endif
  endif
endfunc


func FadeInWindow($parent_hwnd, $step = 5)
  local const $ALPHA_MAX = 255
  local const $PERCENT_MAX = 100
  local const $FADE_FRAME_MS = 5
  local const $DEFAULT_STEP = 5
  if $step <= 0 then $step = $DEFAULT_STEP
  WinSetTrans($parent_hwnd, "", 0)
  GUISetState(@SW_SHOW, $parent_hwnd)
  local $i = $PERCENT_MAX
  while $i >= 3
    WinSetTrans($parent_hwnd, "", ($PERCENT_MAX - $i) * $ALPHA_MAX / $PERCENT_MAX)
    Sleep($FADE_FRAME_MS)
    $i -= $step
  wend
  WinSetTrans($parent_hwnd, "", $ALPHA_MAX)
  WinActivate($parent_hwnd)
endfunc


func OnTrayHoverActivate()
  if not $window_visible then return
  if $hover_to_show = $GUI_UNCHECKED then return
  if $hover_last_tick = 0 or _Timer_Diff($hover_last_tick) > 1000 then
    $hover_last_tick = _Timer_Init()
  endif
  local $elapsed_ms = _Timer_Diff($hover_last_tick)
  if $elapsed_ms > ((11 - $hover_sensitivity) * 100) then
    $hover_last_tick = 0
    WinActivate($lpf_GUI)
    RedrawWindow($lpf_GUI)
  endif
endfunc


func RedrawWindow($hwnd, $rect_struct = 0, $erase = 0, $flags = BitOR($RDW_INVALIDATE, $RDW_ERASE))
  local $rect_ptr = 0, $result
  if $rect_struct <> 0 then $rect_ptr = DllStructGetPtr($rect_struct)
  $result = DllCall("User32.dll", "int", "RedrawWindow", "hwnd", $hwnd, "ptr", $rect_ptr, "int", $erase, "int", $flags)
  if IsArray($result) then return ($result[0] <> 0)
endfunc


func OnResized()
  EnforceWindowBounds()
endfunc


func OnPrimaryUp()
  EnforceWindowBounds()
endfunc


func EnforceWindowBounds()
  local $win_rect = WinGetPos($lpf_GUI)
  if not IsArray($win_rect) then return false
  if $win_rect[2] < $min_width + $min_width_pad then WinMove($lpf_GUI, "", default, default, $min_width + $min_width_pad)
  if $win_rect[3] < $min_height + $min_height_pad then WinMove($lpf_GUI, "", default, default, default, $min_height + $min_height_pad)
  Sleep(25)
  $win_rect = WinGetPos($lpf_GUI)
  if not IsArray($win_rect) then return false
  if $win_rect[0] > @DesktopWidth - $win_rect[2] then WinMove($lpf_GUI, "", @DesktopWidth - $win_rect[2], default, default)
  if $win_rect[1] > @DesktopHeight - $win_rect[3] then WinMove($lpf_GUI, "", default, @DesktopHeight - $win_rect[3], default)
  return true
endfunc


func SaveWindowGeometry()
  if not EnforceWindowBounds() then return false
  local $win_rect = WinGetPos($lpf_GUI)
  if not IsArray($win_rect) then return false
  if $win_x <> $win_rect[0] and $win_rect[0] >= 0 and $win_rect[0] < (@DesktopWidth - 25) then IniWrite($ini_path, $app_name, "x", $win_rect[0])
  if $win_y <> $win_rect[1] and $win_rect[1] >= 0 and $win_rect[1] < (@DesktopHeight - 25) then IniWrite($ini_path, $app_name, "y", $win_rect[1])
  $win_rect = WinGetClientSize($lpf_GUI)
  if not IsArray($win_rect) then return false
  IniWrite($ini_path, $app_name, "width", $win_rect[0])
  IniWrite($ini_path, $app_name, "height", $win_rect[1])
  return true
endfunc



func GetPathLeaf($path)
  $path = StringReplace($path, "/", "\")
  if StringRight($path, 1) = "\" then $path = StringTrimRight($path, 1)
  local $parts = StringSplit($path, "\")
  local $leaf = $parts[$parts[0]]
  if StringRight($leaf, 1) = ":" then $leaf = StringTrimRight($leaf, 1)
  return $leaf
endfunc


func CheckForUpdate($app_name, $check_url, $download_url, $ini_path, $section, $app_version, $parent_hwnd = default, $suspend_gui = false)
  local $check_interval_days = IniRead($ini_path, $section, "version_checking", "")
  if $check_interval_days == 0 then return
  if $check_interval_days = -1 or $check_interval_days = "" then
    if $suspend_gui then SuspendMainWindow()
    local $answer = InputBox("Automatic Version Checking?", $app_name & " can check online for a new version of itself." & @LF & _
                              "Enter the number of days between checks (0 to disable version checking).  ", "", " M", 400, 150, _
                                                            (@DesktopWidth / 2) - 200, (@DesktopHeight / 2) - 50, 0, $parent_hwnd)
    if $suspend_gui then ResumeMainWindow()
    if $answer = "" then return false
    _LFN_IniWrite($ini_path, $section, "version_checking", Int($answer))
    if $answer = 0 then return
  endif
  if $check_interval_days > 365 then $check_interval_days = 365
  if $check_interval_days > 0 then
    local $last_checked = IniRead($ini_path, $section, "version_checked", "2000/01/01 00:00:00")
    local $days_since_check = _DateDiff("D", $last_checked, _NowCalc())
    if $days_since_check < $check_interval_days then return
  endif
  local $plural_s = ""
  if $check_interval_days > 1 then $plural_s = "s"
  ProgressOn("Version Check (every " & $check_interval_days & " day" & $plural_s & ")", "Checking for new version..")
  ProgressSet(25)
  local $remote_version = InetRead($check_url, $INET_FORCERELOAD)
  if @error <> 0 then
    ProgressOff()
    ShowAppMsg("Version Check FAILED!", "Could not determine version online." & @LF & "Check your firewall.", $APP_MSG_OK, 0)
    return
  endif
  $remote_version = BinaryToString($remote_version)
  ProgressSet(50)
  IniWrite($ini_path, $section, "version_checked", _NowCalc())
  ProgressSet(75)
  local $compare_result = _VersionCompare($app_version, $remote_version)
  switch $compare_result
    case 0, 1
      ProgressSet(100)
      ProgressOff()
      return false
    case -1
      ProgressSet(100)
      local $choice = ShowAppMsg("New Version Available", "A newer version of " & _
                                             $app_name & " is available." & @LF & "Would you like to visit the download page?", $APP_MSG_YESNO, 0)
      ProgressOff()
      switch $choice
        case $IDYES
          VisitUrl($download_url)
      endswitch
  endswitch
endfunc



func CheckForUpgradeINI()

  local $saved_version = IniRead($ini_path, $app_name, "version", 0)
  local $compare_result = _VersionCompare($app_version, $saved_version)
  switch $compare_result
    case 0, -1
      return false
  endswitch
  local $new_ini_path = @TempDir & "\" & $ini_filename & ".new"
  FileInstall("Resources\Long Path Fixer.ini", $new_ini_path, 1)
  local $section_names = IniReadSectionNames($ini_path)
  if IsArray($section_names) then
    for $i = 1 to $section_names[0]
      local $section_data = IniReadSection($ini_path, $section_names[$i])
      if IsArray($section_data) then
        for $j = 1 to $section_data[0][0]
          if StringLeft($section_data[$j][0], 1) <> "#" then
            IniWrite($new_ini_path, $section_names[$i], $section_data[$j][0], $section_data[$j][1])
          endif
        next
      endif
    next
  endif
  FileMove($ini_path, GetLongParent($ini_path) & "\[" & @YEAR & "-" & @MON & "-" & @MDAY & "@" & @HOUR & "." & @MIN & "] " & $ini_filename & ".ini")
  FileMove($new_ini_path, $ini_path, $FC_OVERWRITE)
  IniWrite($ini_path, $app_name, "version", $app_version)
endfunc


func ShowAboutDialog()
  TrayItemSetState($tray_item_about, $GUI_UNCHECKED)
  local $old_event_mode = AutoItSetOption("GUIOnEventMode", 0)
  local $old_coord_mode = AutoItSetOption("GUICoordMode", 1)
  SuspendMainWindow()
  local $about_pos = GetDialogPos("about")
  local $dlg_hwnd = GUICreate(" About " & $app_name & "..", 250, 105, $about_pos[0], $about_pos[1], $WS_CAPTION, $WS_EX_TOPMOST)
  GUICtrlCreateLabel(" " & $app_name & " v" & $app_version & @LF & " from corz.org", 60, 8)
  GUICtrlCreateIcon($exe_path, 0, 10, 10)
  GUICtrlCreateLabel(" Do you want to visit the " & @LF & " " & $app_name & " web page at this time?  ", 60, 40)
  local $btn_no = GUICtrlCreateButton("NO, not right now", 10, 80, 95, 22)
  GUICtrlSetTip(-1, "The other button is the one you want to click!")
  local $btn_yes = GUICtrlCreateButton("YES, let's do it!", 148, 80, 95, 22)
  GUICtrlSetTip(-1, "The link will open in your system default browser")
  GUISetState()
  while 1
    local $msg = GUIGetMsg()
    switch $msg
      case $GUI_EVENT_CLOSE, $btn_no
        SaveDialogPos($dlg_hwnd, "about")
        GUIDelete($dlg_hwnd)
        exitloop
      case $btn_yes
        VisitUrl($app_url)
        SaveDialogPos($dlg_hwnd, "about")
        GUIDelete($dlg_hwnd)
        exitloop
    endswitch
  wend
  AutoItSetOption("GUICoordMode", $old_coord_mode)
  AutoItSetOption("GUIOnEventMode", $old_event_mode)
  ResumeMainWindow()
endfunc


; Opens the folder-operation progress window with an empty bar.
; Reads $dialog_title for the window caption, writes the new window and
; control handles into the $progress_* globals, returns nothing. The main
; window stays suspended until CloseProgressDialog runs. The bar advances
; through UpdateProgressDialog between finished files.
; Shortens a path from the middle when too long for the dialog.
; Reads $path and $max_chars, writes nothing, returns the path unchanged
; when short enough and head plus "..." plus tail otherwise.
func TruncateMiddle($path, $max_chars)
  if StringLen($path) <= $max_chars then return $path
  local $head_len = Int(($max_chars - 3) / 2)
  local $tail_len = $max_chars - 3 - $head_len
  return StringLeft($path, $head_len) & "..." & StringRight($path, $tail_len)
endfunc


func ShowProgressDialog($dialog_title, $header_line)
  $progress_old_event_mode = AutoItSetOption("GUIOnEventMode", 0)
  $progress_old_coord_mode = AutoItSetOption("GUICoordMode", 1)
  local $dlg_pos = GetDialogPos("progress")
  $progress_window = GUICreate($dialog_title, 380, 135, $dlg_pos[0], $dlg_pos[1], $WS_CAPTION, $WS_EX_TOPMOST)
  GUICtrlCreateLabel($header_line, 10, 8, 360, 18)
  $progress_file_label = GUICtrlCreateLabel("", 10, 28, 360, 18)
  $progress_bar = GUICtrlCreateProgress(10, 52, 360, 20)
  $progress_cancel_button = GUICtrlCreateButton("Cancel", 290, 100, 80, 25)
  GUISetState(@SW_SHOW, $progress_window)
endfunc


; Advances the progress window and checks for Cancel.
; Reads $done_count files finished out of $item_total and $current_name
; for the label, writes the new bar position, returns false the moment the
; user presses Cancel or closes the window and true otherwise. Callers stop
; the file loop on false and leave finished files where they are.
func UpdateProgressDialog($done_count, $item_total, $current_name)
  local $shown_name = $current_name
  if StringLen($shown_name) > 62 then $shown_name = "..." & StringRight($shown_name, 59)
  GUICtrlSetData($progress_file_label, $shown_name)
  GUICtrlSetData($progress_bar, Round($done_count * 100 / $item_total))
  local $ui_message = GUIGetMsg()
  if $ui_message = $GUI_EVENT_CLOSE or $ui_message = $progress_cancel_button then return false
  return true
endfunc


; Closes the folder-operation progress window.
; Reads the $progress_* globals, writes nothing else, returns nothing.
; Restores the event and coordinate modes saved by ShowProgressDialog.
func CloseProgressDialog()
  SaveDialogPos($progress_window, "progress")
  GUIDelete($progress_window)
  AutoItSetOption("GUICoordMode", $progress_old_coord_mode)
  AutoItSetOption("GUIOnEventMode", $progress_old_event_mode)
endfunc


; Shows the current single-file action in the main window caption.
; Reads $action_word ("Copying", "Moving", "Deleting", "Recycling"),
; writes the caption of $lpf_GUI, returns nothing. The compositor repaints
; the caption without message pumping, so the notice stays visible while
; the one atomic file call blocks. RestoreBusyTitle removes it again.
func SetBusyTitle($action_word)
  WinSetTitle($lpf_GUI, "", $win_title & " - " & $action_word & " file..")
endfunc


; Restores the normal main window caption.
; Reads $win_title, writes the caption of $lpf_GUI, returns nothing.
; Callers run this the moment their atomic file call returns.
func RestoreBusyTitle()
  WinSetTitle($lpf_GUI, "", $win_title)
endfunc


; Removes emptied source folders deepest first after a folder move.
; Reads the enumerated $entries from the folder driver, writes nothing,
; returns nothing. Folders that still hold files fail quietly and stay.
func RemoveEmptySourceDirs($entries)
  for $i = $entries[0] to 1 step -1
    if StringRight($entries[$i], 1) = "\" then _LFN_DirRemove(StringTrimRight($entries[$i], 1), 0)
  next
endfunc


; Copies or moves a whole folder file by file with progress and Cancel.
; Reads $source_dir, $dest_dir, $action ("copy" or "move") and
; $dialog_title, writes the mirrored folders and files under $dest_dir,
; returns a 4-element array: [0] files attempted, [1] files failed, [2]
; first failed path, [3] true when the user cancelled. Folders with no
; files still mirror with no window. A cancelled move leaves finished files
; moved and the rest untouched.
func CopyOrMoveFolder($source_dir, $dest_dir, $action, $dialog_title)
  local $outcome[4] = [0, 0, "", false]
  local $source_root = $source_dir
  while StringInStr($source_root, "\\")
    $source_root = StringReplace($source_root, "\\", "\")
  wend
  local $entries = __LFN_FilesListToArray($source_root, true)
  local $file_total = @extended
  local $source_prefix = __LFN_Target_SetUnicodePrefix($source_root) & "\"
  local $i, $relative
  for $i = 1 to $entries[0]
    if StringRight($entries[$i], 1) = "\" then
      $relative = StringTrimLeft($entries[$i], StringLen($source_prefix))
      _LFN_DirCreate($dest_dir & "\" & $relative)
    endif
  next
  if $file_total > 0 then ShowProgressDialog($dialog_title, _StringTitleCase($action) & "ing files to " & TruncateMiddle($dest_dir, $PROGRESS_PATH_CHARS))
  local $done_count = 0
  local $file_ok = false
  for $i = 1 to $entries[0]
    if StringRight($entries[$i], 1) = "\" then continueloop
    $relative = StringTrimLeft($entries[$i], StringLen($source_prefix))
    if $file_total > 0 then
      if not UpdateProgressDialog($done_count, $file_total, $relative) then
        $outcome[3] = true
        exitloop
      endif
    endif
    $outcome[0] += 1
    if $action = "move" then
      $file_ok = _LFN_FileMove($entries[$i], $dest_dir & "\" & $relative, $FC_NOOVERWRITE)
    else
      $file_ok = _LFN_FileCopy($entries[$i], $dest_dir & "\" & $relative, $FC_NOOVERWRITE)
    endif
    if not $file_ok then
      $outcome[1] += 1
      if $outcome[2] = "" then $outcome[2] = $entries[$i]
    endif
    $done_count += 1
  next
  if $file_total > 0 then CloseProgressDialog()
  if $action = "move" then
    RemoveEmptySourceDirs($entries)
    _LFN_DirRemove($source_root, 0)
  endif
  return $outcome
endfunc


; Deletes a whole folder file by file with progress and Cancel.
; Reads $source_dir and $dialog_title, writes deletions, returns the same
; 4-element outcome array as CopyOrMoveFolder. Files go first, folders
; follow deepest first. Cancel leaves the rest untouched for next time.
func DeleteFolderWithProgress($source_dir, $dialog_title)
  local $outcome[4] = [0, 0, "", false]
  local $source_root = $source_dir
  while StringInStr($source_root, "\\")
    $source_root = StringReplace($source_root, "\\", "\")
  wend
  local $entries = __LFN_FilesListToArray($source_root, true)
  local $file_total = @extended
  local $source_prefix = __LFN_Target_SetUnicodePrefix($source_root) & "\"
  if $file_total > 0 then ShowProgressDialog($dialog_title, "Deleting files in " & TruncateMiddle($source_root, $PROGRESS_PATH_CHARS))
  local $done_count = 0
  local $i, $relative
  for $i = 1 to $entries[0]
    if StringRight($entries[$i], 1) = "\" then continueloop
    $relative = StringTrimLeft($entries[$i], StringLen($source_prefix))
    if $file_total > 0 then
      if not UpdateProgressDialog($done_count, $file_total, $relative) then
        $outcome[3] = true
        exitloop
      endif
    endif
    $outcome[0] += 1
    if not _LFN_FileDelete($entries[$i]) then
      $outcome[1] += 1
      if $outcome[2] = "" then $outcome[2] = $entries[$i]
    endif
    $done_count += 1
  next
  if $file_total > 0 then CloseProgressDialog()
  RemoveEmptySourceDirs($entries)
  _LFN_DirRemove($source_root, 0)
  return $outcome
endfunc


; Recycles a whole folder with progress and Cancel.
; Reads $source_dir and $dialog_title, writes each file into the temp
; mirror and recycles the mirror with one FileRecycle call, clears emptied
; source folders deepest first, returns the 4-element outcome array. Cancel
; stops between files; finished files wait in the mirror until the next
; recycle run cleans them away.
func RecycleFolderWithProgress($source_dir, $dialog_title)
  EnsureTempFolder()
  if __LFN_Target_IsExistingFolder($recycle_mirror) then _LFN_DirRemove($recycle_mirror, 3)
  _LFN_DirCreate($recycle_mirror)
  local $outcome[4] = [0, 0, "", false]
  local $source_root = $source_dir
  while StringInStr($source_root, "\\")
    $source_root = StringReplace($source_root, "\\", "\")
  wend
  local $entries = __LFN_FilesListToArray($source_root, true)
  local $file_total = @extended
  local $source_prefix = __LFN_Target_SetUnicodePrefix($source_root) & "\"
  local $i, $relative
  for $i = 1 to $entries[0]
    if StringRight($entries[$i], 1) = "\" then
      $relative = StringTrimLeft($entries[$i], StringLen($source_prefix))
      _LFN_DirCreate($recycle_mirror & "\" & $relative)
    endif
  next
  if $file_total > 0 then ShowProgressDialog($dialog_title, "Recycling files in " & TruncateMiddle($source_root, $PROGRESS_PATH_CHARS))
  local $done_count = 0
  for $i = 1 to $entries[0]
    if StringRight($entries[$i], 1) = "\" then continueloop
    $relative = StringTrimLeft($entries[$i], StringLen($source_prefix))
    if $file_total > 0 then
      if not UpdateProgressDialog($done_count, $file_total, $relative) then
        $outcome[3] = true
        exitloop
      endif
    endif
    $outcome[0] += 1
    if not _LFN_FileMove($entries[$i], $recycle_mirror & "\" & $relative, $FC_OVERWRITE) then
      $outcome[1] += 1
      if $outcome[2] = "" then $outcome[2] = $entries[$i]
    endif
    $done_count += 1
  next
  if $file_total > 0 then CloseProgressDialog()
  if $outcome[3] then return $outcome
  if FileRecycle($recycle_mirror) = 0 then
    $outcome[1] += 1
    if $outcome[2] = "" then $outcome[2] = $recycle_mirror
  endif
  RemoveEmptySourceDirs($entries)
  _LFN_DirRemove($source_root, 0)
  return $outcome
endfunc


; Reads a stored dialog position for an id, default centered.
; Reads "<id>_x" and "<id>_y" ini keys, writes nothing, returns a 2-element
; array with the coordinates. Callers pass the elements to GUICreate.
func GetDialogPos($dialog_id)
  local $pos[2] = [Int(IniRead($ini_path, $app_name, $dialog_id & "_x", -1)), Int(IniRead($ini_path, $app_name, $dialog_id & "_y", -1))]
  return $pos
endfunc


; Writes a dialog position for an id for next time.
; Reads $window and $dialog_id, writes "<id>_x" and "<id>_y" ini keys,
; returns nothing. Off-screen positions never store, same guard as
; SaveWindowGeometry.
func SaveDialogPos($window, $dialog_id)
  local $dlg_rect = WinGetPos($window)
  if not IsArray($dlg_rect) then return
  if $dlg_rect[0] >= 0 and $dlg_rect[0] < (@DesktopWidth - 25) then IniWrite($ini_path, $app_name, $dialog_id & "_x", $dlg_rect[0])
  if $dlg_rect[1] >= 0 and $dlg_rect[1] < (@DesktopHeight - 25) then IniWrite($ini_path, $app_name, $dialog_id & "_y", $dlg_rect[1])
endfunc


; Shows an app message through the house UserDialog.
; Reads $title and $text for display, $style ($APP_MSG_OK or $APP_MSG_YESNO)
; for the buttons and $timeout seconds (0 waits forever), writes nothing,
; returns $IDOK, $IDYES or $IDNO. Rendering, timeout, modality and
; title-keyed position memory all live in UserDialog: same titles share a
; spot. Dialog typeface comes from the dialog_font ini value via UserDialog.
; The close box and a spent timeout answer $IDNO on Yes/No windows
; and $IDOK on OK windows.
func ShowAppMsg($title, $text, $style, $timeout)
  local $buttons = StringSplit("OK", "|")
  if $style = $APP_MSG_YESNO then $buttons = StringSplit("Yes|No", "|")
  local $answer = UserDialog($title, $text, $buttons, default, default, $timeout, true, false, false, "", "", "", $ini_path, $app_name)
  if $style = $APP_MSG_YESNO then
    if $answer = 1 then return $IDYES
    return $IDNO
  endif
  return $IDOK
endfunc


func SuspendMainWindow()
  GUISetState(@SW_DISABLE, $lpf_GUI)
  TraySetState($TRAY_ICONSTATE_HIDE)
  UnregisterHotkeys()
endfunc


func ResumeMainWindow()
  GUISetState(@SW_ENABLE, $lpf_GUI)
  TraySetState($TRAY_ICONSTATE_SHOW)
  WinActivate($lpf_GUI)
  GUISwitch($lpf_GUI)
  RegisterHotkeys()
endfunc


func RegisterHotkeys()
  HotKeySet("{F5}", "OnHotkeyF5")
  HotKeySet("{F2}", "OnHotkeyF2")
  HotKeySet("{Del}", "OnHotkeyDel")
  HotKeySet("{Esc}", "OnHotkeyEsc")
  HotKeySet("{ENTER}", "OnComboEnter")
endfunc


func UnregisterHotkeys()
  HotKeySet("{F5}")
  HotKeySet("{F2}")
  HotKeySet("{Del}")
  HotKeySet("{Esc}")
  HotKeySet("{ENTER}")
endfunc


; Sends a hotkey to the active window when Long Path Fixer does not own it.
; Reads $key as the AutoIt key string and $func_name as the handler name
; to restore. Writes nothing, returns nothing. Callers are the four
; OnHotkey handlers plus OnComboEnter, each passes its own key and name.
#Au3Stripper_Off
func SetHotKey($key, $func_name)
  HotKeySet($key)
  Send($key)
  HotKeySet($key, $func_name)
endfunc
#Au3Stripper_On


func OnHotkeyF5()
  if WinActive($lpf_GUI) then
    RefreshFileList()
  else
    SetHotKey("{F5}", "OnHotkeyF5")
  endif
endfunc


func OnHotkeyDel()
  if WinActive($lpf_GUI) then
    Deleteselected()
  else
    SetHotKey("{Del}", "OnHotkeyDel")
  endif
endfunc


func OnHotkeyF2()
  if WinActive($lpf_GUI) then
    Renameselected()
  else
    SetHotKey("{F2}", "OnHotkeyF2")
  endif
endfunc


func OnHotkeyEsc()
  if WinActive($lpf_GUI) then
    SaveAndExit(-9)
  else
    SetHotKey("{Esc}", "OnHotkeyEsc")
  endif
endfunc


func OnTrayExit()
  SaveAndExit(-9)
endfunc


func OnClose()
  SaveAndExit(-9)
endfunc


func SaveAndExit($exit_code = 0)
  SaveLastPath()
  SaveWindowGeometry()
  if FileExists($temp_dir) then DirRemove($temp_dir, 1)
  CheckForUpdate($app_name, $version_check_url, $download_url, $ini_path, $app_name, $app_version, $lpf_GUI)
  exit $exit_code
endfunc








; Compiler Directives..
;

#Region

#pragma compile(AutoItExecuteAllowed, true)
; #pragma compile(ExecLevel, HighestAvailable)
#pragma compile(Compression, 9)


#AutoIt3Wrapper_LogFile="%scriptdir%\wrapper.log"

#AutoIt3Wrapper_Run_Au3Stripper=Y
#Au3Stripper_Parameters=/StripOnly /rsln
#AutoIt3Wrapper_UseX64=Y
#AutoIt3Wrapper_UseUpx=N
#AutoIt3Wrapper_Run_AU3Check=Y
#AutoIt3Wrapper_AU3Check_Parameters=-d -w 1 -w 2 -w 3 -w- 4 -w 5 -w 6 -w 7 -v 1
#AutoIt3Wrapper_AU3Check_Stop_OnWarning=N
#AutoIt3Wrapper_Run_Stop_OnError=N
#AutoIt3Wrapper_Res_HiDpi=Y

; *** YOU MIGHT NEED TO USE FORWARD SLASHES IN RELATIVE PATHS - YMMV!!! **
#AutoIt3Wrapper_Icon=Resources\Long Path Fixer.ico

; Free-Form Res Fields..
#AutoIt3Wrapper_Res_Field=Author|corz.org
#AutoIt3Wrapper_Res_Field=CompanyName|corz.org
#AutoIt3Wrapper_Res_Field=Contact|software@corz.org
#AutoIt3Wrapper_Res_Field=Copyright|corz.org
#AutoIt3Wrapper_Res_Field=Instructions|Launch Long Path Fixer.exe.
#AutoIt3Wrapper_Res_Field=Long Description|Long Path Fixer works with paths that Explorer (and others) can't reach.
#AutoIt3Wrapper_Res_Field=ProductName|Long Path Fixer
#AutoIt3Wrapper_Res_Field=Publisher|corz.org
#AutoIt3Wrapper_Res_Field=Web Page|http://corz.org/
#AutoIt3Wrapper_Res_Field=Compiled|%date% %time%

; Application's resource info..
#AutoIt3Wrapper_Res_Comment=Long Path Fixer
; This is the one that shows up in Process Explorer..
#AutoIt3Wrapper_Res_Description=Long Path Fixer - from corz.org
#AutoIt3Wrapper_Res_LegalCopyright=corz.org
#AutoIt3Wrapper_Res_ProductVersion=1


#AutoIt3Wrapper_Res_Field=Build|Public Release


; Backup this version of the script (dropped into a backup.zip, below). So I don't have to remember to..
#AutoIt3Wrapper_Run_Before_Admin=Y
#AutoIt3Wrapper_Run_After_Admin=Y

; Kill my .exe if it is running. We'll use this new version immediately.
#AutoIt3Wrapper_Run_Before=taskkill /F /IM Long Path Fixer.exe

; Copy the source file, name with the current version..
#AutoIt3Wrapper_Run_After=copy /Y "%in%"       ".\%scriptfile% - %fileversion%.au3"

; Copy latest binaries to app folders (overwrites existing binary).     Your copy may be somewhere else..
#AutoIt3Wrapper_Run_After=copy /Y "%outx64%"    "C:\Program Files\corz\Long Path Fixer\Long Path Fixer.exe"

; Handy to keep a backup of the stripped version (if applicable), too..
#AutoIt3Wrapper_Run_After=move /Y .\%scriptfile%_stripped.au3       ".\%scriptfile% - %fileversion%_stripped.au3"

; Fill distro folder..
#AutoIt3Wrapper_Run_After=copy /Y   ".\Itstory.txt"     "..\Long Path Fixer\Itstory.txt"
#AutoIt3Wrapper_Run_After=move /Y   "%outx64%" 			    "..\Long Path Fixer\Long Path Fixer.exe"


; Create zip of distro directory..
#AutoIt3Wrapper_Run_After=7z.exe a -mx7 -tzip "..\Long Path Fixer.zip" "..\Long Path Fixer\"

; Hash the zip..
#AutoIt3Wrapper_Run_After=checksum.exe cq-t-h "..\Long Path Fixer.zip"


; Backup this version of the source files to BackUp.zip..
#AutoIt3Wrapper_Run_After=7z.exe a -mx7 -tzip "..\BackUp\BackUp.zip" ".\%scriptfile% - %fileversion%.au3"
#AutoIt3Wrapper_Run_After=7z.exe a -mx7 -tzip "..\BackUp\BackUp.zip" ".\%scriptfile% - %fileversion%_stripped.au3"

; Note: The 7z and checksum program directories are in my %PATH% (System Properties >> Advanced >> Environment Variables).
; Which is why I don't need to supply the full paths in these commands.


; Finally, remove the (now-zipped) source files..
#AutoIt3Wrapper_Run_After=del /f /q ".\%scriptfile% - %fileversion%.au3"
#AutoIt3Wrapper_Run_After=del /f /q ".\%scriptfile% - %fileversion%_stripped.au3"


#AutoIt3Wrapper_Run_After=start "" "C:\Program Files\corz\Long Path Fixer\Long Path Fixer.exe"


#EndRegion

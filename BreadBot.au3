#include <IE.au3>
#include <INet.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <GUIListBox.au3>
#include <GuiStatusBar.au3>
#include <WindowsConstants.au3>
#include <Array.au3>
#include <Crypt.au3>

Global $oIE, $isConnected = False, $pickedServer = False, $logCache = "", $serverFTP = ObjCreate('Scripting.Dictionary')
Global $lastUsedInput, $playerlist = ObjCreate('Scripting.Dictionary'), $confirmReady[4], $activePause[5], $config = @ScriptDir & "\settings.ini"

#Region ### START Koda GUI section ### Form=
$Form1 = GUICreate("Signaltransmitter / BFCup - Dashboard", 665, 408)
$CtrlUser = GUICtrlCreateInput("Benutzername", 8, 8, 150, 21)
$CtrlPass = GUICtrlCreateInput("Passwort", 165, 8, 158, 21)
$CtrlServer = GUICtrlCreateCombo("Server wählen...", 336, 8, 185, 21, $CBS_DROPDOWNLIST)
GUICtrlSetState(-1, $GUI_DISABLE)
$CtrlConnect = GUICtrlCreateButton("Verbinden", 528, 8, 121, 22)
$Group1 = GUICtrlCreateGroup("RCON", 8, 40, 313, 281)
GUICtrlCreateGroup("", -99, -99, 1, 1)
$CtrlRconLog = GUICtrlCreateList("", 24, 56, 281, 227, BitOR($WS_BORDER, $WS_VSCROLL))
$CtrlRconSend = GUICtrlCreateInput("RCON Befehl...", 24, 283, 281, 21)
$Group2 = GUICtrlCreateGroup("Chat", 336, 40, 313, 281)
GUICtrlCreateGroup("", -99, -99, 1, 1)
$CtrlChatLog = GUICtrlCreateList("", 348, 56, 281, 227, BitOR($WS_BORDER, $WS_VSCROLL))
$CtrlChatSend = GUICtrlCreateInput("Nachricht an alle...", 348, 283, 281, 21)
$CtrlSubmitButton = GUICtrlCreateButton(".", -10, -10, 1, 1, $BS_DEFPUSHBUTTON)
$Button2 = GUICtrlCreateButton("Warmup", 8, 328, 73, 49)
$Button3 = GUICtrlCreateButton("Knife", 88, 328, 73, 49)
$Button4 = GUICtrlCreateButton("Switch", 168, 328, 73, 49)
$Button5 = GUICtrlCreateButton("Start", 248, 328, 73, 49)
$CtrlTeamA = GUICtrlCreateInput("Team A", 336, 329, 242, 21)
$CtrlTeamB = GUICtrlCreateInput("Team B", 336, 353, 242, 21)
$CtrlTeamATacCount = GUICtrlCreateInput("1", 585, 328, 17, 21, $ES_CENTER)
$CtrlTeamBTacCount = GUICtrlCreateInput("1", 585, 352, 17, 21, $ES_CENTER)
$CtrlTeamATecTimer = GUICtrlCreateInput("15:00", 608, 328, 41, 21, $ES_CENTER)
$CtrlTeamBTecTimer = GUICtrlCreateInput("15:00", 608, 352, 41, 21, $ES_CENTER)
$StatusBar1 = _GUICtrlStatusBar_Create($Form1)
_GUICtrlStatusBar_SetMinHeight($StatusBar1, 17)
GUISetState(@SW_SHOW)
#EndRegion ### END Koda GUI section ###

GUICtrlSetTip($CtrlUser, "Gib deine Signaltransmitter - Benutzerdaten ein")
GUICtrlSetTip($CtrlPass, "Gib deine Signaltransmitter - Benutzerdaten ein")
GUICtrlSetTip($CtrlTeamA, "Drücke Enter um beide Namen auf dem Server zu setzen")
GUICtrlSetTip($CtrlTeamB, "Drücke Enter um beide Namen auf dem Server zu setzen")
GUICtrlSetTip($CtrlTeamATacCount, "Taktische Pausen")
GUICtrlSetTip($CtrlTeamBTacCount, "Taktische Pausen")
GUICtrlSetTip($CtrlTeamATecTimer, "Technische Pausen")
GUICtrlSetTip($CtrlTeamBTecTimer, "Technische Pausen")

$placeholders = ObjCreate('Scripting.Dictionary')
$placeholders.Add($CtrlRconSend, "RCON Befehl...")
$placeholders.Add($CtrlChatSend, "Nachricht an alle...")
$placeholders.Add($CtrlTeamA, "Team A")
$placeholders.Add($CtrlTeamB, "Team B")
$placeholders.Add($CtrlUser, "Benutzername")
$placeholders.Add($CtrlPass, "Passwort")

If FileExists($config) And IniRead($config,"settings", "saveLogin", 0) = 1 Then
   $loadUser = IniRead($config, "login", "username", "Benutzername")
   $loadPass = IniRead($config, "login", "password", "Passwort")
   GUICtrlSetData($CtrlUser, $loadUser)
   If $loadPass <> "Passwort" Then
	  GUICtrlSendMsg($CtrlPass, $EM_SETPASSWORDCHAR, Asc("*"), 0)
	  GUICtrlSetData($CtrlPass, decrypt($loadPass))
   EndIf
EndIf

setStatus("Warten auf Verbindung...")
GUIRegisterMsg($WM_COMMAND, "On_WM_COMMAND")

While 1
   $nMsg = GUIGetMsg()

   Switch $nMsg
	  Case $GUI_EVENT_CLOSE
		 Exit

	  Case $CtrlConnect
		 If $isConnected = False Then
			GUICtrlSetState($CtrlConnect, $GUI_DISABLE)
			$test = login(GUICtrlRead($CtrlUser), GUICtrlRead($CtrlPass))
			GUICtrlSetState($CtrlConnect, $GUI_ENABLE)
			If $test = False Then
			   ContinueLoop
			EndIf

			If Not FileExists($config) Then
			   $ask = MsgBox(32+4, "Login speichern", "Möchtest du deine Anmeldedaten speichern um darauf künftig schneller zuzugreifen?")
			   If $ask = 6 Then
				  IniWrite($config, "settings", "saveLogin", 1)
				  saveLogin()
			   Else
				  IniWrite($config, "settings", "saveLogin", 0)
			   EndIf
			ElseIf IniRead($config, "settings", "saveLogin", 0) = 1 Then
			   saveLogin()
			EndIf

			$oIE = $test
			$isConnected = True
			$pickedServer = False
		 Else
			$selected = GUICtrlRead($CtrlServer)
			$serverId = StringRegExp($selected, "\[(\d+)\]", $STR_REGEXPARRAYMATCH)
			If IsArray($serverId) Then
			   GUICtrlSetData($CtrlChatLog, "")
			   GUICtrlSetData($CtrlRconLog, "")
			   $test = loadServer($oIE, $serverId[0])
			   If $test Then
				  $pickedServer = $serverId[0]
				  botSay("Melde mich zum Dienst. Zur Hilfe: !help")
				  GUICtrlSetData($CtrlConnect, "Ändern")
				  AdlibRegister("refreshTimer", 500)
			   EndIf
			EndIf
		 EndIf

	  Case $CtrlSubmitButton
		 Switch $lastUsedInput
			Case $CtrlUser, $CtrlPass
			   ControlClick("","", GUICtrlGetHandle($CtrlConnect))

			Case $CtrlRconSend
			   $cmd = GUICtrlRead($CtrlRconSend)
			   GUICtrlSetData($CtrlRconSend, "")
			   sendRcon($oIE, $cmd)
			   setStatus("Befehl abgeschickt")

			Case $CtrlChatSend
			   $msg = GUICtrlRead($CtrlChatSend)
			   GUICtrlSetData($CtrlChatSend, "")
			   sendRcon($oIE, "say " & $msg)
			   setStatus("Nachricht abgeschickt")

			Case $CtrlTeamA, $CtrlTeamB
			   $teamA = GUICtrlRead($CtrlTeamA)
			   $teamB = GUICtrlRead($CtrlTeamB)
			   sendRcon($oIE, "mp_teamname_1 " & $teamA)
			   sendRcon($oIE, "mp_teamname_2 " & $teamB)
			   setStatus("Team - Bezeichnungen angepasst")

		 EndSwitch

	  Case $Button2
		 setStatus("Warmup gestartet")
		 sendRcon($oIE, "exec warmup.cfg")
	  Case $Button3
		 setStatus("Knife - Round gestartet")
		 sendRcon($oIE, "exec knife.cfg")
	  Case $Button4
		 setStatus("Teamseiten getauscht")
		 sendRcon($oIE, "mp_swapteams 1")
	  Case $Button5
		 setStatus("Match gestartet")
		 sendRcon($oIE, "exec esl5on5.cfg")
   EndSwitch
WEnd

Func parseCommand($username, $msg)
   setStatus("Verarbeite " & $username & ": " & $msg)
   $msg = StringTrimLeft(StringLower($msg), 1)
   If StringInStr($msg, " ") Then
	  Local $cmds = StringSplit($msg, " ")
	  _ArrayDelete($cmds, 0)
   Else
	  Local $cmds[1] = [$msg]
   EndIf
   $params = UBound($cmds)

   Switch $cmds[0]
	  Case "help"
		 botSay("Anmeldung: !team [1 oder 2]")
		 botSay("Map - Wahl: !map [mapname]")
		 botSay("Vorbereitung: !warmup !knife !stay !switch !fix")
		 botSay("Pausen: !pause [tac oder tec] !unpause")
		 botSay("Bestaetigung: !ready !unready")

	  Case "team"
		 If $params = 1 Or Int($cmds[1]) > 2 Or Int($cmds[1]) < 1 Then
			botSay("Falsche Syntax, " & $username)
			botSay(GUICtrlRead($CtrlTeamA) & " = !team 1")
			botSay(GUICtrlRead($CtrlTeamB) & " = !team 2")
		 Else
			$team = Int($cmds[1])
			$playerlist.Item($username) = $team
			botSay($username & " ist jetzt angemeldet fuer " & getTeamName($team))
		 EndIf

	  Case "ready"
		 $team = getTeam($username)
		 If $team And StringLen($confirmReady[0]) And $confirmReady[$team] = 0 Then
			$confirmReady[$team] = 1
			botSay(getTeamName($team) & " ist bereit")

			If $confirmReady[1] = 1 And $confirmReady[2] = 1 Then
			   Switch $confirmReady[0]
				  Case "knife"
					 botSay("Messerrunde wird gestartet")
					 sendRcon($oIE, "exec knife.cfg")
				  Case "warmup"
					 botSay("Warmup wird gestartet")
					 sendRcon($oIE, "exec warmup.cfg")
				  Case "unpause"
					 sendRcon($oIE, "mp_unpause_match 1")
					 botSay("Das Match geht weiter!")
				  Case "switch"
					 sendRcon($oIE, "mp_swapteams 1")
					 sendRcon($oIE, "exec esl5on5.cfg")
					 botSay("Seiten werden getauscht und das Spiel beginnt")
				  Case "stay"
					 sendRcon($oIE, "exec esl5on5.cfg")
					 botSay("Seiten werden belassen und das Spiel beginnt")
				  Case "map"
					 botSay("Map wird zu " & $confirmReady[3] & " gewechselt")
					 sendRcon($oIE, "map " & $confirmReady[3])
					 sendRcon($oIE, "exec warmup.cfg")
					 GUICtrlSetData($CtrlTeamATacCount, 1)
					 GUICtrlSetData($CtrlTeamBTacCount, 1)
			   EndSwitch
			   $confirmReady[0] = ""
			EndIf
		 EndIf

	  Case "unready"
		 $team = getTeam($username)
		 If $team And StringLen($confirmReady[0]) And  And $confirmReady[$team] = 1 Then
			If StringLen($activePause[0]) And $activePause[1] = $team And $confirmReady[0] = "unpause" Then
			   botSay(getTeamName($team) & " kann das Ende der Pause nicht abbrechen")
			Else
			   $confirmReady[$team] = 0
			   botSay(getTeamName($team) & " ist nicht bereit")
			EndIf
		 EndIf

	  Case "knife"
		 $team = getTeam($username)
		 If $team Then
			startConfirmation("knife", $team, $username & " moechte die Messerrunde starten")
		 EndIf

	  Case "warmup"
		 $team = getTeam($username)
		 If $team Then
			startConfirmation("warmup", $team, $username & " moechte das Warmup starten")
		 EndIf

	  Case "pause"
		 If StringLen($activePause[0]) Then
			botSay("Es gibt bereits eine Pause. Du kannst diese per !unpause aufheben.")
			Return False
		 EndIf

		 $team = getTeam($username)
		 If $team Then
			If $params = 1 Or ($cmds[1] <> "tec" And $cmds[1] <> "tac") Then
			   botSay("Falsche Syntax, " & $username & ". Verwende !pause [tac oder tec]")
			ElseIf $params = 2 Or $cmds[2] <> "jetzt" Then
			   botSay("Der Pausenzaehler startet sofort beim Pausecall")
			   botSay("Die Pause sollte also erst am Ende einer Runde gecalled werden")
			   botSay("Rufe die Pause dann per !pause [tac oder tec] [jetzt] auf.")
			Else
			   $pauseObj = getPauseObj($team, $cmds[1])
			   If $cmds[1] = "tac" Then
				  $remaining = Int(GUICtrlRead($pauseObj))
				  If $remaining = 0 Then
					 botSay(getTeamName($team) & " hat keine taktischen Pausen mehr zur Verfuegung")
				  Else
					 GUICtrlSetData($pauseObj, $remaining - 1)
					 botSay(getTeamName($team) & " aktiviert eine taktische Pause")
					 startPause($cmds[1], $team, 5*60)
				  EndIf
			   Else
				  $readRemaining = GUICtrlRead($pauseObj)
				  $remaining = parseTime($readRemaining, 1)
				  If $remaining = 0 Then
					 botSay(getTeamName($team) & " hat keine technischen Pausen mehr zur Verfuegung")
				  Else
					 botSay(getTeamName($team) & " aktiviert eine technische Pause")
					 startPause($cmds[1], $team, $remaining)
				  EndIf
			   EndIf
			EndIf
		 EndIf

	  Case "unpause"
		 If Not StringLen($activePause[0]) Then
			botSay("Es gibt keine Pause welche aufgehoben werden kann")
			Return False
		 EndIf

		 $team = getTeam($username)
		 If $team Then
			If $team = $activePause[1] Then
			   endPause()
			   startConfirmation("unpause", $team, $username & " moechte die Pause beenden")
			Else
			   botSay("Nur das Team welches die Pause aktiviert hat kann diese auch wieder beenden")
			EndIf
		 EndIf

	  Case "switch"
		 $team = getTeam($username)
		 If $team Then
			startConfirmation("switch", $team, $username & " moechte dass beide Teams die Seiten wechseln und das Spiel beginnen")
		 EndIf

	  Case "stay"
		 $team = getTeam($username)
		 If $team Then
			startConfirmation("stay", $team, $username & " moechte dass beide Teams die Seiten beibehalten und das Spiel beginnen")
		 EndIf

	  Case "map"
		 $team = getTeam($username)
		 If $team Then
			If $params = 1 Then
			   botSay("Falsche Syntax, " & $username & ". Verwende !map [mapname]")
			Else
			   startConfirmation("map", $team, $username & " moechte die Karte wechseln zu " & $cmds[1], $cmds[1])
			EndIf
		 EndIf

	  Case "fix"
		 sendRcon($oIE, "exec fix.cfg")
		 botSay("Fix.cfg ausgefuehrt")

   EndSwitch
   setStatus("Fertig verarbeitet - " & $username & ": !" & $msg)
EndFunc

Func startPause($type, $team, $time)
   $activePause[0] = $type
   $activePause[1] = $team
   $activePause[2] = $time
   $activePause[3] = TimerInit()
   $activePause[4] = 0
   sendRcon($oIE, "mp_pause_match 1")
EndFunc

Func endPause()
   If $activePause[0] = "tec" Then
	  $newtime = $activePause[2] - Floor(TimerDiff($activePause[3])/1000)
	  GUICtrlSetData(getPauseObj($activePause[1], $activePause[0]), parseTime($newtime, 2))

	  If $newtime > 0 Then
		 botSay("Timer der technischen Pause gestoppt: " & parseTime($newtime, 2) & " verbleibend fuer " & getTeamName($activePause[1]))
	  EndIf
   EndIf

   $activePause[0] = ""
   $activePause[4] = 0
EndFunc

Func checkPause()
   If StringLen($activePause[0]) Then
	  $newtime = $activePause[2] - Floor(TimerDiff($activePause[3])/1000)

	  $restmins = $newtime/60
	  If Mod($newtime, 60) = 0 And $activePause[4] <> $restmins And $restmins > 0 Then
		 $activePause[4] = $restmins
		 botSay("Die Pause von " & getTeamName($activePause[1]) & " endet in spaetestens " & ($newtime/60) & " Minuten")
	  EndIf
	  If $activePause[0] = "tec" Then
		 GUICtrlSetData(getPauseObj($activePause[1], $activePause[0]), parseTime($newtime, 2))
	  EndIf
	  If $newtime <= 0 Then
		 botSay("Die Pause von " & getTeamName($activePause[1]) & " ist ausgelaufen, es geht weiter!")
		 endPause()
		 sendRcon($oIE, "mp_unpause_match 1")
	  EndIf
   EndIf
EndFunc

Func getTeam($user)
   If $playerlist.Exists($user) And ($playerlist.Item($user) = 1 Or $playerlist.Item($user) = 2) Then
	  Return $playerlist.Item($user)
   Else
	  botSay($user & ", du bist nicht angemeldet. Verwende !team [1 oder 2]")
	  Return False
   EndIf
EndFunc

Func getTeamName($team)
   If $team = 1 Then
	  Return GUICtrlRead($CtrlTeamA)
   Else
	  Return GUICtrlRead($CtrlTeamB)
   EndIf
EndFunc

Func getPauseObj($team, $type)
   If $type = "tac" Then
	  If $team = 1 Then
		 Return $CtrlTeamATacCount
	  Else
		 Return $CtrlTeamBTacCount
	  EndIf
   Else
	  If $team = 1 Then
		 Return $CtrlTeamATecTimer
	  Else
		 Return $CtrlTeamBTecTimer
	  EndIf
   EndIf
EndFunc

Func startConfirmation($key, $team, $msg, $details = "")
   If $confirmReady[0] = $key And $confirmReady[3] = $details Then
	  Return False
   EndIf
   $confirmReady[0] = $key
   $confirmReady[1] = 0
   $confirmReady[2] = 0
   $confirmReady[$team] = 1
   $confirmReady[3] = $details
   botSay($msg)
   botSay("Dieser Befehl muss vom anderen Team per !ready bestaetigt werden (Abbruch per !unready)")
EndFunc

Func parseTime($time, $way)
   If $way = 1 Then ; MM:SS zu Sekunden
	  $expl = StringSplit($time, ":")
	  Return Int($expl[1])*60 + Int($expl[2])
   ElseIf $way = 2 Then ; Sekunden zu MM:SS
	  $mins = Floor($time / 60)
	  $seks = $time - ($mins*60)
	  Return StringFormat("%02i:%02i", $mins, $seks)
   EndIf
EndFunc

Func refreshTimer()
   If $isConnected = False Or $pickedServer = False Then
	  Return AdlibUnRegister("refreshTimer")
   EndIf

   checkPause()
   If WinExists("Message from webpage") Then
	  WinClose("Message from webpage") ; Ab und zu Fehlermeldungen seitens Signaltransmitter
   EndIf

   $currentLog = getLog($oIE)
   If $currentLog <> $logCache Then
	  Local $isInit = False
	  If StringLen($logCache) Then
		 $newLog = StringReplace($currentLog, $logCache, "")
	  Else
		 $newLog = $currentLog
		 $isInit = True
	  EndIf

	  $logCache = $currentLog
	  $addEntries = StringSplit($newLog, @CRLF)
	  For $i = 1 To $addEntries[0]
		 $addEntries[$i] = StringStripWS($addEntries[$i], 3)
	  Next
	  _ArrayDelete($addEntries, 0)
	  $addStr = StringReplace(_ArrayToString($addEntries, "|"),"||", "|")
	  If StringLeft($addStr, 1) = "|" Then
		 $addstr = StringTrimLeft($addStr, 1)
	  EndIf
	  If StringRight($addStr, 1) = "|" Then
		 $addstr = StringTrimRight($addStr, 1)
	  EndIf
	  GUICtrlSetData($CtrlRconLog, $addStr & "|")
	  autoScroll($CtrlRconLog)
	  ;ConsoleWrite("NewRCON: " & $addStr & @crlf)

	  $chatContainer = ""
	  If Not $playerlist.Exists("Console") Then $playerlist.Add("Console", 0)

	  For $i = 0 To UBound($addEntries)-1
		 $row = $addEntries[$i]
		 $joined = StringRegExp($row, 'Client "(.*?)" connected', $STR_REGEXPARRAYMATCH)
		 $chat = StringRegExp($row, '(.+?): (.+)', $STR_REGEXPARRAYMATCH)
		 $teamname = StringRegExp($row, 'mp_teamname_(\d) (.+)', $STR_REGEXPARRAYMATCH)
		 ; todo: umbenennen

		 If IsArray($joined) Then
			$joined = StringStripWS($joined[0],3)
			If Not $playerlist.Exists($joined) Then $playerlist.Add($joined, 3)
		 ElseIf IsArray($chat) Then
			$chat[0] = StringStripWS($chat[0],3)
			$chat[1] = StringStripWS($chat[1],3)
			If $playerlist.Exists($chat[0]) Then
			   If StringLeft($chat[1], 1) = "!" And Not $isInit Then
				  parseCommand($chat[0], $chat[1])
			   EndIf
			   Switch $playerlist.Item($chat[0])
				  Case 0
					 $prefix = "C"
				  Case 1
					 $prefix = "A"
				  Case 2
					 $prefix = "B"
				  Case 3
					 $prefix = "?"
			   EndSwitch
			   $chatContainer = $chatContainer & "| (" & $prefix & ") " & $chat[0] & ": " & $chat[1]
			EndIf
		 ElseIf IsArray($teamname) Then
			$tid = Int($teamname[0])
			$name = StringStripWS($teamname[1], 3)

			If $tid = 1 Then
			   GUICtrlSetData($CtrlTeamA, $name)
			Else
			   GUICtrlSetData($CtrlTeamB, $name)
			EndIf
		 EndIf
	  Next
	  If StringLen($chatContainer) Then
		 GUICtrlSetData($CtrlChatLog, StringTrimLeft($chatContainer,1))
		 autoScroll($CtrlChatLog)
	  EndIf
   EndIf
EndFunc

Func botSay($msg)
   Return sendRcon($oIE, "say (BreadBot) " & $msg)
EndFunc

Func On_WM_COMMAND($hWnd, $Msg, $wParam, $lParam)
   $nNotifyCode = BitShift($wParam, 16)
   $nID = BitAnd($wParam, 0x0000FFFF)
   Switch $nNotifyCode
      Case $EN_UPDATE
		 $lastUsedInput = $nID

	  Case $EN_SETFOCUS
		 $lastUsedInput = $nID
		 If $placeholders.Exists($nID) And GUICtrlRead($nID) = $placeholders.Item($nID) Then
			GUICtrlSetData($nID, "")

			If $nID = $CtrlPass Then
			   GUICtrlSendMsg($CtrlPass, $EM_SETPASSWORDCHAR, Asc("*"), 0)
			   GUICtrlSetState($CtrlPass, $GUI_FOCUS)
			EndIf
		 EndIf

	  Case $EN_KILLFOCUS
		 $lastUsedInput = $nID
		 If $placeholders.Exists($nID) And GUICtrlRead($nID) = "" Then
			GUICtrlSetData($nID, $placeholders.Item($nID))

			If $nID = $CtrlPass Then
			   GUICtrlSendMsg($CtrlPass, $EM_SETPASSWORDCHAR, 0, 0)
			EndIf
		 EndIf
    EndSwitch
 EndFunc

Func getCryptKey()
   Return @UserName & "/" & @ComputerName & "&" & DriveGetSerial(@HomeDrive)
EndFunc

Func encrypt($str)
   $iAlgorithm = $CALG_AES_256
   $key = _Crypt_DeriveKey(getCryptKey(), $iAlgorithm)
   $enc = _Crypt_EncryptData($str, $key, $CALG_USERKEY)
   _Crypt_DestroyKey($key)

   Return $enc
EndFunc

Func decrypt($str)
   $iAlgorithm = $CALG_AES_256
   $key = _Crypt_DeriveKey(getCryptKey(), $iAlgorithm)
   $enc = _Crypt_DecryptData($str, $key, $CALG_USERKEY)
   _Crypt_DestroyKey($key)

   Return $enc
EndFunc

Func savelogin()
   IniWrite($config, "login", "username", GUICtrlRead($CtrlUser))
   IniWrite($config, "login", "password", encrypt(GUICtrlRead($CtrlPass)))
EndFunc

; ######################################################

Func onExit()
   _IEQuit($oIE)
EndFunc

Func autoScroll($list)
   _GUICtrlListBox_SetTopIndex($list, _GUICtrlListBox_GetListBoxInfo($list) - 1)
EndFunc

Func login($username, $password)
   setStatus("Anmeldung bei Signaltransmitter...")

   OnAutoItExitRegister("onExit")
   $ie = _IECreate("https://gamepanel.signaltransmitter.de/", 0, 0, 1)

   $loginForm = _IEFormGetCollection($ie, 0)
   _IEFormElementSetValue(_IEFormElementGetCollection($loginForm, 0), $username)
   _IEFormElementSetValue(_IEFormElementGetCollection($loginForm, 1), $password)
   _IEFormSubmit($loginForm)

   _IENavigate($ie, "https://gamepanel.signaltransmitter.de/userpanel.php?w=gs")
   If _IEPropertyGet($ie,"locationurl") <> "https://gamepanel.signaltransmitter.de/userpanel.php?w=gs" Then
	  setStatus("Anmeldung fehlgeschlagen")
	  Return False
   EndIf

   $showstr = "Server wählen..."
   $tags = _IETagNameGetCollection($ie, "div")
   $i = 0
   For $tag in $tags
	  If StringInStr($tag.className, "box-success") Then
		 $title = StringRegExp($tag.innerHTML, '>\d+\.\d+\.\d+\.\d+:\d+ (.*?)<', $STR_REGEXPARRAYMATCH)
		 $id = StringRegExp($tag.innerHTML, 'id=(\d+)"', $STR_REGEXPARRAYMATCH)
		 $showstr = $showstr & "|[" & $id[0] & "] " & $title[0]

		 $ftp = StringRegExp($tag.innerHTML, '<a href="(ftp:\/\/.*?)">', $STR_REGEXPARRAYMATCH)
		 $serverFTP.Add($id[0], $ftp[0])
	  EndIf
   Next

   GUICtrlSetState($CtrlServer, $GUI_ENABLE)
   GUICtrlSetState($CtrlUser, $GUI_DISABLE)
   GUICtrlSetState($CtrlPass, $GUI_DISABLE)

   GUICtrlSetData($CtrlServer, "")
   GUICtrlSetData($CtrlServer, $showstr, "Server wählen...")
   GUICtrlSetData($CtrlConnect, "Auswählen")
   setStatus("Anmeldung erfolgreich, wähle einen Server aus...")

   Return $ie
EndFunc

Func loadServer($ie, $id)
   setStatus("Übernehme Server #" & $id & "...")
   _IENavigate($ie, "https://gamepanel.signaltransmitter.de/userpanel.php?w=gs&d=sl&id=" & $id)

   $timeout = TimerInit()
   While TimerDiff($timeout) < 10*1000
	  $log = getLog($oIE)
	  If StringLen($log) Then
		 setStatus("Server #" & $id & " erfolgreich übernommen")
		 Return True
	  EndIf
   WEnd

   setStatus("Server #" & $id & " konnte nicht übernommen werden")
   Return False
EndFunc

Func sendRcon($ie, $cmd)
   If $isConnected = False Or $pickedServer = False Then
	  setStatus("Du musst dich erst verbinden bevor du Befehle ausführen kannst")
	  Return False
   EndIf
   $input = _IEGetObjById($ie, "inputCommand")
   $input.innerText = $cmd
   $oIE.document.parentwindow.execScript("submitForm();")
   Sleep(250)
EndFunc

Func getLog($ie)
   $log = _IEGetObjById($ie, "boxBody")
   $oIE.document.parentwindow.execScript("getLog();")
   Return $log.innerText

   ;$log = _INetGetSource($serverFTP.Item($pickedServer) & "/screenlog.0")
   ;Return $log
EndFunc

Func setStatus($text)
   _GUICtrlStatusBar_SetText($StatusBar1, $text)
EndFunc
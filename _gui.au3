Func initGui()
   Opt("GUIOnEventMode", 1)

   Global $lastUsedInput, $config = @ScriptDir & "\settings.ini", $placeholders

   Global $CtrlAdr, $CtrlPass, $CtrlConnect, $CtrlRconLog, $CtrlRconSend, $CtrlChatLog, $CtrlChatSend
   Global $CtrlSubmitButton, $Button2, $Button3, $Button4, $Button5, $CtrlTeamA, $CtrlTeamB
   Global $CtrlTeamATacCount, $CtrlTeamBTacCount, $CtrlTeamATecTimer, $CtrlTeamBTecTimer, $StatusBar1

   #Region ### START Koda GUI section ### Form=
   $Form1 = GUICreate("BreadBot - Dashboard", 665, 408)
   $CtrlAdr = GUICtrlCreateInput("<IP>:<Port>", 8, 8, 255, 21)
   $CtrlPass = GUICtrlCreateInput("RCON - Passwort", 270, 8, 252, 21)
   $CtrlConnect = GUICtrlCreateButton("Verbinden", 528, 7, 121, 23)
   $Group1 = GUICtrlCreateGroup("RCON", 8, 40, 313, 281)
   GUICtrlCreateGroup("", -99, -99, 1, 1)
   $CtrlRconLog = GUICtrlCreateList("", 15, 56, 298, 245, BitOR($WS_BORDER, $WS_VSCROLL))
   $CtrlRconSend = GUICtrlCreateInput("RCON Befehl...", 15, 295, 298, 17)
   $Group2 = GUICtrlCreateGroup("Chat", 336, 40, 313, 281)
   GUICtrlCreateGroup("", -99, -99, 1, 1)
   $CtrlChatLog = GUICtrlCreateList("", 345, 56, 295, 245, BitOR($WS_BORDER, $WS_VSCROLL))
   $CtrlChatSend = GUICtrlCreateInput("Nachricht an alle...", 345, 295, 295, 17)
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

   GUICtrlSetLimit($CtrlChatLog, 2000)
   GUICtrlSetLimit($CtrlRconLog, 2000)
   GUICtrlSetTip($CtrlTeamATacCount, "Taktische Pausen")
   GUICtrlSetTip($CtrlTeamBTacCount, "Taktische Pausen")
   GUICtrlSetTip($CtrlTeamATecTimer, "Technische Pausen")
   GUICtrlSetTip($CtrlTeamBTecTimer, "Technische Pausen")

   $placeholders = ObjCreate('Scripting.Dictionary')
   $placeholders.Add($CtrlRconSend, "RCON Befehl...")
   $placeholders.Add($CtrlChatSend, "Nachricht an alle...")
   $placeholders.Add($CtrlTeamA, "Team A")
   $placeholders.Add($CtrlTeamB, "Team B")
   $placeholders.Add($CtrlAdr, "<IP>:<Port>")
   $placeholders.Add($CtrlPass, "RCON - Passwort")

   GUISetOnEvent($GUI_EVENT_CLOSE, "guiExit")
   GUICtrlSetOnEvent($CtrlConnect, "guiConnect")
   GUICtrlSetOnEvent($CtrlSubmitButton, "guiInputSubmit")
   GUICtrlSetOnEvent($Button2, "guiBtnWarmup")
   GUICtrlSetOnEvent($Button3, "guiBtnKnife")
   GUICtrlSetOnEvent($Button4, "guiBtnSwap")
   GUICtrlSetOnEvent($Button5, "guiBtnStart")

   If FileExists($config) And IniRead($config,"settings", "saveLogin", 0) = 1 Then
	  $loadUser = IniRead($config, "login", "adr", "<IP>:<Port>")
	  $loadPass = IniRead($config, "login", "password", "RCON - Passwort")
	  GUICtrlSetData($CtrlAdr, $loadUser)
	  If $loadPass <> "RCON - Passwort" Then
		 GUICtrlSendMsg($CtrlPass, $EM_SETPASSWORDCHAR, Asc("*"), 0)
		 GUICtrlSetData($CtrlPass, decrypt($loadPass))
	  EndIf
   EndIf

   setStatus("Warten auf Verbindung...")
   GUIRegisterMsg($WM_COMMAND, "On_WM_COMMAND")
EndFunc

Func guiConnect()
   $serverdaten = GUICtrlRead($CtrlAdr)
   If Not StringInStr($serverdaten, ":") Then
	  setStatus("Falsches Format des Servers, korrekt ist <IP>:<port>")
   ElseIf Not $isConnected Then
	  setStatus("Verbindung wird hergestellt...")
	  $serverparts = StringSplit($serverdaten, ":")

	  GUICtrlSetState($CtrlAdr, $GUI_DISABLE)
	  GUICtrlSetState($CtrlPass, $GUI_DISABLE)
	  GUICtrlSetState($CtrlConnect, $GUI_DISABLE)

	  OnAutoItExitRegister("onExit")
	  UDPStartup()

	  $logSocket = UDPBind(@IPAddress1, $logPort)
	  If @error Then
		 $isConnected = False
		 setStatus("Port konnte nicht geöffnet werden: " & @error)
		 GUICtrlSetState($CtrlConnect, $GUI_ENABLE)
		 Return False
	  EndIf

	  $rconSocket = _SrcDSQ_RCon_Init($serverparts[1], Int($serverparts[2]), GUICtrlRead($CtrlPass))
	  If @error Then
		 $isConnected = False
		 setStatus("RCON - Verbindung konnte nicht hergestellt werden: " & @error)
		 GUICtrlSetState($CtrlConnect, $GUI_ENABLE)
		 Return False
	  EndIf
	  $extAdr = _GetIP() & ":" & $logPort
	  _SrcDSQ_RCon($rconSocket, 'log; logaddress_add "' & $extAdr & '"')
	  _SrcDSQ_RCon_Shutdown($rconSocket) ; dauerhafte verbindung geht leider nicht...

	  If Not FileExists($config) Then
		 $ask = MsgBox(32+4, "Login speichern", "Möchtest du die Serverdaten speichern?")
		 If $ask = 6 Then
			IniWrite($config, "settings", "saveLogin", 1)
			saveLogin()
		 Else
			IniWrite($config, "settings", "saveLogin", 0)
		 EndIf
	  ElseIf IniRead($config, "settings", "saveLogin", 0) = 1 Then
		 saveLogin()
	  EndIf

	  $isConnected = True
	  GUICtrlSetData($CtrlConnect, "Trennen")

	  syncTeamNames()
	  $initTeams = InputBox("Teams initialisieren", "Gib die entsprechende Zahl ein" & @crlf & "1) " & getTeamName(1) & " ist CT, " & getTeamName(1) & " ist T" & @crlf & "2) " & getTeamName(1) & " ist T, " & getTeamName(1) & " ist CT" & @crlf & "3) Nichts setzen")
	  If $initTeams = "1" Then
		 setTeamList("CT", 1)
		 setTeamList("TERRORIST", 2)
	  ElseIf $initTeams = "2" Then
		 setTeamList("CT", 1)
		 setTeamList("TERRORIST", 2)
	  EndIf

	  botSay("Stehe zur Verfügung. Mehr Informationen per !help")
	  setStatus("Verbindung erfolgreich hergestellt")
	  GUICtrlSetState($CtrlConnect, $GUI_ENABLE)
   Else
	  GUICtrlSetState($CtrlConnect, $GUI_DISABLE)
	  botSay("Verbindung wird getrennt. Bis dann.")
	  UDPCloseSocket($logSocket)
	  UDPShutdown()
	  $isConnected = False

	  GUICtrlSetData($CtrlChatLog, "")
	  GUICtrlSetData($CtrlRconLog, "")

	  GUICtrlSetState($CtrlAdr, $GUI_ENABLE)
	  GUICtrlSetState($CtrlPass, $GUI_ENABLE)
	  GUICtrlSetData($CtrlConnect, "Verbinden")
	  GUICtrlSetState($CtrlConnect, $GUI_ENABLE)
   EndIf
EndFunc

Func guiInputSubmit()
   Switch $lastUsedInput
	  Case $CtrlAdr, $CtrlPass
		 ControlClick("","", GUICtrlGetHandle($CtrlConnect))

	  Case $CtrlRconSend
		 $cmd = GUICtrlRead($CtrlRconSend)
		 GUICtrlSetData($CtrlRconSend, "")
		 setStatus("Befehl abgeschickt")
		 sendRcon($cmd)

	  Case $CtrlChatSend
		 $msg = GUICtrlRead($CtrlChatSend)
		 GUICtrlSetData($CtrlChatSend, "")
		 setStatus("Nachricht abgeschickt")
		 sendRcon("say " & $msg)
   EndSwitch
EndFunc

Func guiBtnWarmup()
   setStatus("Warmup gestartet")
   sendRcon("exec warmup.cfg")
EndFunc

Func guiBtnKnife()
   setStatus("Knife - Round gestartet")
   sendRcon("exec knife.cfg")
   $knifeRound = True
EndFunc

Func guiBtnSwap()
   setStatus("Teamseiten getauscht")
   swapTeams(True)
EndFunc

Func guiBtnStart()
   setStatus("Match gestartet")
   sendRcon("exec esl5on5.cfg")
EndFunc

Func guiExit()
   Exit
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
		 If $nID = $CtrlTeamA Or $nID = $CtrlTeamB Then
			syncTeamNames()
		 EndIf
    EndSwitch
EndFunc

Func getTeamName($team) ; 1 = erstes Team, 2 = Zweites
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

Func savelogin()
   IniWrite($config, "login", "adr", GUICtrlRead($CtrlAdr))
   IniWrite($config, "login", "password", encrypt(GUICtrlRead($CtrlPass)))
EndFunc

Func autoScroll($list)
   _GUICtrlListBox_SetTopIndex($list, _GUICtrlListBox_GetListBoxInfo($list) - 1)
EndFunc

Func setStatus($text)
   _GUICtrlStatusBar_SetText($StatusBar1, $text)
EndFunc
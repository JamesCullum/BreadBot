#NoTrayIcon
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
#include <SrcDSQLib.au3>
#include "_gui.au3" ; GUI - Teil

Global $isConnected = False, $logSocket, $logPort = 7130, $pauseState = 0, $teamScores[2], $knifeRound = False
Global $teamList = ObjCreate('Scripting.Dictionary'), $confirmReady[4], $activePause[5], $boQueue[5]

initGui()

While 1
   If $isConnected Then
	  checkPause()

	  $msg = cleanUDPRecv()
	  If $msg Then
		 ;ConsoleWrite("NewRCON: " & $msg & @crlf)
		 $nicemsg = StringTrimLeft($msg,23)
		 GUICtrlSetData($CtrlRconLog, $nicemsg & "|")
		 autoScroll($CtrlRconLog)

		 If StringInStr($msg, '>" say "') Then
			$chat = StringRegExp($msg, '"(.*?)<(\d+)><.*?><(TERRORIST|CT|Spectator|Console)>" say "(.*?)"$', $STR_REGEXPARRAYMATCH)
			If IsArray($chat) Then
			   If $teamList.Exists($chat[2]) Then
				  $team = $teamList.Item($chat[2])
			   Else
				  $team = False
			   EndIf
			   If StringLeft($chat[3], 1) = "!" Then
				  If $team Then
					 parseCommand($chat[0], $team, $chat[3])
				  Else
					 botSay("Team konnten noch nicht erkannt werden, bitte Spiel neu starten")
				  EndIf
			   EndIf
			   Local $addchat = ""
			   If $chat[2] <> "Console" Then
				  $addchat = "(" & StringReplace($chat[2],"TERRORIST", "T")
				  If $team Then $addchat &= "/T" & $team
				  $addchat &= ") " & $chat[0] & ": "
			   EndIf
			   GUICtrlSetData($CtrlChatLog, $addchat & $chat[3] & "|")
			   autoScroll($CtrlChatLog)
			EndIf
		 EndIf
		 If StringInStr($msg, ' triggered "') Then
			$npcTrigger = StringRegExp($msg, '(\w+?) triggered "(.*?)"( on |$)', $STR_REGEXPARRAYMATCH)
			If IsArray($npcTrigger) Then
			   Switch $npcTrigger[1]
				  Case "Round_Spawn"
					 $pauseState = 1
				  Case "Round_Start"
					 $pauseState = 0
				  Case "Match_Start"
					 GUICtrlSetData($CtrlTeamATacCount, 1)
					 GUICtrlSetData($CtrlTeamBTacCount, 1)
					 GUICtrlSetData($CtrlChatLog, "")
					 GUICtrlSetData($CtrlRconLog, "")
					 If $boQueue[0] And $boQueue[4] = 0 Then
						$boQueue[4] = 1
						$knifeRound = True
						startPause("bot", 0, 5*60)
						sendRcon("exec knife.cfg")
					 EndIf
				  Case "Round_End"
					 If $teamList.Exists("CT") Then
						If $knifeRound = False Then
						   If $teamScores[0] > $teamScores[1] Then
							  onScore(1)
						   ElseIf $teamScores[1] > $teamScores[0] Then
							  onScore(2)
						   Else
							  onScore(0)
						   EndIf
						Else
						   sendRcon("mp_pause_match")
						   If $teamScores[0] > $teamScores[1] Then
							  botSay(getTeamName(1) & " darf entscheiden: !stay / !switch")
							  $knifeRound = 1
						   ElseIf $teamScores[1] > $teamScores[0] Then
							  botSay(getTeamName(2) & " darf entscheiden: !stay / !switch")
							  $knifeRound = 2
						   Else
							  botSay("Kein Sieger nach der Knife? Nochmal!")
							  sendRcon("mp_unpause_match")
						   EndIf
						EndIf
					 EndIf
			   EndSwitch
			EndIf
		 EndIf
		 If StringInStr($msg, "Team playing ") Then
			$playing = StringRegExp($msg, 'Team playing "(\w+)": (.*?)$', $STR_REGEXPARRAYMATCH)
			If IsArray($playing) Then
			   If $playing[1] = getTeamName(1) Then
				  setTeamList($playing[0], 1)
				  setTeamList(sideOpposite($playing[0]), 2)
			   ElseIf $playing[1] = getTeamName(2) Then
				  setTeamList($playing[0], 2)
				  setTeamList(sideOpposite($playing[0]), 1)
			   Else
				  ConsoleWrite("Keine Ahnung welche Seite " & $playing[1] & " spielt" & @crlf)
			   EndIf
			EndIf
		 EndIf
		 If StringInStr($msg, ' scored "') Then
			$score = StringRegExp($msg, 'Team "(.*?)" scored "(\d+)" with ', $STR_REGEXPARRAYMATCH)
			If IsArray($score) And $teamList.Exists($score[0]) Then
			   $teamid = Int($teamList.Item($score[0])) - 1
			   $teamScores[$teamid] = Int($score[1])
			   ;ConsoleWrite("setScore T" & ($teamid+1) & ": " & $teamScores[$teamid] & @crlf)
			EndIf
		 EndIf
	  EndIf
   Else
	  Sleep(100)
   EndIf
WEnd

Func parseCommand($username, $team, $msg)
   setStatus("Verarbeite Befehl: " & $msg)
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
		 botSay("!fix !match !warmup !knife !stay !switch !pause !unpause")

	  Case "ready"
		 If StringLen($confirmReady[0]) And $confirmReady[$team] = 0 Then
			$confirmReady[$team] = 1
			botSay(getTeamName($team) & " ist bereit")

			If $confirmReady[1] = 1 And $confirmReady[2] = 1 Then
			   Switch $confirmReady[0]
				  Case "knife"
					 botSay("Messerrunde wird gestartet")
					 sendRcon("exec knife.cfg")
					 $knifeRound = True
				  Case "warmup"
					 botSay("Warmup wird gestartet")
					 sendRcon("exec warmup.cfg")
				  Case "unpause"
					 sendRcon("mp_unpause_match")
					 botSay("Das Match geht weiter!")
				  Case "map"
					 botSay("Map wird zu " & $confirmReady[3] & " gewechselt")
					 sendRcon("map " & $confirmReady[3])
				  Case "endmatch"
					 For $i = 0 To UBound($boQueue)-1
						$boQueue[$i] = False
					 Next
					 botSay("Match - Modus wurde abgebrochen")
				  Case "match"
					 $boQueue[0] = 1 ; Zähler
					 $boQueue[1] = $confirmReady[3] ; Maps
					 $boQueue[2] = 0 ; Score Team 1
					 $boQueue[3] = 0 ; Score Team 2
					 $boQueue[4] = 0 ; Match - State

					 $maps = StringSplit($boQueue[1], "|")
					 _ArrayDelete($maps, 0)
					 sendRcon('mp_teammatchstat_1 "0"; mp_teammatchstat_2 "0"; mp_teammatchstat_holdtime 30')
					 sendRcon('mp_teammatchstat_txt "Match 1 von ' & UBound($maps) & '"; map ' & $maps[0])
			   EndSwitch
			   $confirmReady[0] = ""
			EndIf
		 ElseIf $boQueue[0] And $activePause[0] = "bot" Then
			endPause()
			startConfirmation("unpause", $team, getTeamName($team) & " möchte beginnen")
		 EndIf

	  Case "unready"
		 If StringLen($confirmReady[0]) And $confirmReady[$team] = 1 Then
			If $activePause[1] = $team And $confirmReady[0] = "unpause" Then
			   botSay(getTeamName($team) & " kann das Ende der Pause nicht abbrechen")
			Else
			   $confirmReady[$team] = 0
			   botSay(getTeamName($team) & " ist nicht bereit")
			EndIf
		 EndIf

	  Case "stop"
		 startConfirmation("endmatch", $team, getTeamName($team) & " möchte das Match abbrechen")

	  Case "knife"
		 startConfirmation("knife", $team, getTeamName($team) & " möchte die Messerrunde starten")

	  Case "warmup"
		 startConfirmation("warmup", $team, getTeamName($team) & " möchte das Warmup starten")

	  Case "match"
		 If $params = 1 Then
			botSay("Setze nach !match alle zu spielenden Maps")
		 Else
			$mapCount = $params - 1
			$mapPool = ""
			For $i = 1 To UBound($cmds)-1
			   If StringLeft($cmds[$i], 3) <> "de_" Then
				  botSay($cmds[$i] & " ist keine gültige Map")
				  Return False
			   EndIf
			   $mapPool &= $cmds[$i] & "|"
			Next
			$mapPool = StringTrimRight($mapPool, 1)
			$dispPool = StringReplace($mapPool, "|", ", ")
			botSay(getTeamName($team) & " hat ein BO" & $mapCount & " vorgeschlagen")
			startConfirmation("match", $team, $dispPool, $mapPool)
		 EndIf

	  Case "pause"
		 If StringLen($activePause[0]) Then
			botSay("Es gibt bereits eine Pause. Du kannst diese per !unpause aufheben.")
			Return False
		 EndIf

		 If $params = 1 Or ($cmds[1] <> "tec" And $cmds[1] <> "tac") Then
			botSay("Falsche Syntax. Verwende !pause [tac oder tec]")
		 Else
			$pauseObj = getPauseObj($team, $cmds[1])
			If $cmds[1] = "tac" Then
			   $remaining = Int(GUICtrlRead($pauseObj))
			   If $remaining = 0 Then
				  botSay(getTeamName($team) & " hat keine taktischen Pausen mehr zur Verfügung")
			   Else
				  GUICtrlSetData($pauseObj, $remaining - 1)
				  botSay(getTeamName($team) & " aktiviert eine taktische Pause")
				  startPause($cmds[1], $team, 5*60)
			   EndIf
			Else
			   $readRemaining = GUICtrlRead($pauseObj)
			   $remaining = parseTime($readRemaining, 1)
			   If $remaining = 0 Then
				  botSay(getTeamName($team) & " hat keine technischen Pausen mehr zur Verfügung")
			   Else
				  botSay(getTeamName($team) & " aktiviert eine technische Pause")
				  startPause($cmds[1], $team, $remaining)
			   EndIf
			EndIf
		 EndIf

	  Case "unpause"
		 If StringLen($activePause[0]) Then
			If $team = $activePause[1] Or $activePause[1] = 0 Then
			   If $activePause[1] <> 0 Then endPause()
			   startConfirmation("unpause", $team, getTeamName($team) & " möchte die Pause beenden")
			Else
			   botSay("Nur das Team welches die Pause aktiviert hat kann diese auch wieder beenden")
			EndIf
		 EndIf

	  Case "switch"
		 If $knifeRound = $team Then
			$knifeRound = False
			swapTeams(True)
			sendRcon("mp_unpause_match; exec esl5on5.cfg")
		 EndIf

	  Case "stay"
		 If $knifeRound = $team Then
			$knifeRound = False
			sendRcon("mp_unpause_match; exec esl5on5.cfg")
		 EndIf

	  Case "map"
		 #cs
		 If $params = 1 Then
			botSay("Falsche Syntax. Verwende !map [mapname]")
		 Else
			startConfirmation("map", $team, getTeamName($team) & " möchte die Karte wechseln zu " & $cmds[1], $cmds[1])
		 EndIf
		 #ce
		 botSay("Verwende !match statt !map um direkt alle Maps zu setzen")

	  Case "fix"
		 sendRcon("exec fix.cfg")
		 botSay("Fix.cfg ausgefuehrt")

	  Case "debugcmd"
		 If $username = "Trooper[Y]" Then
			$doCmd = "!"
			For $i = 2 To UBound($cmds)-1
			   $doCmd &= $cmds[$i] & " "
			Next
			parseCommand($username, $cmds[1], $doCmd)
		 EndIf

   EndSwitch
   setStatus("Fertig verarbeitet: !" & $msg)
EndFunc

Func onScore($leader)
   $roundNum = $teamScores[0] + $teamScores[1]

   If $leader > 0 Then
	  $firstid = $leader-1
	  If $firstid = 1 Then
		 $scndid = 0
	  Else
		 $scndid = 1
	  EndIf

	  If ($teamScores[$firstid] = 16 And $teamScores[$scndid] < 15) Or ($roundNum > 31 And Mod($teamScores[$firstid],5) = 1 And $teamScores[$scndid] < $teamScores[$firstid]-1) Then
		 botSay(getTeamName($leader) & " gewinnt " & $teamScores[0] & " - " & $teamScores[1])

		 If $boQueue[0] Then
			$boQueue[0] += 1
			$boQueue[$leader+1] += 1
			$maps = StringSplit($boQueue[1], "|")
			_ArrayDelete($maps, 0)

			If $boQueue[0] > UBound($maps) Or $boQueue[$leader+1] > (UBound($maps)/2) Then
			   botSay("BO" & UBound($maps) & ": Matchergebnis " & $boQueue[2] & " - " & $boQueue[3])
			   For $i = 0 To UBound($boQueue)-1
				  $boQueue[$i] = False
			   Next
			Else
			   botSay("BO" & UBound($maps) & ": Matchstand " & $boQueue[2] & " - " & $boQueue[3])

			   $boQueue[4] = 0
			   sendRcon('mp_teammatchstat_1 "' & $boQueue[2] & '"; mp_teammatchstat_2 "' & $boQueue[3] & '";')
			   sendRcon('mp_teammatchstat_txt "Match ' & $boQueue[0] & ' von ' & UBound($maps) & '"; map ' & $maps[$boQueue[0]-1])
			EndIf
		 EndIf
	  Else
		 botSay(getTeamName($leader) & " führt " & $teamScores[0] & " - " & $teamScores[1])
	  EndIf
   Else
	  If $roundnum >= 30 And Mod($roundnum, 10) = 0 Then
		 botSay("Verlängerung bei " & $teamScores[0] & " - " & $teamScores[1])
	  Else
		 botSay("Gleichstand bei " & $teamScores[0] & " - " & $teamScores[1])
	  EndIf
   EndIf

   If $roundNum = 15 Or ($roundnum > 31 And Mod($roundnum, 5) = 0 And Mod($roundnum,10) <> 0) Then
	  swapTeams(False)
   EndIf
EndFunc

Func swapTeams($realswap)
   If $realswap Then
	  sendRcon("mp_swapteams 3")
   EndIf

   $oldCT = $teamList.Item("CT")
   $teamList.Item("CT") = $teamList.Item("TERRORIST")
   $teamList.Item("TERRORIST") = $oldCT
   ;ConsoleWrite("Swap after: CT " & $teamList.Item("CT") & " / T " & $teamList.Item("TERRORIST") & @CRLF)
EndFunc

Func sideOpposite($side)
   If $side = "CT" Then
	  Return "TERRORIST"
   Else
	  Return "CT"
   EndIf
EndFunc

Func setTeamList($side, $id)
   If $teamList.Exists($side) Then
	  $teamList.Item($side) = $id
   Else
	  $teamList.Add($side, $id)
   EndIf
EndFunc

Func startPause($type, $team, $time)
   $activePause[0] = $type
   $activePause[1] = $team
   $activePause[2] = $time
   $activePause[3] = TimerInit()
   $activePause[4] = 0
   sendRcon("mp_pause_match")
EndFunc

Func endPause()
   If $activePause[0] = "tec" Then
	  $newtime = $activePause[2] - Floor(TimerDiff($activePause[3])/1000)
	  GUICtrlSetData(getPauseObj($activePause[1], $activePause[0]), parseTime($newtime, 2))

	  If $newtime > 0 Then
		 botSay(parseTime($newtime, 2) & " verbleibend für " & getTeamName($activePause[1]))
	  EndIf
   EndIf

   $activePause[0] = ""
   $activePause[4] = 0
EndFunc

Func checkPause()
   If StringLen($activePause[0]) > 1 And $pauseState = 1 Then
	  $newtime = $activePause[2] - Floor(TimerDiff($activePause[3])/1000)

	  $restmins = $newtime/60
	  If Mod($newtime, 60) = 0 And $activePause[4] <> $restmins And $restmins > 0 Then
		 $activePause[4] = $restmins
		 If $restmins = 1 Then
			If $activePause[0] = "bot" Then
			   botSay("Die Runde startet in spätestens einer Minute (!ready)")
			Else
			   botSay("Die Pause endet in spätestens einer Minute")
			EndIf
		 Else
			If $activePause[0] = "bot" Then
			   botSay("Die Runde startet in spätestens " & $restmins & " Minuten (!ready)")
			Else
			   botSay("Die Pause endet in spätestens " & $restmins & " Minuten")
			EndIf
		 EndIf
	  EndIf
	  If $activePause[0] = "tec" Then
		 GUICtrlSetData(getPauseObj($activePause[1], $activePause[0]), parseTime($newtime, 2))
	  EndIf
	  If $newtime <= 0 Then
		 botSay("Die Pause ist ausgelaufen, es geht weiter!")
		 endPause()
		 sendRcon("mp_unpause_match")
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
   botSay("Dieser Befehl muss vom anderen Team per !ready bestätigt werden (Abbruch per !unready)")
EndFunc

Func botSay($msg)
   Return sendRcon("say (BreadBot) " & $msg)
EndFunc

Func syncTeamNames()
   $teamA = GUICtrlRead($CtrlTeamA)
   $teamB = GUICtrlRead($CtrlTeamB)
   sendRcon("mp_teamname_1 " & $teamA & "; mp_teamname_2 " & $teamB)
   setStatus("Team - Bezeichnungen angepasst")
EndFunc

; ######################################################

Func onExit()
   If $isConnected Then
	  ;sendRcon('logaddress_del "' & _GetIP() & ":" & $logPort & '"')
	  UDPCloseSocket($logSocket)
   EndIf
   UDPShutdown()
EndFunc

Func sendRcon($cmd)
   If Not $isConnected Then
	  setStatus("Du musst dich erst verbinden bevor du Befehle ausführen kannst")
	  Return False
   EndIf

   $serverdaten = GUICtrlRead($CtrlAdr)
   $serverparts = StringSplit($serverdaten, ":")
   $ret = _SrcDSQ_RCon($serverparts[1], Int($serverparts[2]), GUICtrlRead($CTrlPass), $cmd)
   #cs
   ConsoleWrite("SendRcon: " & $cmd & @crlf & "Result: (" & @error & ") <" & $ret & ">" & @CRLF)
   If Not StringLen($ret) Then
	  _ArrayDisplay($rconSocket)
   EndIf
   #ce
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

Func cleanUDPRecv()
   Local $cache = False
   $cache = UDPRecv($logSocket, 2048, 1)
   If $cache Then
	  $cache = StringTrimLeft($cache, 2)
	  $cache = __ReadHexStr($cache)
	  $cache = StringTrimLeft($cache, 6)
	  $cache = StringStripCR(StringStripWS($cache,3))
	  $cache = StringRegExpReplace($cache, '[^\w<> \-:äöüÄÖÜ"\.\!\#\/\\\(\)\?\,\[\]]', '')
	  If StringLen($cache) > 2 And Not StringInStr($cache, "SIGNALTRANSMITTER.de", 1) Then
		 Return $cache
	  EndIf
   EndIf
   Return False
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

   Return BinaryToString($enc)
EndFunc
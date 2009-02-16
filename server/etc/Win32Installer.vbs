'
' $Id: Win32Installer.vbs,v 1.19 2009/02/16 14:33:59 grubba Exp $
'
' Companion file to RoxenUI.wxs with custom actions.
'
' 2004-11-29 Henrik Grubbström
'

' At call time the CustomActionData property has been set to [TARGETDIR].
'
' Remove any previously installed service.
Function RemoveOldService()
  Dim WshShell, serverdir

  targetdir = Session.Property("CustomActionData")

  Set WshShell = CreateObject("WScript.Shell")
  WshShell.CurrentDirectory = targetdir

  WshShell.Run """" & targetdir & "ntstart"" --remove", 0, True

  RemoveOldService = 1
End Function

' At call time the CustomActionData property has been set to
' [SERVERDIR];[MYSQLBASE];[MYSQLDEXE];[MYISAMCHKEXE].
'
' Creates "[SERVERDIR]mysql-location.txt" with the
' content "basedir=[MYSQLBASE]"
'         "mysqld=[MYSQLDEXE]"
'         "myisamchk=[MYISAMCHKEXE]"
Function CreateMysqlLocation()
  Dim re, matches, match, fso, tf, serverdir, mysqlbase, mysqld, myisamchk

  serverdir = ""
  mysqlbase = ""
  mysqld = ""
  myisamchk = ""

  Set re = New RegExp
  re.Pattern = "[^;]*"
  re.Global = True
  Set matches = re.Execute(Session.Property("CustomActionData"))
  For Each match in matches
    If serverdir = "" Then
      serverdir = match.Value
    Else
      If mysqlbase = "" Then
        mysqlbase = match.Value
      Else
        If mysqld = "" Then
          mysqld = match.Value
        Else
          If myisamchk = "" Then
            myisamchk = match.Value
          End If
        End If
      End If
    End If
  Next

  Set fso = CreateObject("Scripting.FileSystemObject")

  Set tf = fso.CreateTextFile(serverdir & "mysql-location.txt", True)
  tf.writeLine("# Created by $Id: Win32Installer.vbs,v 1.19 2009/02/16 14:33:59 grubba Exp $")
  tf.writeLine("basedir=" & mysqlbase)
  If mysqld <> "" Then
    tf.writeLine("mysqld=" & mysqld)
  End If
  If myisamchk <> "" Then
    tf.writeLine("myisamchk=" & myisamchk)
  End If
  tf.Close

  CreateMysqlLocation = 1
End Function

' At call time the CustomActionData property has been set to [SERVERDIR].
'
' Creates "[SERVERDIR]pikelocation.txt" with the
' content "[SERVERDIR]pike\bin\pike"
Function CreatePikeLocation()
  Dim fso, tf, serverdir
  Set fso = CreateObject("Scripting.FileSystemObject")

  serverdir = Session.Property("CustomActionData")

  Set tf = fso.CreateTextFile(serverdir & "pikelocation.txt", True)
  tf.WriteLine(serverdir & "pike\bin\pike")
  tf.Close

  CreatePikeLocation = 1
End Function

' At call time the CustomActionData property has been set to
' [SERVERDIR];[SERVER_NAME];[SERVER_PROTOCOL];[SERVER_PORT];[ADM_USER];[ADM_PASS1]
'
' Create a new configinterface.
Function CreateConfigInterface()
  Dim re, matches, match, WshShell, serverdir
  Set re = New RegExp
  re.Pattern = "[^;]*"
  re.Global = False
  Set matches = re.Execute(Session.Property("CustomActionData"))
  For Each match in matches
    serverdir = match.Value
  Next

  Set WshShell = CreateObject("WScript.Shell")
  WshShell.Run """" & serverdir & "pike\bin\pike"" """ & serverdir &_
    "bin\create_configif.pike"" --batch __semicolon_separated__ """ &_
    Session.Property("CustomActionData") & """ ok y update n", 0, True

  CreateConfigInterface = 1
End Function

Function CreateEnvironment()
  Dim envfile, fso, tf
  Set fso = CreateObject("Scripting.FileSystemObject")

  envfile = Session.Property("CustomActionData")

  If (Not fso.FileExists(envfile)) Then
    Set tf = fso.CreateTextFile(envfile, True)
    tf.WriteLine("[Parameters]")
    tf.WriteLine("default= ")
    tf.WriteLine("[Environment]")
    tf.WriteLine("_JAVA_OPTIONS=-Xmx256M")
    tf.Close
  End If
End Function

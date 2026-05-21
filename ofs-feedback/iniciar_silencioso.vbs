' iniciar_silencioso.vbs
' Executa o iniciar.bat sem mostrar janela (usado pelo autostart do Windows).
' Os servicos (PostgreSQL, FastAPI, serve.py) continuam rodando em background.

Set WshShell = CreateObject("WScript.Shell")
strPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = strPath
' 0 = janela oculta, False = nao espera terminar
WshShell.Run Chr(34) & strPath & "\iniciar.bat" & Chr(34) & " /auto", 0, False
Set WshShell = Nothing

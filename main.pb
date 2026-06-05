; epicASM v1.00 (not done)
; PureBasic 4.61

Enumeration
  #Win
  #Log
  #Status
  #BtnFile
  #BtnDisasm
  #BtnBuild
  #BtnCancel
  #FileText
  #Arch
  #Backend
  #ArchLabel
  #BackendLabel
  #ChkNoAddr
  #ChkEntry
EndEnumeration

Global inputFile$, taskActive = 0, taskProcess = 0

Procedure AddLog(txt$)
  SendMessage_(GadgetID(#Log), #EM_SETSEL, -1, -1)
  SendMessage_(GadgetID(#Log), #EM_REPLACESEL, 0, txt$ + #CRLF$)
EndProcedure

Procedure UpdateStatus(msg$)
  SetGadgetText(#Status, msg$)
EndProcedure

Procedure KillTask()
  If taskProcess
    KillProgram(taskProcess)
    taskProcess = 0
  EndIf
  taskActive = 0
  UpdateStatus("Cancelled")
  AddLog("*** Cancelled by user ***")
  DisableGadget(#BtnCancel, 1)
  DisableGadget(#BtnDisasm, 0)
  DisableGadget(#BtnBuild, 0)
EndProcedure

Procedure.s CheckTool(tool$)
  If FileSize(tool$) <= 0
    AddLog("ERROR: " + tool$ + " not found in " + GetCurrentDirectory())
    ProcedureReturn ""
  EndIf
  ProcedureReturn tool$
EndProcedure

Procedure.s ShortPath(fullPath$)
  Protected short$, len
  short$ = Space(#MAX_PATH)
  len = GetShortPathName_(@fullPath$, @short$, #MAX_PATH)
  If len > 0 And len <= #MAX_PATH
    ProcedureReturn Left(short$, len)
  EndIf
  ProcedureReturn fullPath$
EndProcedure

Procedure RunCmdSilent(cmd$, logFile$, timeout = 60000)
  Protected prog, exitCode, start = GetTickCount_(), elapsed
  prog = RunProgram("cmd.exe", "/c " + cmd$, "", #PB_Program_Open | #PB_Program_Hide)
  If prog = 0
    AddLog("ERROR: can't create cmd.exe process")
    ProcedureReturn -1
  EndIf
  taskProcess = prog
  taskActive = 1
  While ProgramRunning(prog) And taskActive
    Delay(50)
    elapsed = GetTickCount_() - start
    If elapsed > timeout
      KillProgram(prog)
      AddLog("ERROR: timeout after " + Str(timeout/1000) + " sec")
      taskProcess = 0 : taskActive = 0
      ProcedureReturn -2
    EndIf
    While WindowEvent() : Wend
  Wend
  exitCode = ProgramExitCode(prog)
  CloseProgram(prog)
  taskProcess = 0
  If taskActive = 0
    ProcedureReturn -3
  EndIf
  taskActive = 0
  ProcedureReturn exitCode
EndProcedure

Procedure ShowLogFile(logFile$)
  If FileSize(logFile$) > 0
    AddLog("--- Tool output ---")
    If ReadFile(0, logFile$)
      While Eof(0) = 0
        AddLog(ReadString(0))
      Wend
      CloseFile(0)
    EndIf
    AddLog("--- End ---")
  EndIf
EndProcedure

Procedure StripAddresses(inFile$, outFile$)
  If ReadFile(0, inFile$) = 0 : ProcedureReturn 0 : EndIf
  If CreateFile(1, outFile$) = 0 : CloseFile(0) : ProcedureReturn 0 : EndIf
  While Eof(0) = 0
    line$ = ReadString(0)
    If Len(line$) > 28
      line$ = Mid(line$, 29)
    Else
      line$ = ""
    EndIf
    WriteStringN(1, line$)
  Wend
  CloseFile(0)
  CloseFile(1)
  ProcedureReturn 1
EndProcedure

; Detect bitness from PE header, returns 0=16bit, 1=32bit, 2=64bit, -1=unknown
Procedure DetectArchitecture(file$)
  If ReadFile(0, file$)
    ; Check MZ signature
    Protected mz.w
    ReadData(0, @mz, 2)
    If mz <> $5A4D  ; 'MZ' in little-endian
      CloseFile(0)
      ProcedureReturn -1
    EndIf
    ; Seek to PE offset at 0x3C
    FileSeek(0, $3C)
    Protected peOffset.l
    ReadData(0, @peOffset, 4)
    If peOffset <= 0 Or peOffset >= Lof(0)
      CloseFile(0)
      ProcedureReturn -1
    EndIf
    FileSeek(0, peOffset)
    ; Check PE\0\0 signature
    Protected sig.l
    ReadData(0, @sig, 4)
    If sig <> $00004550  ; 'PE\0\0'
      CloseFile(0)
      ProcedureReturn -1
    EndIf
    ; Skip FileHeader (20 bytes) and first 2 bytes of OptionalHeader (Magic)
    FileSeek(0, Loc(0) + 20 + 2)
    Protected machine.w
    ReadData(0, @machine, 2)
    CloseFile(0)
    Select machine
      Case $014C  ; i386
        ProcedureReturn 1
      Case $8664  ; AMD64
        ProcedureReturn 2
      Default
        ProcedureReturn -1
    EndSelect
  EndIf
  ProcedureReturn -1
EndProcedure

Procedure DoDisasm()
  If inputFile$ = "" : AddLog("No input file") : ProcedureReturn : EndIf
  If FileSize(inputFile$) <= 0 : AddLog("Input file not found: " + inputFile$) : ProcedureReturn : EndIf

  AddLog("--- Disassembling: " + inputFile$)
  UpdateStatus("Disassembling...")
  DisableGadget(#BtnDisasm, 1) : DisableGadget(#BtnBuild, 1) : DisableGadget(#BtnCancel, 0)

  ; Output name: <name>_build.asm
  Protected baseName$ = GetFilePart(inputFile$)
  Protected dot = 0, i
  For i = Len(baseName$) To 1 Step -1
    If Mid(baseName$, i, 1) = "."
      dot = i
      Break
    EndIf
  Next
  If dot > 0
    baseName$ = Left(baseName$, dot - 1)
  EndIf
  Protected outputAsm$ = GetPathPart(inputFile$) + baseName$ + "_build.asm"
  Protected logFile$    = GetPathPart(inputFile$) + baseName$ + "_disasm.log"

  arch = GetGadgetState(#Arch)
  backend = GetGadgetState(#Backend)
  strip = GetGadgetState(#ChkNoAddr)

  shortIn$   = ShortPath(inputFile$)
  shortOut$  = ShortPath(outputAsm$)
  shortLog$  = ShortPath(logFile$)

  If backend = 0
    tool$ = CheckTool("nasm\ndisasm.exe")
    If tool$ = "" : Goto error : EndIf
    shortTool$ = ShortPath(tool$)
    Select arch
      Case 0 : bits$ = "16"
      Case 1 : bits$ = "32"
      Case 2 : bits$ = "64"
    EndSelect
    cmd$ = shortTool$ + " -b " + bits$ + " -o 0x0 " + shortIn$ + " > " + shortOut$ + " 2>" + shortLog$
  Else
    tool$ = CheckTool("mingw\objdump.exe")
    If tool$ = "" : Goto error : EndIf
    shortTool$ = ShortPath(tool$)
    Select arch
      Case 0 : machine$ = "i8086"
      Case 1 : machine$ = "i386"
      Case 2 : machine$ = "i386:x86-64"
    EndSelect
    cmd$ = shortTool$ + " -D -M intel -b binary -m " + machine$ + " --start-address=0 " + shortIn$ + " > " + shortOut$ + " 2>" + shortLog$
  EndIf

  rc = RunCmdSilent(cmd$, logFile$, 60000)

  If rc = -1
    AddLog("Failed to start command")
  ElseIf rc = -2
    AddLog("Timeout")
  ElseIf rc = -3
    AddLog("Cancelled")
  ElseIf rc = 0
    If FileSize(outputAsm$) <= 0
      AddLog("ERROR: disassembly produced empty file. Tool output:")
      ShowLogFile(logFile$)
      UpdateStatus("Disassembly failed (empty output)")
    Else
      If strip
        temp$ = outputAsm$ + ".tmp"
        If StripAddresses(outputAsm$, temp$)
          DeleteFile(outputAsm$)
          RenameFile(temp$, outputAsm$)
          AddLog("Addresses stripped")
        Else
          AddLog("Warning: could not strip addresses")
        EndIf
      EndIf
      AddLog("SUCCESS: " + outputAsm$)
      UpdateStatus("Ready. Asm saved: " + outputAsm$)
    EndIf
  Else
    AddLog("ERROR: exit code " + Str(rc))
    ShowLogFile(logFile$)
    UpdateStatus("Disassembly failed")
  EndIf
  Goto cleanup

error:
  AddLog("Aborted due to missing tool")
cleanup:
  DisableGadget(#BtnCancel, 1)
  DisableGadget(#BtnDisasm, 0)
  DisableGadget(#BtnBuild, 0)
EndProcedure

Procedure DoBuild()
  ; Smart .asm selection using current inputFile$
  Protected asmFile$ = ""
  If inputFile$ <> ""
    ext$ = LCase(GetExtensionPart(inputFile$))
    If ext$ = "asm"
      asmFile$ = inputFile$
    Else
      ; Try same-name .asm
      Protected baseName$ = GetFilePart(inputFile$)
      Protected dot = 0, i
      For i = Len(baseName$) To 1 Step -1
        If Mid(baseName$, i, 1) = "."
          dot = i
          Break
        EndIf
      Next
      If dot > 0
        baseName$ = Left(baseName$, dot - 1)
      EndIf
      Protected candidate$ = GetPathPart(inputFile$) + baseName$ + ".asm"
      If FileSize(candidate$) > 0
        asmFile$ = candidate$
      Else
        ; Try _build.asm (disasm output with new naming)
        candidate$ = GetPathPart(inputFile$) + baseName$ + "_build.asm"
        If FileSize(candidate$) > 0
          asmFile$ = candidate$
        Else
          ; Also try old disasm_output.asm for backwards compatibility
          candidate$ = GetPathPart(inputFile$) + "disasm_output.asm"
          If FileSize(candidate$) > 0
            asmFile$ = candidate$
          EndIf
        EndIf
      EndIf
    EndIf
  EndIf

  If asmFile$ = ""
    asmFile$ = OpenFileRequester("Select .asm file to build", "", "ASM|*.asm", 0)
    If asmFile$ = "" : ProcedureReturn : EndIf
  EndIf

  If FileSize(asmFile$) <= 0 : AddLog("ASM file not found") : ProcedureReturn : EndIf

  AddLog("--- Building: " + asmFile$)
  UpdateStatus("Building...")
  DisableGadget(#BtnDisasm, 1) : DisableGadget(#BtnBuild, 1) : DisableGadget(#BtnCancel, 0)

  arch = GetGadgetState(#Arch)
  If arch = 0
    fmt$ = "bin"
    outExt$ = ".com"
    linkerNeeded = 0
  ElseIf arch = 1
    fmt$ = "win32"
    outExt$ = ".exe"
    linkerNeeded = 1
  ElseIf arch = 2
    fmt$ = "win64"
    outExt$ = ".exe"
    linkerNeeded = 1
  EndIf

  ; Base name for output files: <name>_disasm
  Protected name$ = GetFilePart(asmFile$)
  Protected dot = 0, i
  For i = Len(name$) To 1 Step -1
    If Mid(name$, i, 1) = "."
      dot = i
      Break
    EndIf
  Next
  If dot > 0
    name$ = Left(name$, dot - 1)
  EndIf
  Protected base$   = GetPathPart(asmFile$) + name$
  Protected finalAsm$ = asmFile$
  Protected tempAsm$  = base$ + "_with_entry.asm"
  Protected autoEntry = GetGadgetState(#ChkEntry)

  ; --- Entry point handling ---
  If linkerNeeded And autoEntry
    Protected hasStart  = 0, hasGlobal = 0
    If ReadFile(2, asmFile$)
      While Eof(2) = 0
        line$ = Trim(ReadString(2))
        If LCase(line$) = "start:" Or Left(LCase(line$), 7) = "start: "
          hasStart = 1
        EndIf
        If LCase(line$) = "global start" Or LCase(line$) = "global start"
          hasGlobal = 1
        EndIf
      Wend
      CloseFile(2)
    EndIf

    If Not hasStart
      If CreateFile(3, tempAsm$)
        WriteStringN(3, "global start")
        WriteStringN(3, "start:")
        If ReadFile(2, asmFile$)
          While Eof(2) = 0
            WriteStringN(3, ReadString(2))
          Wend
          CloseFile(2)
        EndIf
        CloseFile(3)
        finalAsm$ = tempAsm$
        AddLog("Added 'start:' entry point")
      EndIf
    ElseIf Not hasGlobal
      If CreateFile(3, tempAsm$)
        WriteStringN(3, "global start")
        If ReadFile(2, asmFile$)
          While Eof(2) = 0
            WriteStringN(3, ReadString(2))
          Wend
          CloseFile(2)
        EndIf
        CloseFile(3)
        finalAsm$ = tempAsm$
        AddLog("Added 'global start'")
      EndIf
    EndIf
  EndIf

  Protected obj$ = base$ + ".obj"
  Protected exe$ = base$ + "_disasm" + outExt$

  ; --- NASM ---
  nasm$ = CheckTool("nasm\nasm.exe")
  If nasm$ = "" : Goto build_error : EndIf
  Protected nasmLog$ = base$ + "_nasm.log"
  cmd1$ = ShortPath(nasm$) + " -f " + fmt$ + " " + ShortPath(finalAsm$) + " -o " + ShortPath(obj$) + " > " + ShortPath(nasmLog$) + " 2>&1"
  rc = RunCmdSilent(cmd1$, nasmLog$, 30000)
  If rc <> 0
    AddLog("NASM error (code " + Str(rc) + "):")
    ShowLogFile(nasmLog$)
    Goto build_error
  EndIf

  ; --- Link ---
  If linkerNeeded = 0
    ; 16-bit COM
    If FileSize(exe$) > 0 : DeleteFile(exe$) : EndIf
    If RenameFile(obj$, exe$)
      AddLog("BUILD SUCCESS: " + exe$)
      UpdateStatus("Ready: " + exe$)
    Else
      AddLog("Error renaming " + obj$ + " to " + exe$)
      UpdateStatus("Build error")
    EndIf
  Else
    If FileSize(exe$) > 0
      If DeleteFile(exe$) = 0
        AddLog("ERROR: Cannot delete existing file: " + exe$)
        AddLog("File may be running or access denied.")
        Goto build_error
      EndIf
    EndIf

    link$ = CheckTool("golink\golink.exe")
    If link$ = "" : Goto build_error : EndIf
    Protected linkLog$ = base$ + "_link.log"
    cmd2$ = ShortPath(link$) + " /entry:start " + ShortPath(obj$) + " kernel32.dll user32.dll /console /out:" + ShortPath(exe$) + " > " + ShortPath(linkLog$) + " 2>&1"
    rc = RunCmdSilent(cmd2$, linkLog$, 30000)

    If rc = 0
      AddLog("BUILD SUCCESS: " + exe$)
      UpdateStatus("Ready: " + exe$)
    Else
      AddLog("Linker error (code " + Str(rc) + "):")
      ShowLogFile(linkLog$)
      UpdateStatus("Build error")
    EndIf
  EndIf

  If finalAsm$ <> asmFile$ And FileSize(finalAsm$) > 0
    DeleteFile(finalAsm$)
  EndIf
  Goto build_cleanup

build_error:
  UpdateStatus("Build aborted")
build_cleanup:
  DisableGadget(#BtnCancel, 1)
  DisableGadget(#BtnDisasm, 0)
  DisableGadget(#BtnBuild, 0)
EndProcedure

Procedure SetInputFile(f$)
  inputFile$ = f$
  SetGadgetText(#FileText, f$)
  DisableGadget(#BtnDisasm, 0)
  AddLog("Selected: " + f$)

  ; Auto-detect bitness from PE header
  arch = DetectArchitecture(f$)
  If arch >= 0
    SetGadgetState(#Arch, arch)
    AddLog("Architecture auto-detected: " + Str(arch))
  EndIf
EndProcedure

Procedure WinCallback(hWnd, msg, wParam, lParam)
  If msg = #WM_DROPFILES
    Protected cnt = DragQueryFile_(wParam, -1, 0, 0), buf, file$
    If cnt > 0
      buf = AllocateMemory(512)
      If buf
        DragQueryFile_(wParam, 0, buf, 512)
        file$ = PeekS(buf)
        FreeMemory(buf)
        SetInputFile(file$)
      EndIf
    EndIf
    DragFinish_(wParam)
    ProcedureReturn 0
  EndIf
  ProcedureReturn #PB_ProcessPureBasicEvents
EndProcedure

; ========== Classic Win98 look ==========
If OSVersion() >= #PB_OS_Windows_XP
  lib = OpenLibrary(#PB_Any, "uxtheme.dll")
  If lib
    CallFunction(lib, "SetThemeAppProperties", 0)
    CloseLibrary(lib)
  EndIf
EndIf

LoadFont(0, "MS Sans Serif", 8)
SetGadgetFont(#PB_Default, FontID(0))

OpenWindow(#Win, 0, 0, 570, 430, "epicASM v1.00 - Classic", #PB_Window_SystemMenu | #PB_Window_MinimizeGadget | #PB_Window_ScreenCentered)
SetWindowCallback(@WinCallback())
SetWindowColor(#Win, RGB(192,192,192))

CreateGadgetList(WindowID(#Win))

EditorGadget(#Log, 5, 5, 560, 260, #PB_Editor_ReadOnly)
SetGadgetColor(#Log, #PB_Gadget_BackColor, RGB(255,255,255))
SetGadgetColor(#Log, #PB_Gadget_FrontColor, RGB(0,0,0))

TextGadget(#Status, 5, 270, 560, 20, "Ready. Drag & drop a binary file", #PB_Text_Border)
SetGadgetColor(#Status, #PB_Gadget_BackColor, RGB(192,192,192))

ButtonGadget(#BtnFile, 5, 300, 70, 25, "Browse")
TextGadget(#FileText, 80, 305, 420, 20, "", #PB_Text_Border)
SetGadgetColor(#FileText, #PB_Gadget_BackColor, RGB(255,255,255))

ButtonGadget(#BtnDisasm, 5, 335, 100, 25, "Disassemble")
ButtonGadget(#BtnBuild, 110, 335, 100, 25, "Build")
ButtonGadget(#BtnCancel, 215, 335, 70, 25, "Cancel")

TextGadget(#ArchLabel, 5, 370, 40, 20, "Arch:", #PB_Text_Border)
SetGadgetColor(#ArchLabel, #PB_Gadget_BackColor, RGB(192,192,192))
ComboBoxGadget(#Arch, 50, 368, 60, 100)
AddGadgetItem(#Arch, -1, "16")
AddGadgetItem(#Arch, -1, "32")
AddGadgetItem(#Arch, -1, "64")
SetGadgetState(#Arch, 1)

TextGadget(#BackendLabel, 120, 370, 55, 20, "Backend:", #PB_Text_Border)
SetGadgetColor(#BackendLabel, #PB_Gadget_BackColor, RGB(192,192,192))
ComboBoxGadget(#Backend, 180, 368, 80, 100)
AddGadgetItem(#Backend, -1, "ndisasm")
AddGadgetItem(#Backend, -1, "objdump")
SetGadgetState(#Backend, 0)

CheckBoxGadget(#ChkNoAddr, 280, 370, 120, 20, "Strip addresses")
SetGadgetColor(#ChkNoAddr, #PB_Gadget_BackColor, RGB(192,192,192))

CheckBoxGadget(#ChkEntry, 410, 370, 150, 20, "Add entry point (start:)")
SetGadgetColor(#ChkEntry, #PB_Gadget_BackColor, RGB(192,192,192))
SetGadgetState(#ChkEntry, 1)

DisableGadget(#BtnDisasm, 1)
DisableGadget(#BtnCancel, 1)
DragAcceptFiles_(WindowID(#Win), #True)

AddLog("Current directory: " + GetCurrentDirectory())
AddLog("Checking tools...")
CheckTool("nasm\ndisasm.exe")
CheckTool("mingw\objdump.exe")
CheckTool("nasm\nasm.exe")
CheckTool("golink\golink.exe")

Repeat
  ev = WaitWindowEvent()
  Select ev
    Case #PB_Event_CloseWindow
      If taskActive : KillTask() : Delay(200) : EndIf
      Break
    Case #PB_Event_Gadget
      Select EventGadget()
        Case #BtnFile
          f$ = OpenFileRequester("Open binary file", "", "*.*", 0)
          If f$ : SetInputFile(f$) : EndIf
        Case #BtnDisasm
          If Not taskActive : DoDisasm() : EndIf
        Case #BtnBuild
          If Not taskActive : DoBuild() : EndIf
        Case #BtnCancel
          If taskActive : KillTask() : EndIf
      EndSelect
  EndSelect
ForEver
End

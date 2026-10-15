#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Автозагрузка: при каждом запуске обновляем ярлык в папке автозагрузки Windows,
; чтобы программа стартовала вместе с системой без доп. действий.
try FileCreateShortcut(A_ScriptFullPath, A_Startup "\LayoutSwitch.lnk", A_ScriptDir)
A_IconTip := "LayoutSwitch: Ctrl+\ меняет раскладку набранного текста"
; Ctrl+\  -> перевести только что набранный текст в другую раскладку (RU <-> EN)
;           и переключить раскладку, чтобы можно было продолжать печатать.
; Если буфер пуст, а в приложении выделен текст, будет сконвертировано выделение.

en := "qwertyuiop[]asdfghjkl;'zxcvbnm,./``QWERTYUIOP{}ASDFGHJKL:`"ZXCVBNM<>?~@#$^&"
ru := "йцукенгшщзхъфывапролджэячсмитьбю.ёЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,Ё`"№;:?"

enToRu := Map()
ruToEn := Map()
Loop Parse, en
{
    e := A_LoopField
    r := SubStr(ru, A_Index, 1)
    enToRu[e] := r
    ruToEn[r] := e
}

typed := ""

ih := InputHook("V")
ih.OnChar := OnChar
ih.OnKeyDown := OnResetKey
ih.KeyOpt("{Backspace}", "N")
ih.KeyOpt("{Enter}{NumpadEnter}{Tab}{Esc}{Left}{Right}{Up}{Down}{Home}{End}{Delete}{PgUp}{PgDn}", "N")
ih.Start()

OnChar(hook, char) {
    global typed
    if Ord(char) >= 32
        typed .= char
}

OnResetKey(hook, vk, sc) {
    global typed
    if (vk = 0x08)            ; Backspace
        typed := SubStr(typed, 1, -1)
    else
        typed := ""
}

~LButton::
~RButton::
~MButton:: {
    global typed
    typed := ""
}

GetLangId() {
    hwnd := WinExist("A")
    thread := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    hkl := DllCall("GetKeyboardLayout", "UInt", thread, "Ptr")
    return hkl & 0xFFFF
}

SetLayout(toRussian) {
    id := toRussian ? "00000419" : "00000409"
    hkl := DllCall("LoadKeyboardLayout", "Str", id, "UInt", 1, "Ptr")
    PostMessage(0x50, 0, hkl, , "A")   ; WM_INPUTLANGCHANGEREQUEST
}

Convert(text, toRussian) {
    global enToRu, ruToEn
    m := toRussian ? enToRu : ruToEn
    out := ""
    Loop Parse, text
        out .= m.Has(A_LoopField) ? m[A_LoopField] : A_LoopField
    return out
}

$^sc02B:: {                         ; Ctrl + \ (клавиша обратной косой черты)
    global typed
    KeyWait "Ctrl"                  ; дождаться отпускания Ctrl, иначе Backspace удалит слова
    Sleep 30

    if (typed != "") {
        ; направление определяем по текущей раскладке
        toRussian := (GetLangId() != 0x419)
        converted := Convert(typed, toRussian)
        SendInput "{Backspace " StrLen(typed) "}"
        SendText converted
        SetLayout(toRussian)
        typed := converted
        return
    }

    ; запасной вариант: конвертация выделенного текста
    saved := ClipboardAll()
    A_Clipboard := ""
    SendInput "^c"
    if !ClipWait(0.5) {
        A_Clipboard := saved
        return
    }
    sel := A_Clipboard
    hasCyr := RegExMatch(sel, "[а-яёА-ЯЁ]")
    toRussian := !hasCyr
    converted := Convert(sel, toRussian)
    A_Clipboard := converted
    SendInput "^v"
    Sleep 150
    A_Clipboard := saved
    SetLayout(toRussian)
}

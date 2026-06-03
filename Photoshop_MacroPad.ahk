; ==============================================================================
; Название: Photoshop MacroPad Pro Control
; Автор: andrey-arttech
; Версия: 3.0 (С графическим HUD и палитрой на 32 цвета)
; Лицензия: MIT
; Описание: Скрипт для 12-клавишного макропада с 3 энкодерами.
;           Прямая интеграция с PS через COM, интерактивная пипетка,
;           синхронизация инструментов и визуальный HUD.
; ==============================================================================

#NoEnv
#SingleInstance Force
SetBatchLines, -1 ; Максимальная скорость выполнения скрипта AHK

; --- КАСТОМИЗАЦИЯ И ПОДПИСЬ В СИСТЕМЕ ---
Menu, Tray, Tip, PS MacroPad Pro by [andrey-arttech]

; --- АВТО-ЗАПРОС ПРАВ АДМИНИСТРАТОРА ---
if not A_IsAdmin
{
   Run *RunAs "%A_ScriptFullPath%"
   ExitApp
}

; Приветственное уведомление при успешном запуске
ToolTip, 🎨 PS MacroPad Controller v3.0`nГрафический HUD успешно запущен!
SetTimer, RemoveToolTip, -3000

; --- БЛОК ИНИЦИАЛИЗАЦИИ ГЛОБАЛЬНЫХ ПЕРЕМЕННЫХ ---
global ToolToggle := 1 
global Mode_Knob1 := "Color"
global Mode_Knob2 := "Color"
global Mode_Knob3 := "Color"
global VisualSize := 5 
global OpacityIndex := 10 
global HardnessIndex := 4 

; Накопительные буферы для изменений параметров цвета
global HueBuffer := 0
global SaturationBuffer := 0
global BrightnessBuffer := 0

; Глобальные переменные для интерактивной пипетки
global Old_H := 0
global Old_S := 0
global Old_B := 0
global AltPressed := 0

; Переменные графического интерфейса HUD
global HudTextCtrl, HudColorCtrl, HudColorCtrlBackground, HudInitialized := false

#IfWinActive ahk_exe Photoshop.exe ; --- ВСЕ КЛАВИШИ НИЖЕ РАБОТАЮТ ТОЛЬКО В PHOTOSHOP ---

; --- ИНТЕРАКТИВНАЯ ПИПЕТКА (ОПТИМИЗИРОВАННАЯ ПОД ГРАФИЧЕСКИЕ ПЛАНШЕТЫ) ---

~*Alt::
    if (AltPressed = 1) 
        return
    if (!IsBrushOrEraser())
        return
    AltPressed := 1
    GetRawHSB(Old_H, Old_S, Old_B)
return

~*Alt Up::
    AltPressed := 0
return

~*~LButton::
    if (AltPressed = 0) 
        return
    GoSub, ProcessColorSample
return

~*!LButton::
    if (AltPressed = 0) 
        return
    GoSub, ProcessColorSample
return

ProcessColorSample:
    Sleep, 180 
    GetRawHSB(new_H, new_S, new_B)
    
    if (new_H = 0 && new_S = 0 && new_B = 0 && Old_B > 15) {
        AltPressed := 0
        return
    }
    
    diff_H := new_H - Old_H
    diff_S := new_S - Old_S
    diff_B := new_B - Old_B
    
    str_diff_H := (diff_H > 0) ? "▲" . diff_H . "°" : (diff_H < 0) ? "▼" . Abs(diff_H) . "°" : "="
    str_diff_S := (diff_S > 0) ? "▲" . diff_S . "%" : (diff_S < 0) ? "▼" . Abs(diff_S) . "%" : "="
    str_diff_B := (diff_B > 0) ? "▲" . diff_B . "%" : (diff_B < 0) ? "▼" . Abs(diff_B) . "%" : "="
    
    HSB_to_RGB(new_H, new_S, new_B, R, G, B)
    newName := ParseExtendedColor(new_H, new_S, new_B)
    
    hudText := "🎨 " . newName . "`n"
            . "⭕ " . ToBold(new_H) . "° [" . str_diff_H . "] | 💧 " . ToBold(new_S) . "% [" . str_diff_S . "] | 💡 " . ToBold(new_B) . "% [" . str_diff_B . "]`n"
            . "🖥️ RGB: [" . R . ", " . G . ", " . B . "]"
            
    ShowTip(hudText, R, G, B, true)
    
    Old_H := new_H
    Old_S := new_S
    Old_B := new_B
return

; --- РУЧКА 1 (ТОН / НЕПРОЗРАЧНОСТЬ КИСТИ) ---
F20:: 
    Mode_Knob1 := (Mode_Knob1 = "Color") ? "Opacity" : "Color"
    ShowTip("РУЧКА 1: " . (Mode_Knob1 = "Color" ? "ТОН" : "НЕПРОЗРАЧНОСТЬ"))
return

F13:: 
    if (Mode_Knob1 = "Color") {
        HueBuffer -= 2 
        SetTimer, ApplyHue, -120 
    } else {
        OpacityIndex--
        if (OpacityIndex < 1) 
            OpacityIndex := 1
        Send % (OpacityIndex = 10 ? "0" : OpacityIndex)
        ShowTip("НЕПРОЗРАЧНОСТЬ: " . OpacityIndex * 10 . "%")
    }
return

F14:: 
    if (Mode_Knob1 = "Color") {
        HueBuffer += 2
        SetTimer, ApplyHue, -120
    } else {
        OpacityIndex++
        if (OpacityIndex > 10) 
            OpacityIndex := 10
        Send % (OpacityIndex = 10 ? "0" : OpacityIndex)
        ShowTip("НЕПРОЗРАЧНОСТЬ: " . OpacityIndex * 10 . "%")
    }
return

; --- РУЧКА 2 (НАСЫЩЕННОСТЬ / ЖЕСТКОСТЬ КИСТИ) ---
F21:: 
    Mode_Knob2 := (Mode_Knob2 = "Color") ? "Hardness" : "Color"
    ShowTip("РУЧКА 2: " . (Mode_Knob2 = "Color" ? "НАСЫЩЕННОСТЬ" : "ЖЕСТКОСТЬ"))
return

F15:: 
    if (Mode_Knob2 = "Color") {
        SaturationBuffer -= 2
        SetTimer, ApplySaturation, -120
    } else {
        if (HardnessIndex > 0) {
            HardnessIndex--
            Send {Shift down}
            Send {[}
            Send {Shift up}
        }
        ShowTip("ЖЕСТКОСТЬ: " . HardnessIndex * 25 . "%")
    }
return

F16:: 
    if (Mode_Knob2 = "Color") {
        SaturationBuffer += 2
        SetTimer, ApplySaturation, -120
    } else {
        if (HardnessIndex < 4) {
            HardnessIndex++
            Send {Shift down}
            Send {]}
            Send {Shift up}
        }
        ShowTip("ЖЕСТКОСТЬ: " . HardnessIndex * 25 . "%")
    }
return

; --- РУЧКА 3 (ЯРКОСТЬ / РАЗМЕР КИСТИ) ---
F19:: 
    Mode_Knob3 := (Mode_Knob3 = "Color") ? "Size" : "Color"
    ShowTip("РУЧКА 3: " . (Mode_Knob3 = "Color" ? "ЯРКОСТЬ" : "РАЗМЕР КИСТИ"))
return

F17:: 
    if (Mode_Knob3 = "Color") {
        BrightnessBuffer -= 2
        SetTimer, ApplyBrightness, -120
    } else {
        Send {[}
        if (VisualSize > 1) 
            VisualSize--
        
        bar := ""
        Loop, %VisualSize%
            bar .= "|"
        Loop, % (20 - VisualSize)
            bar .= " "
            
        ShowTip("РАЗМЕР: [" . bar . "]")
    }
return

F18:: 
    if (Mode_Knob3 = "Color") {
        BrightnessBuffer += 2
        SetTimer, ApplyBrightness, -120
    } else {
        Send {]}
        if (VisualSize < 20) 
            VisualSize++
            
        bar := ""
        Loop, %VisualSize%
            bar .= "|"
        Loop, % (20 - VisualSize)
            bar .= " "
            
        ShowTip("РАЗМЕР: [" . bar . "]")
    }
return

; --- ТАЙМЕРЫ ЭНКОДЕРОВ (ПЛОТНЫЙ ТЕКСТ) ---

ApplyHue:
    currentDelta := HueBuffer
    HueBuffer := 0 
    GetColorFullDetails(currentDelta, "H", newVal, colorName)
    
    GetRawHSB(h, s, b)
    HSB_to_RGB(h, s, b, R, G, B)
    
    hudText := "🌈 ТОН: " . ToBold(newVal) . "° [" . colorName . "]`n"
            . "💧 " . s . "% | 💡 " . b . "% | RGB: [" . R . "," . G . "," . B . "]"
    ShowTip(hudText, R, G, B, true)
return

ApplySaturation:
    currentDelta := SaturationBuffer
    SaturationBuffer := 0
    GetColorFullDetails(currentDelta, "S", newVal, colorName)
    
    GetRawHSB(h, s, b)
    HSB_to_RGB(h, s, b, R, G, B)
    
    hudText := "💧 НАС.: " . ToBold(newVal) . "% [" . colorName . "]`n"
            . "⭕ " . h . "° | 💡 " . b . "% | RGB: [" . R . "," . G . "," . B . "]"
    ShowTip(hudText, R, G, B, true)
return

ApplyBrightness:
    currentDelta := BrightnessBuffer
    BrightnessBuffer := 0
    GetColorFullDetails(currentDelta, "B", newVal, colorName)
    
    GetRawHSB(h, s, b)
    HSB_to_RGB(h, s, b, R, G, B)
    
    hudText := "💡 ЯРК.: " . ToBold(newVal) . "% [" . colorName . "]`n"
            . "⭕ " . h . "° | 💧 " . s . "% | RGB: [" . R . "," . G . "," . B . "]"
    ShowTip(hudText, R, G, B, true)
return

; --- СИНХРОНИЗАЦИЯ С КЛАВИАТУРОЙ (ТРЕХСТРОЧНАЯ КИСТЬ) ---

~$*b::
    Critical 
    ToolToggle := 1
    Sleep, 50
    opacValue := OpacityIndex * 10
    hardValue := HardnessIndex * 25
    
    ; Переносим жесткость на третью строчку через `n
    msg := "🖌️ КИСТЬ`n💧 НЕПРОЗР: " . opacValue . "%`n🧱 ЖЕСТК: " . hardValue . "%"
    ShowTip(msg)
return

~$*e::
    Critical
    ToolToggle := 0
    Sleep, 50
    opacValue := OpacityIndex * 10
    
    msg := "🧼 ЛАСТИК`n💧 НЕПРОЗР: " . opacValue . "%"
    ShowTip(msg)
return

~r:: ShowTip("ПОВОРОТ ХОЛСТА")

^!+k::  
    Critical
    if (ToolToggle = 0) {
        Send, b
        ToolToggle := 1
        Sleep, 50
        opacValue := OpacityIndex * 10
        hardValue := HardnessIndex * 25
        msg := "🖌️ КИСТЬ`n💧 НЕПРОЗР: " . opacValue . "%`n🧱 ЖЕСТК: " . hardValue . "%"
        ShowTip(msg)
    } else {
        Send, e
        ToolToggle := 0
        Sleep, 50
        opacValue := OpacityIndex * 10
        msg := "🧼 ЛАСТИК`n💧 НЕПРОЗР: " . opacValue . "%"
        ShowTip(msg)
    }
return

; --- УМНЫЙ ТРЁХРЕЖИМНЫЙ АДАПТИВНЫЙ HUD У КУРСОРA ---
ShowTip(text, r:=0, g:=0, b:=0, showColorSquare:=false) {
    global HudTextCtrl, HudColorCtrl, HudColorCtrlBackground, HudInitialized
    
    r := (r > 255) ? 255 : ((r < 0) ? 0 : r)
    g := (g > 255) ? 255 : ((g < 0) ? 0 : g)
    b := (b > 255) ? 255 : ((b < 0) ? 0 : b)
    
    if (!HudInitialized) {
        Gui, HUD:+AlwaysOnTop -Caption +Owner +LastFound +E0x20 
        Gui, HUD:Color, 1C1C1C 
        Gui, HUD:Font, s9 q5 cFFFFFF, Segoe UI 
        
        Gui, HUD:Add, Progress, x10 y12 w22 h22 c000000 vHudColorCtrlBackground, 100
        Gui, HUD:Add, Progress, x11 y13 w20 h20 cFFFFFF vHudColorCtrl, 100 
        
        ; Текстовое поле изначально создаем с большим запасом по высоте (h55) под 3 строчки
        Gui, HUD:Add, Text, x38 y10 w240 h55 vHudTextCtrl, % text
        
        HudInitialized := true
    }
    
    GuiControl, HUD:, HudTextCtrl, % text
    
    ; Задаем базовые стандартные размеры (для микро-плашки ластика/размера)
    hudWidth := 150
    hudHeight := 50
    
    if (showColorSquare) {
        ; --- РЕЖИМ 1: ЦВЕТОВОЙ HUD ---
        hexColor := Format("{:02X}{:02X}{:02X}", r, g, b)
        GuiControl, HUD: +c%hexColor%, HudColorCtrl
        GuiControl, HUD: Move, HudColorCtrl, x11 y13 w20 h20
        GuiControl, HUD: Move, HudColorCtrlBackground, x10 y12 w22 h22
        GuiControl, HUD: Move, HudTextCtrl, x38 y10 w240 h38
        hudWidth := 285
        hudHeight := 50
    } 
    else if (InStr(text, "КИСТЬ")) {
        ; --- РЕЖИМ 2: ВЕРТИКАЛЬНАЯ ТРЕХСТРОЧНАЯ КИСТЬ ---
        GuiControl, HUD: Move, HudColorCtrl, x-100 y-100
        GuiControl, HUD: Move, HudColorCtrlBackground, x-100 y-100
        GuiControl, HUD: Move, HudTextCtrl, x10 y8 w130 h52
        hudWidth := 150
        hudHeight := 65 ; Увеличиваем высоту плашки, чтобы влезла жесткость!
    } 
    else {
        ; --- РЕЖИМ 3: УЛЬТРА-МИКРО ТЕКСТОВЫЙ HUD (Ластик, Размер, Поворот) ---
        GuiControl, HUD: Move, HudColorCtrl, x-100 y-100
        GuiControl, HUD: Move, HudColorCtrlBackground, x-100 y-100
        GuiControl, HUD: Move, HudTextCtrl, x10 y10 w130 h38
        hudWidth := 150
        hudHeight := 50
    }
    
    CoordMode, Mouse, Screen
    MouseGetPos, mouseX, mouseY
    
    guiX := mouseX + 20
    guiY := mouseY + 15
    
    ; Применяем динамическую ширину и высоту
    Gui, HUD:Show, x%guiX% y%guiY% w%hudWidth% h%hudHeight% NoActivate
    
    SetTimer, RemoveHUD, -1500
}

RemoveHUD:
    Gui, HUD:Hide
return

RemoveToolTip:
    ToolTip
return

ToBold(num) {
    out := ""
    Loop, Parse, num
    {
        if (A_LoopField >= "0" && A_LoopField <= "9")
            out .= Chr(0xD835) . Chr(0xDFEC + A_LoopField)
        else
            out .= A_LoopField
    }
    return out
}

GetRawHSB(ByRef h, ByRef s, ByRef b) {
    Loop, 3 
    {
        try {
            app := ComObjActive("Photoshop.Application")
            hsb := app.ForegroundColor.HSB
            h := Round(hsb.Hue)
            s := Round(hsb.Saturation)
            b := Round(hsb.Brightness)
            
            if (h != 0 || s != 0 || b != 0 || Old_B <= 15)
                return
        }
        Sleep, 30 
    }
    h := Old_H, s := Old_S, b := Old_B
}

GetColorFullDetails(delta, param, ByRef outVal, ByRef outName) {
    try {
        app := ComObjActive("Photoshop.Application")
        color := app.ForegroundColor
        hsb := color.HSB
        
        h := hsb.Hue
        s := hsb.Saturation
        b := hsb.Brightness
        
        if (param = "H") {
            h := h + delta
            if (h >= 360) {
                h := Mod(h, 360)
            } else if (h < 0) {
                h := 360 + Mod(h, 360)
            }
            hsb.Hue := h
        }
        else if (param = "S") {
            s := s + delta
            if (s > 100) {
                s := 100
            }
            if (s < 0) {
                s := 0
            }
            hsb.Saturation := s
        }
        else if (param = "B") {
            b := b + delta
            if (b > 100) {
                b := 100
            }
            if (b < 0) {
                b := 0
            }
            hsb.Brightness := b
        }
        
        color.HSB := hsb
        app.ForegroundColor := color
        
        outVal := Round(param = "H" ? h : (param = "S" ? s : b))
        outName := ParseExtendedColor(Round(h), Round(s), Round(b))
        return
    }
    outVal := 0, outName := "Ошибка"
}

HSB_to_RGB(h, s, b_val, ByRef outR, ByRef outG, ByRef outB) {
    s := s / 100
    v := b_val / 100
    
    if (s = 0) {
        val := Round(v * 255)
        outR := val, outG := val, outB := val
        return
    }
    
    hf := h / 60
    i := Floor(hf)
    f := hf - i
    
    pv := v * (1 - s)
    qv := v * (1 - s * f)
    tv := v * (1 - s * (1 - f))
    
    if (i = 0 || i = 6) {
        r := v, g := tv, b := pv
    } else if (i = 1) {
        r := qv, g := v, b := pv
    } else if (i = 2) {
        r := pv, g := v, b := tv
    } else if (i = 3) {
        r := pv, g := qv, b := v
    } else if (i = 4) {
        r := tv, g := pv, b := v
    } else if (i = 5) {
        r := v, g := pv, b := qv
    }
    
    outR := Round(r * 255)
    outG := Round(g * 255)
    outB := Round(b * 255)
}

; Продвинутый анализатор цвета по 32 секторам с динамическими модификаторами
ParseExtendedColor(h, s, b) {
    if (b <= 12) 
        return "Черный"
    if (s <= 7 && b >= 88) 
        return "Белый"
    if (s <= 10) 
        return "Серый"

    name := ""
    if (h >= 355 || h < 10) 
        name := "Красный"
    else if (h >= 10 && h < 20) 
        name := "Терракотовый"
    else if (h >= 20 && h < 30) 
        name := "Оранжевый"
    else if (h >= 30 && h < 42) 
        name := "Янтарный"
    else if (h >= 42 && h < 50) 
        name := "Песочный"
    else if (h >= 50 && h < 55) 
        name := "Горчичный"
    else if (h >= 55 && h < 64) 
        name := "Желтый"
    else if (h >= 64 && h < 73) 
        name := "Лаймовый"
    else if (h >= 73 && h < 85) 
        name := "Салатовый"
    else if (h >= 85 && h < 115) 
        name := "Зеленый"
    else if (h >= 115 && h < 135) 
        name := "Хвойный"
    else if (h >= 135 && h < 150) 
        name := "Изумрудный"
    else if (h >= 150 && h < 162) 
        name := "Оливковый"
    else if (h >= 162 && h < 172) 
        name := "Мятный"
    else if (h >= 172 && h < 182) 
        name := "Аквамарин"
    else if (h >= 182 && h < 192) 
        name := "Бирюзовый"
    else if (h >= 192 && h < 202) 
        name := "Морской волны"
    else if (h >= 202 && h < 212) 
        name := "Небесный"
    else if (h >= 212 && h < 222) 
        name := "Голубой"
    else if (h >= 222 && h < 232) 
        name := "Лазурный"
    else if (h >= 232 && h < 242) 
        name := "Синий"
    else if (h >= 242 && h < 250) 
        name := "Ультрамарин"
    else if (h >= 250 && h < 258) 
        name := "Индиго"
    else if (h >= 258 && h < 268) 
        name := "Лиловый"
    else if (h >= 268 && h < 278) 
        name := "Фиолетовый"
    else if (h >= 278 && h < 290) 
        name := "Аметистовый"
    else if (h >= 290 && h < 305) 
        name := "Пурпурный"
    else if (h >= 305 && h < 320) 
        name := "Маджента"
    else if (h >= 320 && h < 332) 
        name := "Фуксия"
    else if (h >= 332 && h < 343) 
        name := "Розовый"
    else if (h >= 343 && h < 355) 
        name := "Пудровый"

    if (b < 45 && name != "Черный") {
        return "Темно-" . Format("{:L}", name)
    }
    ; СОКРАЩЕНИЕ: Вместо "Пастельный" возвращаем короткое "Паст."
    if (s < 35 && b > 65 && name != "Белый" && name != "Серый") {
        return "Паст. " . Format("{:L}", name)
    }
        
    return name
}

GetBrushSize() {
    try {
        app := ComObjActive("Photoshop.Application")
        js := "function getBrushSize() {`n"
           .  "    try {`n"
           .  "        var ref = new ActionReference();`n"
           .  "        ref.putEnumerated(charIDToTypeID('capp'), charIDToTypeID('Ordn'), charIDToTypeID('Trgt'));`n"
           .  "        var desc = executeActionGet(ref);`n"
           .  "        if (desc.hasKey(stringIDToTypeID('currentToolOptions'))) {`n"
           .  "            var options = desc.getObjectValue(stringIDToTypeID('currentToolOptions'));`n"
           .  "            if (options.hasKey(stringIDToTypeID('brush'))) {`n"
           .  "                return Math.round(options.getObjectValue(stringIDToTypeID('brush')).getDouble(stringIDToTypeID('size')));`n"
           .  "            }`n"
           .  "        }`n"
           .  "        var ref2 = new ActionReference();`n"
           .  "        ref2.putProperty(charIDToTypeID('Prpr'), stringIDToTypeID('tool'));`n"
           .  "        ref2.putEnumerated(charIDToTypeID('capp'), charIDToTypeID('Ordn'), charIDToTypeID('Trgt'));`n"
           .  "        var toolDesc = executeActionGet(ref2);`n"
           .  "        var options2 = toolDesc.getObjectValue(stringIDToTypeID('currentToolOptions'));`n"
           .  "        return Math.round(options2.getObjectValue(stringIDToTypeID('brush')).getDouble(stringIDToTypeID('size')));`n"
           .  "    } catch(e) { return '?'; }`n"
           .  "}`n"
           .  "getBrushSize();"
        
        size := app.doJavaScript(js)
        return size
    } catch {
        return "?"
    }
}

IsBrushOrEraser() {
    MouseGetPos,,, TaskWindow, TaskControl
    WinGetClass, windowClass, ahk_id %TaskWindow%
    
    if (InStr(TaskControl, "Tab") || InStr(TaskControl, "Dock") || InStr(TaskControl, "Owl") || InStr(TaskControl, "Tree"))
        return false 
        
    try {
        app := ComObjActive("Photoshop.Application")
        js := "var r = new ActionReference(); r.putProperty(charIDToTypeID('Prpr'), stringIDToTypeID('tool')); r.putEnumerated(charIDToTypeID('capp'), charIDToTypeID('Ordn'), charIDToTypeID('Trgt')); typeIDToStringID(executeActionGet(r).getEnumerationType(stringIDToTypeID('tool')));"
        tName := "" . app.doJavaScript(js)
        
        if (tName = "")
            return true
            
        StringLower, toolName, tName
        if (InStr(toolName, "brush") || InStr(toolName, "eraser"))
            return true
    }
    return false
}

#IfWinActive
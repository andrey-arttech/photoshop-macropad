; ==============================================================================
; Название: Photoshop MacroPad Pro Control
; Автор: andrey-arttech
; GitHub: github.com
; Версия: 2.4
; Лицензия: MIT
; Описание: Скрипт для 12-клавишного макропада с 3 энкодерами.
;           Прямая интеграция с PS через COM, интерактивная пипетка,
;           синхронизация инструментов и визуальный HUD.
; ==============================================================================


#NoEnv
#SingleInstance Force
SetBatchLines, -1 ; Максимальная скорость выполнения скрипта AHK

; --- КАСТОМИЗАЦИЯ И ПОДПИСЬ В СИСТЕМЕ ---
Menu, Tray, Tip, PS MacroPad Pro by [andrey-arttech] ; Подпись при наведении на иконку в трее

; --- АВТО-ЗАПРОС ПРАВ АДМИНИСТРАТОРА ---
if not A_IsAdmin
{
   Run *RunAs "%A_ScriptFullPath%"
   ExitApp
}

; Приветственное уведомление при успешном запуске от имени Админа
ToolTip, 🎨 PS MacroPad Controller v1.0`nby [andrey-arttech] успешно запущен!
SetTimer, RemoveToolTip, -3000 ; Исчезнет через 3 секунды

; --- БЛОК ИНИЦИАЛИЗАЦИИ ГЛОБАЛЬНЫХ ПЕРЕМЕННЫХ ---
global ToolToggle := 1 
global Mode_Knob1 := "Color"
global Mode_Knob2 := "Color"
global Mode_Knob3 := "Color"
global VisualSize := 5 ; Начальное значение шкалы
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

#IfWinActive ahk_exe Photoshop.exe ; --- ВСЕ КЛАВИШИ НИЖЕ РАБОТАЮТ ТОЛЬКО В PHOTOSHOP ---

; --- ИНТЕРАКТИВНАЯ ПИПЕТКА (ВАРИАНТ 1 С ЖИРНЫМИ ЦИФРАМИ) ---

; Этап 1. Ловим зажатие Alt (тихо фиксируем цвет "БЫЛО")
~*Alt::
    if (AltPressed = 1) 
        return
    AltPressed := 1
    GetRawHSB(Old_H, Old_S, Old_B)
return

; Сбрасываем флаг, когда Alt отпустили
~*Alt Up::
    AltPressed := 0
return

; Этап 2. Ловим клик мыши при зажатом Alt (считываем "СТАЛО" и выводим сравнение)
~*~LButton::
    if (AltPressed = 0) 
        return
        
    ; Короткая пауза для стабильного считывания
    Sleep, 120 
    
    ; Считываем новый цвет
    GetRawHSB(new_H, new_S, new_B)
    
    ; Вычисляем разницу параметров
    diff_H := new_H - Old_H
    diff_S := new_S - Old_S
    diff_B := new_B - Old_B
    
    ; Форматируем отображение дельты для Тона, Насыщенности и Яркости
    str_diff_H := (diff_H > 0) ? "▲" . diff_H . "°" : (diff_H < 0) ? "▼" . Abs(diff_H) . "°" : "="
    str_diff_S := (diff_S > 0) ? "▲" . diff_S . "%" : (diff_S < 0) ? "▼" . Abs(diff_S) . "%" : "="
    str_diff_B := (diff_B > 0) ? "▲" . diff_B . "%" : (diff_B < 0) ? "▼" . Abs(diff_B) . "%" : "="
    
    ; Конвертируем HSB в RGB для новой пробы цвета
    HSB_to_RGB(new_H, new_S, new_B, R, G, B)
    
    ; Получаем текстовые названия цветов
    oldName := ParseExtendedColor(Old_H, Old_S, Old_B)
    newName := ParseExtendedColor(new_H, new_S, new_B)
    
    ; Переводим новые (текущие) значения в псевдо-жирный Юникод
    b_H := ToBold(new_H)
    b_S := ToBold(new_S)
    b_B := ToBold(new_B)
    
    ; Собираем лаконичный двухстрочный HUD
   hudText := "🎨 " . newName . "`n"
            . "⭕ " . b_H . "° [" . str_diff_H . "] | 💧 " . b_S . "% [" . str_diff_S . "] | 💡 " . b_B . "% [" . str_diff_B . "]`n"
            . "🖥️ RGB: [" . R . ", " . G . ", " . B . "]"
    ShowTip(hudText)
    
    ; Перезаписываем базу для следующего сэмпла
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

F17:: ; Вращение влево (Меньше)
    if (Mode_Knob3 = "Color") {
        BrightnessBuffer -= 2
        SetTimer, ApplyBrightness, -120
    } else {
        Send {[}
        if (VisualSize > 1) 
            VisualSize--
        
        ; Рисуем шкалу: [||||      ]
        bar := ""
        Loop, %VisualSize%
            bar .= "|"
        Loop, % (20 - VisualSize)
            bar .= " "
            
        ShowTip("РАЗМЕР: [" . bar . "]")
    }
return

F18:: ; Вращение вправо (Больше)
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

; --- ТАЙМЕРЫ ОТПРАВКИ И ПРИМЕНЕНИЯ БУФЕРА ---

ApplyHue:
    currentDelta := HueBuffer
    HueBuffer := 0 
    GetColorFullDetails(currentDelta, "H", newVal, colorName)
    ShowTip("ТОН: " . newVal . "° (" . colorName . ")")
return

ApplySaturation:
    currentDelta := SaturationBuffer
    SaturationBuffer := 0
    GetColorFullDetails(currentDelta, "S", newVal, colorName)
    ShowTip("НАСЫЩЕННОСТЬ: " . newVal . "% (" . colorName . ")")
return

ApplyBrightness:
    currentDelta := BrightnessBuffer
    BrightnessBuffer := 0
    GetColorFullDetails(currentDelta, "B", newVal, colorName)
    ShowTip("ЯРКОСТЬ: " . newVal . "% (" . colorName . ")")
return


; --- СИНХРОНИЗАЦИЯ С КЛАВИАТУРОЙ ---

~$*b::
    Critical ; Повышает приоритет выполнения, чтобы ничего не обрывалось
    ToolToggle := 1
    Sleep, 50
    ; Принудительно вычисляем локальные переменные внутри блока
    opacValue := OpacityIndex * 10
    hardValue := HardnessIndex * 25
    ; Формируем строку
    msg := "🖌️ КИСТЬ`n💧 Непрозрачность: " . opacValue . "%`n🧱 Жесткость: " . hardValue . "%"
    ShowTip(msg)
return

~$*e::
    Critical
    ToolToggle := 0
    Sleep, 50
    opacValue := OpacityIndex * 10
    msg := "🧼 ЛАСТИК`n💧 Непрозрачность: " . opacValue . "%"
    ShowTip(msg)
return

~r:: ShowTip("ПОВОРОТ ХОЛСТА")

^!+k::  ; Ваша кнопка на пере (стилусе)
    Critical
    if (ToolToggle = 0) {
        Send, b
        ToolToggle := 1
        Sleep, 50
        opacValue := OpacityIndex * 10
        hardValue := HardnessIndex * 25
        msg := "🖌️ КИСТЬ`n💧 Непрозрачность: " . opacValue . "%`n🧱 Жесткость: " . hardValue . "%"
        ShowTip(msg)
    } else {
        Send, e
        ToolToggle := 0
        Sleep, 50
        opacValue := OpacityIndex * 10
        msg := "🧼 ЛАСТИК`n💧 Непрозрачность: " . opacValue . "%"
        ShowTip(msg)
    }
return

#IfWinActive ; --- ЗАКРЫТИЕ ДИРЕКТИВЫ PHOTOSHOP ---


; --- СЛУЖЕБНЫЕ ФУНКЦИИ ---

ShowTip(text) {
    ToolTip, %text%
    SetTimer, RemoveToolTip, -2000 ; 2 секунды удержания окна
}

RemoveToolTip:
    ToolTip
return

; Функция перевода обычных цифр в полужирные символы Юникода
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

; Быстрое чтение HSB без изменения цвета
GetRawHSB(ByRef h, ByRef s, ByRef b) {
    try {
        app := ComObjActive("Photoshop.Application")
        hsb := app.ForegroundColor.HSB
        h := Round(hsb.Hue)
        s := Round(hsb.Saturation)
        b := Round(hsb.Brightness)
        return
    }
    h := 0, s := 0, b := 0
}

; Изменяет HSB в Photoshop и возвращает точные параметры текущего цвета
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

; Алгоритм перевода HSB в физический RGB (0-255)
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

; Продвинутый анализатор цвета по 16 секторам с учетом яркости/насыщенности
ParseExtendedColor(h, s, b) {
    if (b <= 12) {
        return "Черный"
    }
    if (s <= 8 && b >= 85) {
        return "Белый"
    }
    if (s <= 10) {
        return "Серый"
    }

    name := ""
    if (h >= 350 || h < 10) 
        name := "Красный"
    else if (h >= 10 && h < 23) 
        name := "Терракотовый"
    else if (h >= 23 && h < 40) 
        name := "Оранжевый"
    else if (h >= 40 && h < 53) 
        name := "Песочный"
    else if (h >= 53 && h < 64) 
        name := "Желтый"
    else if (h >= 64 && h < 80) 
        name := "Салатовый"
    else if (h >= 80 && h < 140) 
        name := "Зеленый"
    else if (h >= 140 && h < 165) 
        name := "Оливковый"
    else if (h >= 165 && h < 180) 
        name := "Мятный"
    else if (h >= 180 && h < 200) 
        name := "Бирюзовый"
    else if (h >= 200 && h < 220) 
        name := "Голубой"
    else if (h >= 220 && h < 245) 
        name := "Синий"
    else if (h >= 245 && h < 265) 
        name := "Лиловый"
    else if (h >= 265 && h < 285) 
        name := "Фиолетовый"
    else if (h >= 285 && h < 325) 
        name := "Пурпурный"
    else if (h >= 325 && h < 350) 
        name := "Розовый"

    if (b < 45 && name != "Черный") {
        return "Темно-" . Format("{:L}", name)
    }
    if (s < 35 && b > 65 && name != "Белый" && name != "Серый") {
        return "Пастельный " . Format("{:L}", name)
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
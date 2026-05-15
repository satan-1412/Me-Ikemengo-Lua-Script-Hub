-- =========================================================================================
-- [ Ikemen GO Full Auto Engine & 3D Z-Axis Movement System - Beginner-Friendly Configuration Area ]
-- =========================================================================================
-- Author/Integrator: Demon King Satan
-- Description: One-stop management of the auto-load function and the 3D stage Z-axis (depth) movement system.
--       No need to modify any character files! 2D normal stages perfectly maintain original feel, 3D stages are taken over automatically.
-- =========================================================================================

local SYSTEM_CONFIG = {
    -- =====================================================================================
    -- [ 1. Automation System Basic Switches ] 
    -- Beginner guide: true means ON, false means OFF. Modify as needed.
    -- =====================================================================================
    ENABLE_AUTOLOAD_CHARS  = true,  -- true: Enable auto-load characters / false: Disable
    ENABLE_AUTOLOAD_STAGES = true,  -- true: Enable auto-load stages / false: Disable
    ENABLE_AUTO_MOVELIST   = true,  -- true: Enable auto-generate movelist / false: Disable

    -- =====================================================================================
    -- [ 2. 3D Z-Axis Depth System Settings ]
    -- =====================================================================================
    -- 1. Master switch for depth system
    ENABLE_Z_AXIS = true,           -- true: Allow Z-axis movement in specific 3D stages / false: Completely disable

    -- 2. Operation Mode Selection
    -- true  = [Classic Mode] (Recommended): Use ↑ and ↓ for Z-axis movement. Original jump and crouch will be replaced by the spare keys below.
    -- false = [Split Mode]: ↑ and ↓ remain as native jump and crouch. Z-axis movement uses your custom keys below.
    USE_UP_DOWN_FOR_Z_MOVE = true,

    -- 3. Custom Key Settings (Must fill in the key 'name' defined in your common.cmd)
    
    -- Effective in [Classic Mode] (USE_UP_DOWN_FOR_Z_MOVE = true):
    -- Since Up and Down are taken for movement, you need to specify two keys for Jump and Crouch:
    SPARE_JUMP_KEY   = "w",         -- Spare Jump Key (Default: w)
    SPARE_CROUCH_KEY = "hold_d",    -- Spare Crouch Key (Default: hold d)

    -- Effective in [Split Mode] (USE_UP_DOWN_FOR_Z_MOVE = false):
    -- Direction keys act as normal jump/crouch, you need to specify two keys to move inward and outward on the Z-axis:
    CUSTOM_Z_IN_KEY  = "hold_w",    -- Move inward/background key (Default: hold w)
    CUSTOM_Z_OUT_KEY = "hold_d",    -- Move outward/foreground key (Default: hold d)

    -- 4. Movement Feel Settings
    -- Adjust character sliding speed on the Z-axis.
    -- Higher values mean faster movement (ice-skating feel), lower values mean steadier movement. Recommended range: 1.5 to 3.5.
    Z_MOVE_SPEED = "2.2",             
}

--[[
=========================================================================================
[ Beginner Tutorial: How to add custom keys in common.cmd? ]
If you want to use other keys for control, open the data/common.cmd file in the game directory.
Near the top of the file (e.g., below [Defaults]), **APPEND** the following code (DO NOT delete any original code!):

; --- Copy template below ---
[Command]
name = "w"          
command = w         
time = 1            
buffer.time = 1     
buffer.hitpause = 1 
buffer.pauseend = 1 

[Command]
name = "hold_w"     
command = /w        
time = 1
buffer.time = 1
buffer.hitpause = 1
buffer.pauseend = 1

[Command]
name = "hold_d"     
command = /d
time = 1
buffer.time = 1
buffer.hitpause = 1
buffer.pauseend = 1
; --- End of copy ---
=========================================================================================
]]

-- =========================================================================================
-- Below is the core code area, please do not modify randomly
-- =========================================================================================

local autoLoader = {}
local actualFilesMap = {}

local function writeLog(msg)
    local logPath = "save/autoloader_log.txt"
    local f = io.open(logPath, "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " | " .. msg .. "\n")
        f:close()
    end
end

-- ========================================================
-- [Core] Write perfect Z-axis system (Bulletproof array concatenation + AI ecosystem alignment lock)
-- ========================================================
local function WriteZAxisSystem()
    if not SYSTEM_CONFIG.ENABLE_Z_AXIS then
        local f = io.open("save/z_axis_auto.cns", "w")
        if f then f:write(""); f:close() end
        return
    end

    local BLOCK = SYSTEM_CONFIG.USE_UP_DOWN_FOR_Z_MOVE and "1" or "0"
    local K_IN = SYSTEM_CONFIG.USE_UP_DOWN_FOR_Z_MOVE and "holdup" or SYSTEM_CONFIG.CUSTOM_Z_IN_KEY
    local K_OUT = SYSTEM_CONFIG.USE_UP_DOWN_FOR_Z_MOVE and "holddown" or SYSTEM_CONFIG.CUSTOM_Z_OUT_KEY
    local K_JUMP = SYSTEM_CONFIG.SPARE_JUMP_KEY
    local K_CROUCH = SYSTEM_CONFIG.SPARE_CROUCH_KEY
    local SPD = tostring(SYSTEM_CONFIG.Z_MOVE_SPEED)

    local lines = {
        "[StateDef -2]",
        "",
        "; ==================================================",
        "; A. Smart evasion patch: Native Z-axis character detection",
        "; ==================================================",
        "[State -2, Block native control]",
        "type = AssertSpecial",
        "triggerall = " .. BLOCK .. " = 1",
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "trigger1 = StageVar(playerinfo.topbound) != 0 || StageVar(playerinfo.botbound) != 0",
        "flag = nocrouch",
        "flag2 = nojump",
        "",
        "; ==================================================",
        "; B. Spare Jump & Crouch",
        "; ==================================================",
        "[State -2, Spare Jump]",
        "type = ChangeState",
        "triggerall = " .. BLOCK .. " = 1 && statetype != A && statetype != L && ctrl",
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "triggerall = StageVar(playerinfo.topbound) != 0 || StageVar(playerinfo.botbound) != 0",
        "trigger1 = command = \"" .. K_JUMP .. "\"",
        "value = 40",
        "",
        "[State -2, Spare Crouch]",
        "type = ChangeState",
        "triggerall = " .. BLOCK .. " = 1 && statetype != A && statetype != L && ctrl",
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "triggerall = StageVar(playerinfo.topbound) != 0 || StageVar(playerinfo.botbound) != 0",
        "trigger1 = command = \"" .. K_CROUCH .. "\"",
        "value = 10",
        "",
        "; ==================================================",
        "; C. Player Z-axis intervention",
        "; ==================================================",
        "[State -2, Player_Move_Inward]",
        "type = ChangeState",
        "triggerall = AILevel = 0 && statetype != A && statetype != L && ctrl",
        "triggerall = stateno != 85200 && stateno != 85201", 
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "triggerall = StageVar(playerinfo.topbound) != 0 || StageVar(playerinfo.botbound) != 0",
        "trigger1 = command = \"" .. K_IN .. "\"",
        "value = 85200",
        "",
        "[State -2, Player_Move_Outward]",
        "type = ChangeState",
        "triggerall = AILevel = 0 && statetype != A && statetype != L && ctrl",
        "triggerall = stateno != 85200 && stateno != 85201", 
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "triggerall = StageVar(playerinfo.topbound) != 0 || StageVar(playerinfo.botbound) != 0",
        "trigger1 = command = \"" .. K_OUT .. "\"",
        "value = 85201",
        "",
        "; ==================================================",
        "; D. AI Tactics Engine (Arcade Boss Level: Absolute alignment to prevent twitching)",
        "; ==================================================",
        "[State -2, AI_Z-axis_Tactics_Pool_Inward_Dodge_&_Roam]",
        "type = ChangeState",
        "triggerall = AILevel > 0 && statetype != A && statetype != L && ctrl",
        "triggerall = stateno != 85200 && stateno != 85201",
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "triggerall = Pos Z > StageVar(playerinfo.topbound) + 10",
        "trigger1 = EnemyNear, NumProj > 0 && random < 900",
        "trigger2 = p2movetype = A && p2bodydist X = [30, 100] && EnemyNear, Pos Z <= Pos Z && random < 700",
        "; [Ultimate Intercept Lock]: As long as the opponent is in melee range (X<80) and not on the same line (error>4), force positioning, never swing blindly!",
        "trigger3 = abs(EnemyNear, Pos Z - Pos Z) > 4 && p2bodydist X < 80 && EnemyNear, Pos Z < Pos Z",
        "value = 85200",
        "",
        "[State -2, AI_Z-axis_Tactics_Pool_Outward_Dodge_&_Roam]",
        "type = ChangeState",
        "triggerall = AILevel > 0 && statetype != A && statetype != L && ctrl",
        "triggerall = stateno != 85200 && stateno != 85201",
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "triggerall = Pos Z < StageVar(playerinfo.botbound) - 10",
        "trigger1 = EnemyNear, NumProj > 0 && random < 900",
        "trigger2 = p2movetype = A && p2bodydist X = [30, 100] && EnemyNear, Pos Z >= Pos Z && random < 700",
        "trigger3 = abs(EnemyNear, Pos Z - Pos Z) > 4 && p2bodydist X < 80 && EnemyNear, Pos Z > Pos Z",
        "value = 85201",
        "",
        "; =========================================================",
        "; Exclusive State 85200: Move inward",
        "; =========================================================",
        "[StateDef 85200]",
        "type = S",
        "movetype = I",
        "physics = S",
        "; [Core Fix]: When entering this state, deprive control by default (ctrl=0), make AI position properly, completely root out twitching caused by attack conflicts",
        "ctrl = 0", 
        "velset = 0,0",
        "",
        "[State 85200, Player regains control]",
        "type = CtrlSet",
        "trigger1 = AILevel = 0",
        "value = 1",  "; But if it's currently player-controlled, return control instantly to ensure the player can interrupt moves at any time",
        "",
        "[State 85200, Physical dodge minor invincible frames]",
        "type = NotHitBy",
        "trigger1 = time < 8",
        "value = SCA",
        "time = 1",
        "",
        "[State 85200, Auto turn around when flanking]",
        "type = Turn",
        "trigger1 = p2dist X < 0", 
        "",
        "[State 85200, Animation]",
        "type = ChangeAnim",
        "trigger1 = Anim != 21 && Anim != 20",
        "value = 21",
        "",
        "[State 85200, Base Z speed]",
        "type = VelSet",
        "trigger1 = 1",
        "z = -" .. SPD,
        "",
        "[State 85200, Player_Joystick compensation]",
        "type = VelSet",
        "triggerall = AILevel = 0",
        "trigger1 = command = \"holdfwd\"",
        "x = const(velocity.walk.fwd.x)",
        "",
        "[State 85200, Player_Joystick compensation]",
        "type = VelSet",
        "triggerall = AILevel = 0",
        "trigger1 = command = \"holdback\"",
        "x = const(velocity.walk.back.x)",
        "",
        "; --- AI Defense Maxed: Physical arc flanking positioning ---",
        "[State 85200, AI_Defensive_Arc_Dodge_&_Retreat]",
        "type = VelSet",
        "triggerall = AILevel > 0",
        "; When the opponent is attacking fiercely at close range, AI won't suicide forward, but retreats, combining with Z-axis to form a perfect flanking arc",
        "trigger1 = p2movetype = A && p2bodydist X < 50",
        "x = const(velocity.walk.back.x)",
        "",
        "[State 85200, AI_Normal follow-up]",
        "type = VelSet",
        "triggerall = AILevel > 0",
        "triggerall = !(p2movetype = A && p2bodydist X < 50)",
        "trigger1 = p2bodydist X > 60",
        "x = const(velocity.walk.fwd.x)",
        "",
        "[State 85200, Physical boundary]",
        "type = PosSet",
        "trigger1 = Pos Z < StageVar(playerinfo.topbound)",
        "z = StageVar(playerinfo.topbound)",
        "",
        "[State 85200, Player natural exit]",
        "type = ChangeState",
        "trigger1 = AILevel = 0 && command != \"" .. K_IN .. "\"",
        "value = 0",
        "ctrl = 1",
        "",
        "[State 85200, AI_Lethal kill switch out]",
        "type = ChangeState",
        "triggerall = AILevel > 0",
        "; [Lethal Strike]: Only when perfectly aligned with the opponent's Z-axis (error<=4), and right in front (X<80), will it switch back to state 0 and gain ctrl=1 to initiate attack!",
        "trigger1 = abs(EnemyNear, Pos Z - Pos Z) <= 4 && p2bodydist X < 80", 
        "; Projectile safe distance judgment",
        "trigger2 = p2bodydist X >= 120 && abs(EnemyNear, Pos Z - Pos Z) <= 15",
        "trigger3 = Pos Z <= StageVar(playerinfo.topbound)",
        "value = 0",
        "ctrl = 1",
        "",
        "; =========================================================",
        "; Exclusive State 85201: Move outward",
        "; =========================================================",
        "[StateDef 85201]",
        "type = C",
        "movetype = I",
        "physics = C",
        "ctrl = 0",
        "velset = 0,0",
        "",
        "[State 85201, Player regains control]",
        "type = CtrlSet",
        "trigger1 = AILevel = 0",
        "value = 1",
        "",
        "[State 85201, Physical dodge minor invincible frames]",
        "type = NotHitBy",
        "trigger1 = time < 8",
        "value = SCA",
        "time = 1",
        "",
        "[State 85201, Auto turn around when flanking]",
        "type = Turn",
        "trigger1 = p2dist X < 0", 
        "",
        "[State 85201, Animation]",
        "type = ChangeAnim",
        "trigger1 = Anim != 20 && Anim != 21",
        "value = 20",
        "",
        "[State 85201, Base Z speed]",
        "type = VelSet",
        "trigger1 = 1",
        "z = " .. SPD,
        "",
        "[State 85201, Player_Joystick compensation]",
        "type = VelSet",
        "triggerall = AILevel = 0",
        "trigger1 = command = \"holdfwd\"",
        "x = const(velocity.walk.fwd.x)",
        "",
        "[State 85201, Player_Joystick compensation]",
        "type = VelSet",
        "triggerall = AILevel = 0",
        "trigger1 = command = \"holdback\"",
        "x = const(velocity.walk.back.x)",
        "",
        "[State 85201, AI_Defensive_Arc_Dodge_&_Retreat]",
        "type = VelSet",
        "triggerall = AILevel > 0",
        "trigger1 = p2movetype = A && p2bodydist X < 50",
        "x = const(velocity.walk.back.x)",
        "",
        "[State 85201, AI_Normal follow-up]",
        "type = VelSet",
        "triggerall = AILevel > 0",
        "triggerall = !(p2movetype = A && p2bodydist X < 50)",
        "trigger1 = p2bodydist X > 60",
        "x = const(velocity.walk.fwd.x)",
        "",
        "[State 85201, Physical boundary]",
        "type = PosSet",
        "trigger1 = Pos Z > StageVar(playerinfo.botbound)",
        "z = StageVar(playerinfo.botbound)",
        "",
        "[State 85201, Player natural exit]",
        "type = ChangeState",
        "trigger1 = AILevel = 0 && command != \"" .. K_OUT .. "\"",
        "value = 0",
        "ctrl = 1",
        "",
        "[State 85201, AI_Lethal kill switch out]",
        "type = ChangeState",
        "triggerall = AILevel > 0",
        "trigger1 = abs(EnemyNear, Pos Z - Pos Z) <= 4 && p2bodydist X < 80",
        "trigger2 = p2bodydist X >= 120 && abs(EnemyNear, Pos Z - Pos Z) <= 15",
        "trigger3 = Pos Z >= StageVar(playerinfo.botbound)",
        "value = 0",
        "ctrl = 1"
    }

    local f = io.open("save/z_axis_auto.cns", "w")
    if f then 
        f:write(table.concat(lines, "\n"))
        f:close() 
    else
        print("[Error] Failed to generate Z-axis file! Please ensure the 'save' folder exists in the game root directory!")
    end
end

-- ========================================================
-- [New] Dynamic cleanup mechanism: When switch is off, auto erase old injection traces
-- ========================================================
local function cleanDefInjections(defPath)
    local f = io.open(defPath, "r")
    if not f then return false end
    
    local fileLines = {}
    local isDirty = false
    
    for line in f:lines() do
        local cleanLine = line:gsub('\r', '')
        local lowerLine = cleanLine:lower()
        local dropLine = false
        
        -- 1. If Z-axis master switch is off, remove all residual z_axis_auto.cns injections (might be added manually or left from old versions)
        if not SYSTEM_CONFIG.ENABLE_Z_AXIS and lowerLine:match("z_axis_auto%.cns") then
            dropLine = true
            isDirty = true
        end
        
        -- 2. If auto movelist generation is off, remove forcefully written movelist.dat
        if not SYSTEM_CONFIG.ENABLE_AUTO_MOVELIST and lowerLine:match("movelist%s*=%s*movelist%.dat") then
            dropLine = true
            isDirty = true
        end
        
        if not dropLine then
            table.insert(fileLines, cleanLine)
        end
    end
    f:close()
    
    -- If residues found and removed, rewrite and save the def file
    if isDirty then
        local fw = io.open(defPath, "wb")
        if fw then
            for _, l in ipairs(fileLines) do fw:write(l .. "\n") end
            fw:close()
            writeLog("[Cleanup] Switch off detected, cleared residual injections: " .. defPath)
        end
    end
end

-- ========================================================
-- Movelist parsing and auto-load module
-- ========================================================
local function patchDefFile(defPath)
    local f = io.open(defPath, "r")
    if not f then return false end
    local fileLines = {}
    for line in f:lines() do
        local cleanLine = line:gsub('\r', '')
        table.insert(fileLines, cleanLine)
    end
    f:close()
    local currentSection = ""
    local filesSectionStartIdx = -1
    local movelistExistsInFiles = false
    local isDirty = false 
    for i, line in ipairs(fileLines) do
        local cleanLine = line:match("^%s*(.-)%s*$")
        local lowerLine = cleanLine:lower()
        if lowerLine:match("^%[%s*(.-)%s*%]") then
            currentSection = lowerLine:match("^%[%s*(.-)%s*%]")
            if currentSection == "files" then filesSectionStartIdx = i end
        end
        if lowerLine:match("^movelist%s*=") then
            if currentSection == "files" then
                movelistExistsInFiles = true
                return true
            else
                fileLines[i] = "--DELETE_ME--"
                isDirty = true
            end
        end
    end
    if not movelistExistsInFiles and filesSectionStartIdx ~= -1 then
        isDirty = true
        local filesSectionEndIdx = filesSectionStartIdx
        for i = filesSectionStartIdx + 1, #fileLines do
            local line = fileLines[i]:match("^%s*(.-)%s*$")
            if line:match("^%[") then break end
            if line ~= "" and fileLines[i] ~= "--DELETE_ME--" then filesSectionEndIdx = i end
        end
        local newLines = {}
        local inserted = false
        for i, line in ipairs(fileLines) do
            if line ~= "--DELETE_ME--" then
                table.insert(newLines, line)
                if i == filesSectionEndIdx and not inserted then
                    table.insert(newLines, "movelist = movelist.dat")
                    inserted = true
                end
            end
        end
        if not inserted then
            for j, l in ipairs(newLines) do
                if l:lower():match("^%[%s*files%s*%]") then
                    table.insert(newLines, j + 1, "movelist = movelist.dat")
                    break
                end
            end
        end
        local fw = io.open(defPath, "wb")
        if fw then
            for _, l in ipairs(newLines) do fw:write(l .. "\n") end
            fw:close()
            writeLog("[Patch] Movelist patched: " .. defPath)
            return true
        end
    end
    return false
end

local function formatCmdIcon(cmd)
    local s = cmd:gsub("[%s~$/]+", "")
    s = s:gsub("[dD],[dD][fF],[fF]", "_QDF")
    s = s:gsub("[dD],[dD][bB],[bB]", "_QDB")
    s = s:gsub("[fF],[dD],[dD][fF]", "_DSF")
    s = s:gsub("[bB],[dD],[dD][bB]", "_DSB")
    s = s:gsub("[fF],[dD][fF],[dD],[dD][bB],[bB]", "_HDB")
    s = s:gsub("[bB],[dD][bB],[dD],[dD][fF],[fF]", "_HDF")
    s = s:gsub("_QDF,_QDF", "_QDF_QDF")
    s = s:gsub("_QDB,_QDB", "_QDB_QDB")
    local parts = {}
    for part in s:gmatch("([^,]+)") do
        if part:match("^_") then
            table.insert(parts, part)
        else
            local subParts = {}
            for key in part:gmatch("([^+]+)") do
                local res = ""
                local keyUpper = key:upper()
                if keyUpper == "X" then res = "^X"
                elseif keyUpper == "Y" then res = "^Y"
                elseif keyUpper == "Z" then res = "^Z"
                elseif keyUpper == "A" then res = "^A"
                elseif keyUpper == "C" then res = "^C"
                elseif keyUpper == "S" or keyUpper == "START" then res = "^S"
                elseif keyUpper == "B" then if key == "b" then res = "^B" else res = "_B" end           
                elseif keyUpper == "F" or keyUpper == "FWD" then res = "_F"
                elseif keyUpper == "D" or keyUpper == "DOWN" then res = "_D"
                elseif keyUpper == "U" or keyUpper == "UP" then res = "_U"
                elseif keyUpper == "DF" then res = "_DF"
                elseif keyUpper == "DB" then res = "_DB"
                elseif keyUpper == "UF" then res = "_UF"
                elseif keyUpper == "UB" then res = "_UB"
                else res = keyUpper end
                table.insert(subParts, res)
            end
            table.insert(parts, table.concat(subParts, "_+"))
        end
    end
    return table.concat(parts, "")
end

local function generateMovelist(charDir, defPath)
    patchDefFile(defPath)
    local datTarget = (charDir .. "movelist.dat"):lower()
    local txtTarget = (charDir .. "command.txt"):lower()
    if actualFilesMap[datTarget] or actualFilesMap[txtTarget] then return end
    local defFile = io.open(defPath, "r")
    if not defFile then return end
    local cmdFileName = nil
    for line in defFile:lines() do
        local noComment = line:gsub(";.*", "")
        local match = noComment:match("^%s*[cC][mM][dD]%s*=%s*(.-)%s*$")
        if match and match ~= "" then 
            cmdFileName = match:gsub("\\", "/")
            break 
        end
    end
    defFile:close()
    if not cmdFileName then return end
    local expectedCmdPath = (charDir .. cmdFileName):lower()
    local realCmdPath = actualFilesMap[expectedCmdPath]
    if not realCmdPath then return end
    local cmdFile = io.open(realCmdPath, "r")
    if not cmdFile then return end
    local outPath = charDir .. "movelist.dat"
    local datFile = io.open(outPath, "wb")
    if not datFile then 
        cmdFile:close()
        return 
    end
    local moves = { unique = {}, throws = {}, special = {}, super = {} }
    local addedMoves = 0
    local inCommand = false
    local mName = ""
    local mCmd = ""
    local seenMoves = {}
    local function commitMove()
        if inCommand and mName ~= "" and mCmd ~= "" then
            local lowerName = mName:lower()
            local rawCmd = mCmd:gsub("[%s~$/]+", "")
            if not (lowerName:match("ai") or lowerName:match("cpu") or rawCmd:len() == 1) then
                local formattedCmd = formatCmdIcon(mCmd)
                local safeName = mName:gsub("[\128-\255]", "") 
                safeName = safeName:match("^%s*(.-)%s*$") or ""
                if safeName == "" then safeName = "Move_" .. tostring(addedMoves + 1) end
                local sig = safeName .. "||" .. formattedCmd
                if not seenMoves[sig] then
                    seenMoves[sig] = true
                    local cat = "special"
                    if lowerName:match("super") or lowerName:match("hyper") or formattedCmd:match("_QDF.*_QDF") or formattedCmd:match("_QDB.*_QDB") then
                        cat = "super"
                    elseif lowerName:match("throw") then cat = "throws"
                    elseif not (formattedCmd:match("_QDF") or formattedCmd:match("_QDB") or formattedCmd:match("_DSF")) and formattedCmd:match("_%+") then
                        cat = "unique"
                    end
                    local tabs = "\t"
                    local len = safeName:len()
                    if len < 8 then tabs = "\t\t\t\t\t\t"
                    elseif len < 16 then tabs = "\t\t\t\t\t"
                    elseif len < 24 then tabs = "\t\t\t\t"
                    else tabs = "\t\t\t" end
                    table.insert(moves[cat], safeName .. tabs .. formattedCmd)
                    addedMoves = addedMoves + 1
                end
            end
        end
        mName = ""
        mCmd = ""
        inCommand = false
    end
    for line in cmdFile:lines() do
        line = line:gsub('\r', ''):gsub(";.*", "") 
        local cleanLine = line:match("^%s*(.-)%s*$")
        if cleanLine:match("^%[") then
            commitMove()
            if cleanLine:lower():match("^%[%s*command%s*%]") then inCommand = true end
        elseif inCommand and cleanLine ~= "" then
            local n = cleanLine:match('^[nN][aA][mM][eE]%s*="([^"]+)"') or cleanLine:match('^[nN][aA][mM][eE]%s*=%s*(.+)')
            if n then mName = n end
            local c = cleanLine:match('^[cC][oO][mM][mM][aA][nN][dD]%s*=%s*(.+)')
            if c then mCmd = c end
        end
    end
    commitMove()
    if #moves.unique > 0 then
        datFile:write("<#f0f000>:Unique Attacks:</>\n")
        for _, v in ipairs(moves.unique) do datFile:write(v .. "\n") end
        datFile:write("\n")
    end
    if #moves.throws > 0 then
        datFile:write("<#f0f000>:Throws:</>\n")
        for _, v in ipairs(moves.throws) do datFile:write(v .. "\n") end
        datFile:write("\n")
    end
    if #moves.special > 0 then
        datFile:write("<#f0f000>:Special Moves:</>\n")
        for _, v in ipairs(moves.special) do datFile:write(v .. "\n") end
        datFile:write("\n")
    end
    if #moves.super > 0 then
        datFile:write("<#f0f000>:Super Moves:</>\n")
        for _, v in ipairs(moves.super) do datFile:write(v .. "\n") end
        datFile:write("\n")
    end
    datFile:flush()
    datFile:close()
    cmdFile:close()
    if addedMoves == 0 then os.remove(outPath)
    else writeLog("[Success] Movelist generated: " .. charDir .. " (" .. addedMoves .. " moves)") end
end

local function buildFileMap(fileList)
    for _, path in ipairs(fileList) do
        local normalizedPath = path:gsub('\\', '/')
        actualFilesMap[normalizedPath:lower()] = normalizedPath
    end
end

local function loadCharacters()
    local fileList = getDirectoryFiles("chars")
    if not fileList then return end
    buildFileMap(fileList)
    local addedCount = 0
    for _, path in ipairs(fileList) do
        local normalizedPath = path:gsub('\\', '/')
        local relPath = normalizedPath:match("^chars/(.+)$")
        if relPath and relPath:lower():match("%.def$") then
            local folderName, fileName = relPath:match("([^/]+)/([^/]+)%.[dD][eE][fF]$")
            if (not folderName) or (folderName and fileName and folderName:lower() == fileName:lower()) then
                local charDir = normalizedPath:match("^(.-)[^/]+%.def$")
                
                if charDir then 
                    -- [Core Change] Before any processing, perform a cleanup based on current system switches
                    cleanDefInjections(normalizedPath)
                    
                    -- After cleanup, determine if movelist generation is needed
                    if SYSTEM_CONFIG.ENABLE_AUTO_MOVELIST then
                        generateMovelist(charDir, normalizedPath) 
                    end
                end

                if SYSTEM_CONFIG.ENABLE_AUTOLOAD_CHARS then
                    if main.t_charDef[relPath:lower()] == nil then
                        if main.f_addChar(relPath, true, false, false) then
                            addedCount = addedCount + 1
                            local newCharIdx = #main.t_selGrid
                            local charData = main.t_selGrid[newCharIdx]
                            for i = 1, #main.t_selGrid - 1 do
                                if main.t_selGrid[i].chars and #main.t_selGrid[i].chars == 0 then
                                    main.t_selGrid[i].chars = charData.chars
                                    main.t_selGrid[i].slot = charData.slot
                                    for j = 1, #main.t_selChars do
                                        if main.t_selChars[j] == newCharIdx then main.t_selChars[j] = i end
                                    end
                                    table.remove(main.t_selGrid, newCharIdx)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if addedCount > 0 then main.f_updateRandomChars() end
end

local function loadStages()
    local fileList = getDirectoryFiles("stages")
    if not fileList then return end
    for _, path in ipairs(fileList) do
        local normalizedPath = path:gsub('\\', '/')
        if normalizedPath:lower():match("%.def$") then
            if main.t_stageDef[normalizedPath:lower()] == nil then
                local isValidStage = false
                pcall(function()
                    local f = io.open(normalizedPath, "r")
                    if f then
                        local content = f:read(4096) 
                        f:close()
                        if content and content:lower():match("%[stageinfo%]") then isValidStage = true end
                    end
                end)
                if isValidStage then
                    local stageNo = main.f_addStage(normalizedPath)
                    if stageNo ~= nil then
                        local p = main.t_selStages[stageNo].portrait
                        if p == nil or (type(p) == "table" and p[1] == 9000 and p[2] == 0) then
                            main.t_selStages[stageNo].portrait = "stages/stages.png"
                        end
                        table.insert(main.t_includeStage[1], stageNo)
                        table.insert(main.t_includeStage[2], stageNo)
                        if main.t_selStages[stageNo].order == nil then
                            main.t_selStages[stageNo].order = 1
                            if main.t_orderStages[1] == nil then main.t_orderStages[1] = {} end
                            table.insert(main.t_orderStages[1], stageNo)
                        end
                    end
                end
            end
        end
    end
    if main.f_updateSelectableStages then main.f_updateSelectableStages() end
end

function autoLoader.init()
    local zFile = io.open("save/z_axis_auto.cns", "a")
    if zFile then zFile:close() end

    WriteZAxisSystem()

    local f = io.open("save/autoloader_log.txt", "w")
    if f then f:write("--- AutoLoader V21 Start ---\n"); f:close() end
    
    if SYSTEM_CONFIG.ENABLE_AUTOLOAD_CHARS or SYSTEM_CONFIG.ENABLE_AUTO_MOVELIST or SYSTEM_CONFIG.ENABLE_Z_AXIS == false then 
        loadCharacters() 
    end
    if SYSTEM_CONFIG.ENABLE_AUTOLOAD_STAGES then loadStages() end
end

autoLoader.init()
return autoLoader

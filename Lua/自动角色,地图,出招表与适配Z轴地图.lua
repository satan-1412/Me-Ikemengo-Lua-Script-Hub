-- =========================================================================================
-- 【Ikemen GO 全自动引擎与 3D Z轴横移系统 - 傻瓜式保姆级配置区】
-- =========================================================================================
-- 作者/整合：恶魔王撒旦
-- 说明：一站式管理自动加载功能与 3D 地图的 Z 轴（纵深）移动系统。
--       无需修改任何角色文件！2D 普通地图完美保持原生手感，3D 地图自动接管。
-- =========================================================================================

local SYSTEM_CONFIG = {
    -- =====================================================================================
    -- [ 一、自动化系统基础开关 ] 
    -- 傻瓜说明：true代表开启，false代表关闭，按需修改。
    -- =====================================================================================
    ENABLE_AUTOLOAD_CHARS  = true,  -- true: 开启自动加载角色 / false: 关闭
    ENABLE_AUTOLOAD_STAGES = true,  -- true: 开启自动加载地图 / false: 关闭
    ENABLE_AUTO_MOVELIST   = true,  -- true: 开启自动生成出招表 / false: 关闭

    -- =====================================================================================
    -- [ 二、3D Z轴纵深系统设置 ]
    -- =====================================================================================
    -- 1. 纵深系统总开关
    ENABLE_Z_AXIS = true,           -- true: 允许在特定3D地图中Z轴横向移动 / false: 彻底关闭

    -- 2. 操作模式选择
    -- true  = 【经典模式】(推荐)：使用方向键 ↑ 和 ↓ 进行 Z 轴移动。原本的跳跃和蹲下将被替换为下方的备用键。
    -- false = 【分离模式】：方向键 ↑ 和 ↓ 依然是原生的跳跃和蹲下。Z 轴移动使用你下方的自定义按键。
    USE_UP_DOWN_FOR_Z_MOVE = true,

    -- 3. 自定义按键设置 (必须填写你在 common.cmd 中定义好的按键 name)
    
    -- 【经典模式】(USE_UP_DOWN_FOR_Z_MOVE = true) 时生效：
    -- 因为上下键被拿去移动了，所以你需要指定两个键用来跳跃和下蹲：
    SPARE_JUMP_KEY   = "w",         -- 备用跳跃键 (默认为 w 键)
    SPARE_CROUCH_KEY = "hold_d",    -- 备用下蹲键 (默认为长按 d 键)

    -- 【分离模式】(USE_UP_DOWN_FOR_Z_MOVE = false) 时生效：
    -- 方向键正常跳跃下蹲，你需要指定两个键用来在 Z 轴向里和向外移动：
    CUSTOM_Z_IN_KEY  = "hold_w",    -- 向背景内侧移动的按键 (默认为长按 w 键)
    CUSTOM_Z_OUT_KEY = "hold_d",    -- 向屏幕外侧移动的按键 (默认为长按 d 键)

    -- 4. 移动手感设置
    -- 调整角色在 Z 轴上滑步的速度。
    -- 数值越大移动越快(滑冰感)，数值越小移动越稳重。推荐区间：1.5 到 3.5 之间。
    Z_MOVE_SPEED = "2.2",             
}

--[[
=========================================================================================
【小白专属教程：如何在 common.cmd 中添加自定义按键？】
如果你想使用其他的按键作为控制键，请打开游戏目录下的 data/common.cmd 文件。
在文件靠前的位置（例如 [Defaults] 下方），**追加** 以下代码（千万不要删除原有的任何代码！）：

; --- 复制下方模板 ---
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
; --- 复制结束 ---
=========================================================================================
]]

-- =========================================================================================
-- 以下为核心代码区，请勿随意修改
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
-- [核心] 写入完美 Z 轴系统 (防弹数组拼接 + AI生态对齐锁)
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
        "; A. 智能避让补丁：原生Z轴角色检测",
        "; ==================================================",
        "[State -2, 屏蔽原生控制]",
        "type = AssertSpecial",
        "triggerall = " .. BLOCK .. " = 1",
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "trigger1 = StageVar(playerinfo.topbound) != 0 || StageVar(playerinfo.botbound) != 0",
        "flag = nocrouch",
        "flag2 = nojump",
        "",
        "; ==================================================",
        "; B. 备用跳跃下蹲",
        "; ==================================================",
        "[State -2, 备用跳跃]",
        "type = ChangeState",
        "triggerall = " .. BLOCK .. " = 1 && statetype != A && statetype != L && ctrl",
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "triggerall = StageVar(playerinfo.topbound) != 0 || StageVar(playerinfo.botbound) != 0",
        "trigger1 = command = \"" .. K_JUMP .. "\"",
        "value = 40",
        "",
        "[State -2, 备用下蹲]",
        "type = ChangeState",
        "triggerall = " .. BLOCK .. " = 1 && statetype != A && statetype != L && ctrl",
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "triggerall = StageVar(playerinfo.topbound) != 0 || StageVar(playerinfo.botbound) != 0",
        "trigger1 = command = \"" .. K_CROUCH .. "\"",
        "value = 10",
        "",
        "; ==================================================",
        "; C. 玩家 Z 轴介入",
        "; ==================================================",
        "[State -2, 玩家_向内走]",
        "type = ChangeState",
        "triggerall = AILevel = 0 && statetype != A && statetype != L && ctrl",
        "triggerall = stateno != 85200 && stateno != 85201", 
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "triggerall = StageVar(playerinfo.topbound) != 0 || StageVar(playerinfo.botbound) != 0",
        "trigger1 = command = \"" .. K_IN .. "\"",
        "value = 85200",
        "",
        "[State -2, 玩家_向外走]",
        "type = ChangeState",
        "triggerall = AILevel = 0 && statetype != A && statetype != L && ctrl",
        "triggerall = stateno != 85200 && stateno != 85201", 
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "triggerall = StageVar(playerinfo.topbound) != 0 || StageVar(playerinfo.botbound) != 0",
        "trigger1 = command = \"" .. K_OUT .. "\"",
        "value = 85201",
        "",
        "; ==================================================",
        "; D. AI 战术引擎 (三国战纪大BOSS级：绝对对齐防抽搐)",
        "; ==================================================",
        "[State -2, AI_Z轴战术池_向内闪避与游走]",
        "type = ChangeState",
        "triggerall = AILevel > 0 && statetype != A && statetype != L && ctrl",
        "triggerall = stateno != 85200 && stateno != 85201",
        "triggerall = map(nativeZAxis) = 0 && map(vector_z) = 0 && map(hasZAxis) = 0 && map(ignoreAutoZ) = 0",
        "triggerall = Pos Z > StageVar(playerinfo.topbound) + 10",
        "trigger1 = EnemyNear, NumProj > 0 && random < 900",
        "trigger2 = p2movetype = A && p2bodydist X = [30, 100] && EnemyNear, Pos Z <= Pos Z && random < 700",
        "; 【终极拦截锁】：只要对手在近战区(X<80)且不在同一条线(误差>4)，强制进入走位，绝不挥空拳！",
        "trigger3 = abs(EnemyNear, Pos Z - Pos Z) > 4 && p2bodydist X < 80 && EnemyNear, Pos Z < Pos Z",
        "value = 85200",
        "",
        "[State -2, AI_Z轴战术池_向外闪避与游走]",
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
        "; 专属状态 85200：向内侧移动",
        "; =========================================================",
        "[StateDef 85200]",
        "type = S",
        "movetype = I",
        "physics = S",
        "; 【核心修复】：进入此状态时，默认剥夺控制权（ctrl=0），让AI乖乖走位，彻底根除攻击冲突造成的抽搐",
        "ctrl = 0", 
        "velset = 0,0",
        "",
        "[State 85200, 玩家恢复控制权]",
        "type = CtrlSet",
        "trigger1 = AILevel = 0",
        "value = 1",  "; 但如果当前是玩家操作，瞬间归还控制权，保证玩家能随时打断出招",
        "",
        "[State 85200, 物理躲避微小无敌帧]",
        "type = NotHitBy",
        "trigger1 = time < 8",
        "value = SCA",
        "time = 1",
        "",
        "[State 85200, 绕背自动转身]",
        "type = Turn",
        "trigger1 = p2dist X < 0", 
        "",
        "[State 85200, 动画]",
        "type = ChangeAnim",
        "trigger1 = Anim != 21 && Anim != 20",
        "value = 21",
        "",
        "[State 85200, 基础Z速度]",
        "type = VelSet",
        "trigger1 = 1",
        "z = -" .. SPD,
        "",
        "[State 85200, 玩家_摇杆补偿]",
        "type = VelSet",
        "triggerall = AILevel = 0",
        "trigger1 = command = \"holdfwd\"",
        "x = const(velocity.walk.fwd.x)",
        "",
        "[State 85200, 玩家_摇杆补偿]",
        "type = VelSet",
        "triggerall = AILevel = 0",
        "trigger1 = command = \"holdback\"",
        "x = const(velocity.walk.back.x)",
        "",
        "; --- AI 防御性拉满：物理弧线绕背走位 ---",
        "[State 85200, AI_防守弧线_边闪边退]",
        "type = VelSet",
        "triggerall = AILevel > 0",
        "; 当对手在猛攻且距离极近时，AI不往前送死，而是向后退，配合Z轴形成完美的弧线绕背",
        "trigger1 = p2movetype = A && p2bodydist X < 50",
        "x = const(velocity.walk.back.x)",
        "",
        "[State 85200, AI_常规跟进]",
        "type = VelSet",
        "triggerall = AILevel > 0",
        "triggerall = !(p2movetype = A && p2bodydist X < 50)",
        "trigger1 = p2bodydist X > 60",
        "x = const(velocity.walk.fwd.x)",
        "",
        "[State 85200, 物理边界]",
        "type = PosSet",
        "trigger1 = Pos Z < StageVar(playerinfo.topbound)",
        "z = StageVar(playerinfo.topbound)",
        "",
        "[State 85200, 玩家自然退出]",
        "type = ChangeState",
        "trigger1 = AILevel = 0 && command != \"" .. K_IN .. "\"",
        "value = 0",
        "ctrl = 1",
        "",
        "[State 85200, AI_致命击杀切出]",
        "type = ChangeState",
        "triggerall = AILevel > 0",
        "; 【致命一击】：只有完美走到跟对手Z轴误差<=4的精准水平线，且就在身前(X<80)，才会切回0态并获得ctrl=1起手攻击！",
        "trigger1 = abs(EnemyNear, Pos Z - Pos Z) <= 4 && p2bodydist X < 80", 
        "; 放波安全距离判定",
        "trigger2 = p2bodydist X >= 120 && abs(EnemyNear, Pos Z - Pos Z) <= 15",
        "trigger3 = Pos Z <= StageVar(playerinfo.topbound)",
        "value = 0",
        "ctrl = 1",
        "",
        "; =========================================================",
        "; 专属状态 85201：向外侧移动",
        "; =========================================================",
        "[StateDef 85201]",
        "type = C",
        "movetype = I",
        "physics = C",
        "ctrl = 0",
        "velset = 0,0",
        "",
        "[State 85201, 玩家恢复控制权]",
        "type = CtrlSet",
        "trigger1 = AILevel = 0",
        "value = 1",
        "",
        "[State 85201, 物理躲避微小无敌帧]",
        "type = NotHitBy",
        "trigger1 = time < 8",
        "value = SCA",
        "time = 1",
        "",
        "[State 85201, 绕背自动转身]",
        "type = Turn",
        "trigger1 = p2dist X < 0", 
        "",
        "[State 85201, 动画]",
        "type = ChangeAnim",
        "trigger1 = Anim != 20 && Anim != 21",
        "value = 20",
        "",
        "[State 85201, 基础Z速度]",
        "type = VelSet",
        "trigger1 = 1",
        "z = " .. SPD,
        "",
        "[State 85201, 玩家_摇杆补偿]",
        "type = VelSet",
        "triggerall = AILevel = 0",
        "trigger1 = command = \"holdfwd\"",
        "x = const(velocity.walk.fwd.x)",
        "",
        "[State 85201, 玩家_摇杆补偿]",
        "type = VelSet",
        "triggerall = AILevel = 0",
        "trigger1 = command = \"holdback\"",
        "x = const(velocity.walk.back.x)",
        "",
        "[State 85201, AI_防守弧线_边闪边退]",
        "type = VelSet",
        "triggerall = AILevel > 0",
        "trigger1 = p2movetype = A && p2bodydist X < 50",
        "x = const(velocity.walk.back.x)",
        "",
        "[State 85201, AI_常规跟进]",
        "type = VelSet",
        "triggerall = AILevel > 0",
        "triggerall = !(p2movetype = A && p2bodydist X < 50)",
        "trigger1 = p2bodydist X > 60",
        "x = const(velocity.walk.fwd.x)",
        "",
        "[State 85201, 物理边界]",
        "type = PosSet",
        "trigger1 = Pos Z > StageVar(playerinfo.botbound)",
        "z = StageVar(playerinfo.botbound)",
        "",
        "[State 85201, 玩家自然退出]",
        "type = ChangeState",
        "trigger1 = AILevel = 0 && command != \"" .. K_OUT .. "\"",
        "value = 0",
        "ctrl = 1",
        "",
        "[State 85201, AI_致命击杀切出]",
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
        print("[错误] 无法生成 Z 轴文件！请确保游戏根目录下存在 'save' 文件夹！")
    end
end

-- ========================================================
-- [新增] 动态清理机制：开关关闭时，自动擦除旧的注入痕迹
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
        
        -- 1. 如果 Z 轴总开关已关闭，剔除所有残留的 z_axis_auto.cns 注入（可能是手动添加或旧版本遗留）
        if not SYSTEM_CONFIG.ENABLE_Z_AXIS and lowerLine:match("z_axis_auto%.cns") then
            dropLine = true
            isDirty = true
        end
        
        -- 2. 如果出招表自动生成关闭，剔除强行写入的 movelist.dat
        if not SYSTEM_CONFIG.ENABLE_AUTO_MOVELIST and lowerLine:match("movelist%s*=%s*movelist%.dat") then
            dropLine = true
            isDirty = true
        end
        
        if not dropLine then
            table.insert(fileLines, cleanLine)
        end
    end
    f:close()
    
    -- 如果发现了残留并剔除，则重新覆写保存 def 文件
    if isDirty then
        local fw = io.open(defPath, "wb")
        if fw then
            for _, l in ipairs(fileLines) do fw:write(l .. "\n") end
            fw:close()
            writeLog("[Cleanup] 识别到开关关闭，已清除残留注入: " .. defPath)
        end
    end
end

-- ========================================================
-- 出招表解析及自动加载模块
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
                    -- 【核心改动】在做任何处理前，先根据当前的系统开关执行一次大扫除
                    cleanDefInjections(normalizedPath)
                    
                    -- 大扫除之后，再判断是否需要执行出招表生成
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

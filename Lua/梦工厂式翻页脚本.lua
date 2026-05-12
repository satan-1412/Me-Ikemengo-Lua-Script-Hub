-- =======================================================
-- Ikemen GO 外挂模块：终极分页版 (修复3D选人框距离/错位问题，增加2D/3D适配)
-- =======================================================
local scroll_mod = {}

-- ==========================================
-- ⚙️ 【玩家自定义配置区 / 新手请在这里修改】 ⚙️
-- ==========================================
-- 1. [列数] 你的选人框一行有几个格子？(例如 5)
local CUSTOM_COLS = 8   

-- 2. [行数] 你的选人框一页显示几排？(例如 5)
-- 注意：system.def 里的 rows 必须大于这个数字才能翻页！
-- 比如 system.def 写 rows = 20，这里写 5，就能翻 4 页。
local VISIBLE_ROWS = 10 

-- 3. [自动居中] 选人框如果歪了，是否自动把它挪到屏幕中间？(填 true 或 false)
local AUTO_CENTER = true  

-- 4. [快速翻页] 是否开启光标“双击”或“长按”上下键直接翻一页的功能？
local ENABLE_FAST_JUMP = false  

-- 5. [翻页灵敏度] 快速翻页的判定时间 (默认 9，数字越小越难触发)
local TAP_TIME = 9       

-- 6. [3D透视开关] 你的选人界面是否有 3D 景深/倾斜效果？
-- 如果是纯平面 2D 主题请填 false，防止头像变形或错位！
local ENABLE_3D_GRID = false
-- ==========================================

-- 内部变量，记录原版数据
local original_pos_x = nil
local original_pos_y = nil
local original_cols = nil
local camera_y = 0 -- 记录当前翻到了哪一页

-- 记录玩家光标用来做快速翻页
local cursor_tracker = {
    [1] = { last_y = -1, timer_down = 0, timer_up = 0 },
    [2] = { last_y = -1, timer_down = 0, timer_up = 0 }
}

-- 【核心逻辑 1：重新排布网格坐标】
-- 核心原理：为了防止 3D 景深因为向下滚动而变形，我们“锁定镜头绝对不移动”！
-- 而是把第二页、第三页的角色格子，利用算法强制“重叠绑定”在第一页物理坐标上。
hook.add("start.f_selectReset", "ScrollSelect_Reset", function()
    if not original_cols then original_cols = motif.select_info.columns end
    if not original_pos_x then original_pos_x = motif.select_info.pos[1] end
    if not original_pos_y then original_pos_y = motif.select_info.pos[2] end

    -- 覆盖列数
    motif.select_info.columns = CUSTOM_COLS

    -- 居中补偿：如果缩小了列数，把整个选人框往中间挪一挪
    if AUTO_CENTER and original_cols > CUSTOM_COLS then
        local cell_w = motif.select_info.cell.size[1] + motif.select_info.cell.spacing[1]
        local diff_w = (original_cols - CUSTOM_COLS) * cell_w
        motif.select_info.pos[1] = original_pos_x + (diff_w / 2)
    else
        motif.select_info.pos[1] = original_pos_x
    end

    -- 强制锁定镜头 Y 轴，绝不往下滚动
    motif.select_info.pos[2] = original_pos_y
    camera_y = 0

    cursor_tracker[1] = { last_y = -1, timer_down = 0, timer_up = 0 }
    cursor_tracker[2] = { last_y = -1, timer_down = 0, timer_up = 0 }

    -- 重新生成底层的坐标网格
    local cnt = motif.select_info.columns + 1
    local row = 1
    local col = 0
    start.t_grid = {[row] = {}}
    
    for i = 1, motif.select_info.rows * motif.select_info.columns do
        if i == cnt then
            row = row + 1
            cnt = cnt + motif.select_info.columns
            start.t_grid[row] = {}
        end
        col = #start.t_grid[row] + 1
        
        -- 【关键修复】：利用取余(%)算法，计算当前行在“屏幕上”属于第几排
        -- 举例：第 6 排 (row=6) 在屏幕上等于第 1 排 (screen_r=0)
        local screen_r = (row - 1) % VISIBLE_ROWS
        
        -- 默认使用 2D 基础间距和 0 偏移
        local current_spacing_x = motif.select_info.cell.spacing[1]
        local current_spacing_y = motif.select_info.cell.spacing[2]
        local current_offset_x = 0
        local current_offset_y = 0

        -- 如果开启了 3D 模式，则获取第一页专属的 3D 倾斜间距和偏移量
        if ENABLE_3D_GRID then
            local p_spacing = getCellSpacing(col - 1, screen_r)
            local p_offset = getCellOffset(col - 1, screen_r)
            current_spacing_x = p_spacing[1]
            current_spacing_y = p_spacing[2]
            current_offset_x = p_offset[1]
            current_offset_y = p_offset[2]
        end
        
        start.t_grid[row][col] = {
            -- X轴正常计算左右距离
            x = (col - 1) * (motif.select_info.cell.size[1] + current_spacing_x) + current_offset_x,
            -- Y轴强制使用相对排数(screen_r)计算。
            -- 这样不管排到第几页，垂直距离(Y)永远完美对应第一页的距离，不会挤在一起！
            y = screen_r * (motif.select_info.cell.size[2] + current_spacing_y) + current_offset_y
        }
        
        -- 读取引擎本来的人物数据并塞入格子
        local selData = start.f_selGrid(i)
        if selData and selData.char ~= nil then
            start.t_grid[row][col].char = selData.char
            start.t_grid[row][col].char_ref = selData.char_ref
            start.t_grid[row][col].hidden = selData.hidden
        end
        
        -- 判断是否跳过该格子的渲染
        local overrideSkip = false
        if ENABLE_3D_GRID then
            overrideSkip = getCellSkip(col - 1, screen_r)
        end

        if (selData and selData.skip == 1) or overrideSkip then
            start.t_grid[row][col].skip = 1
        end
    end

    start.needUpdateDrawList = true
end)

-- 【核心逻辑 2：屏蔽不可见区域，只渲染当前页的内容】
local old_updateDrawList = start.updateDrawList
start.updateDrawList = function()
    local drawList = {}
    if not motif or not motif.select_info or not start.t_grid then return drawList end
    
    -- 计算当前在哪一页（从第几排画到第几排）
    local start_row = camera_y + 1
    local end_row = start_row + VISIBLE_ROWS - 1
    if end_row > motif.select_info.rows then end_row = motif.select_info.rows end

    -- 只循环渲染属于当前页的数据
    for row = start_row, end_row do
        local row_grid = start.t_grid[row]
        if row_grid then
            for col = 1, motif.select_info.columns do
                local t = row_grid[col]
                local c = col - 1
                
                -- 同样使用取余，调用第一页的参数
                local screen_r = (row - 1) % VISIBLE_ROWS
                
                if t and t.skip ~= 1 then
                    local cellIndex = (row - 1) * motif.select_info.columns + col
                    local charData = start.f_selGrid(cellIndex)
                    
                    -- 获取渲染参数（区分 2D 和 3D 模式）
                    local function getTransforms(base)
                        -- 如果是平面 2D，直接返回基础参数，不进行任何 3D 变形计算
                        if not ENABLE_3D_GRID then
                            return {
                                facing      = base.facing,
                                scale       = base.scale,
                                xshear      = base.xshear,
                                angle       = base.angle,
                                xangle      = base.xangle,
                                yangle      = base.yangle,
                                projection  = base.projection,
                                focallength = base.focallength
                            }
                        end
                        
                        -- 如果是 3D，则严格限制只读取第一页的透视视角形变参数
                        return {
                            facing      = getCellFacing(base.facing, c, screen_r),
                            scale       = getCellTransform(c, screen_r, "scale", base.scale),
                            xshear      = getCellTransform(c, screen_r, "xshear", base.xshear),
                            angle       = getCellTransform(c, screen_r, "angle", base.angle),
                            xangle      = getCellTransform(c, screen_r, "xangle", base.xangle),
                            yangle      = getCellTransform(c, screen_r, "yangle", base.yangle),
                            projection  = getCellTransform(c, screen_r, "projection", base.projection),
                            focallength = getCellTransform(c, screen_r, "focallength", base.focallength)
                        }
                    end

                    if charData then
                        -- 1. 画格子背景
                        if (charData.char ~= nil and (charData.hidden == 0 or charData.hidden == 3)) or motif.select_info.showemptyboxes then
                            local item = getTransforms(motif.select_info.cell.bg)
                            item.anim = motif.select_info.cell.bg.AnimData
                            item.x = motif.select_info.pos[1] + t.x
                            item.y = motif.select_info.pos[2] + t.y
                            table.insert(drawList, item)
                        end
                        
                        -- 2. 画问号（随机选人）
                        if charData.char == 'randomselect' or charData.hidden == 3 then
                            local item = getTransforms(motif.select_info.cell.random)
                            item.anim = motif.select_info.cell.random.AnimData
                            item.x = motif.select_info.pos[1] + t.x + motif.select_info.portrait.offset[1]
                            item.y = motif.select_info.pos[2] + t.y + motif.select_info.portrait.offset[2]
                            table.insert(drawList, item)
                            
                        -- 3. 画人物小头像
                        elseif charData.char_ref ~= nil and charData.hidden == 0 then
                            local item = getTransforms(motif.select_info.portrait)
                            item.anim = charData.cell_data
                            item.x = motif.select_info.pos[1] + t.x + motif.select_info.portrait.offset[1]
                            item.y = motif.select_info.pos[2] + t.y + motif.select_info.portrait.offset[2]
                            
                            -- 修正部分高清/特殊人物小头像的缩放比例
                            if item.scale ~= nil then
                                local charInfo = main.t_selChars[charData.char_ref + 1]
                                if charInfo then
                                    local portraitScale = charInfo.portraitscale or 1
                                    local charLocalcoord = charInfo.localcoord or motif.info.localcoord[1]
                                    local resFix = portraitScale * motif.info.localcoord[1] / charLocalcoord
                                    item.scale = {
                                        item.scale[1] * resFix,
                                        item.scale[2] * resFix
                                    }
                                end
                            end
                            table.insert(drawList, item)
                        end
                    end
                end
            end
        end
    end
    return drawList
end

-- 【核心逻辑 3：监听玩家光标，触发翻页判定】
hook.add("start.f_selectScreen", "ScrollSelect_Loop", function()
    -- 这一行代码确保原版镜头不乱跑
    if not original_pos_y then original_pos_y = motif.select_info.pos[2] end

    -- 如果你开启了“快速翻页”功能，走这里
    if ENABLE_FAST_JUMP then
        for p = 1, 2 do
            if start.p[p] and not start.p[p].selEnd and start.c[p] then
                local curr_y = start.c[p].selY
                if cursor_tracker[p].last_y == -1 then cursor_tracker[p].last_y = curr_y end
                local diff = curr_y - cursor_tracker[p].last_y
                local pData = start.f_getCursorData(p)

                -- 往下连按判定
                if diff == 1 then
                    if cursor_tracker[p].timer_down > 0 then
                        local target = curr_y + VISIBLE_ROWS
                        if target >= motif.select_info.rows then target = motif.select_info.rows - 1 end
                        start.c[p].selY = target
                        start.c[p].cell = target * motif.select_info.columns + start.c[p].selX
                        cursor_tracker[p].timer_down = 0 
                        curr_y = target
                        if pData.cursor.move.snd then sndPlay(motif.Snd, pData.cursor.move.snd[1], pData.cursor.move.snd[2]) end
                    else
                        cursor_tracker[p].timer_down = TAP_TIME
                    end
                -- 往上连按判定
                elseif diff == -1 then
                    if cursor_tracker[p].timer_up > 0 then
                        local target = curr_y - VISIBLE_ROWS
                        if target < 0 then target = 0 end
                        start.c[p].selY = target
                        start.c[p].cell = target * motif.select_info.columns + start.c[p].selX
                        cursor_tracker[p].timer_up = 0 
                        curr_y = target
                        if pData.cursor.move.snd then sndPlay(motif.Snd, pData.cursor.move.snd[1], pData.cursor.move.snd[2]) end
                    else
                        cursor_tracker[p].timer_up = TAP_TIME
                    end
                end
                if cursor_tracker[p].timer_down > 0 then cursor_tracker[p].timer_down = cursor_tracker[p].timer_down - 1 end
                if cursor_tracker[p].timer_up > 0 then cursor_tracker[p].timer_up = cursor_tracker[p].timer_up - 1 end
                cursor_tracker[p].last_y = curr_y
            end
        end
    end

    -- 正常状态下：获取当前 1P 或 2P 的光标到底停留在第几行
    local target_row = 0
    if start.p[1] and not start.p[1].selEnd then 
        target_row = start.c[1].selY
    elseif start.p[2] and not start.p[2].selEnd then 
        target_row = start.c[2].selY 
    end

    -- 计算出当前行数应该触发哪一个分页 (0 = 第一页, 5 = 第二页, 10 = 第三页 ...)
    local new_camera_y = math.floor(target_row / VISIBLE_ROWS) * VISIBLE_ROWS

    -- 只有当分页发生变化时，才通知引擎刷新画面（极大减少掉帧）
    if new_camera_y ~= camera_y then
        camera_y = new_camera_y
        start.needUpdateDrawList = true
    end
end)

return scroll_mod

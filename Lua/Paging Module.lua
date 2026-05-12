-- =======================================================
-- Ikemen GO Addon Module: Ultimate Pagination Version 
-- (Fixes 3D select screen distance/misalignment issues, adds 2D/3D compatibility)
-- =======================================================
local scroll_mod = {}

-- ==========================================
-- ⚙️ [User Custom Configuration Area / Beginners modify here] ⚙️
-- ==========================================
-- 1. [Columns] How many slots per row in your select screen? (e.g., 5)
local CUSTOM_COLS = 8   

-- 2. [Rows] How many rows displayed per page? (e.g., 5)
-- Note: 'rows' in system.def MUST be greater than this number for pagination to work!
-- For example, if system.def has rows = 20, and you set this to 5, you get 4 pages.
local VISIBLE_ROWS = 10 

-- 3. [Auto Center] If the select grid is off-center, automatically move it to the middle of the screen? (true or false)
local AUTO_CENTER = true  

-- 4. [Fast Paging] Enable "double-tap" or "long-press" up/down to flip a whole page?
local ENABLE_FAST_JUMP = false  

-- 5. [Paging Sensitivity] Fast paging trigger time (Default is 9, lower numbers make it harder to trigger)
local TAP_TIME = 9       

-- 6. [3D Perspective Toggle] Does your select screen have 3D depth/tilt effects?
-- Set to false for flat 2D themes to prevent portrait distortion or misalignment!
local ENABLE_3D_GRID = true
-- ==========================================

-- Internal variables to record original data
local original_pos_x = nil
local original_pos_y = nil
local original_cols = nil
local camera_y = 0 -- Records which page we are currently on

-- Track player cursor for fast paging
local cursor_tracker = {
    [1] = { last_y = -1, timer_down = 0, timer_up = 0 },
    [2] = { last_y = -1, timer_down = 0, timer_up = 0 }
}

-- [Core Logic 1: Rearrange Grid Coordinates]
-- Core Principle: To prevent 3D depth deformation when scrolling down, we "lock the camera to absolutely not move"!
-- Instead, we algorithmically force the character slots of the 2nd, 3rd, etc. pages to "overlap and bind" to the physical coordinates of the 1st page.
hook.add("start.f_selectReset", "ScrollSelect_Reset", function()
    if not original_cols then original_cols = motif.select_info.columns end
    if not original_pos_x then original_pos_x = motif.select_info.pos[1] end
    if not original_pos_y then original_pos_y = motif.select_info.pos[2] end

    -- Override columns
    motif.select_info.columns = CUSTOM_COLS

    -- Centering compensation: If columns were reduced, move the entire grid towards the center
    if AUTO_CENTER and original_cols > CUSTOM_COLS then
        local cell_w = motif.select_info.cell.size[1] + motif.select_info.cell.spacing[1]
        local diff_w = (original_cols - CUSTOM_COLS) * cell_w
        motif.select_info.pos[1] = original_pos_x + (diff_w / 2)
    else
        motif.select_info.pos[1] = original_pos_x
    end

    -- Force lock camera Y-axis, never scroll down
    motif.select_info.pos[2] = original_pos_y
    camera_y = 0

    cursor_tracker[1] = { last_y = -1, timer_down = 0, timer_up = 0 }
    cursor_tracker[2] = { last_y = -1, timer_down = 0, timer_up = 0 }

    -- Regenerate the underlying coordinate grid
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
        
        -- [Key Fix]: Use modulo (%) algorithm to calculate which row the current row belongs to "on screen"
        -- Example: The 6th row (row=6) is equal to the 1st row on the screen (screen_r=0)
        local screen_r = (row - 1) % VISIBLE_ROWS
        
        -- Default to using 2D base spacing and 0 offset
        local current_spacing_x = motif.select_info.cell.spacing[1]
        local current_spacing_y = motif.select_info.cell.spacing[2]
        local current_offset_x = 0
        local current_offset_y = 0

        -- If 3D mode is enabled, get the 3D tilt spacing and offset exclusive to the first page
        if ENABLE_3D_GRID then
            local p_spacing = getCellSpacing(col - 1, screen_r)
            local p_offset = getCellOffset(col - 1, screen_r)
            current_spacing_x = p_spacing[1]
            current_spacing_y = p_spacing[2]
            current_offset_x = p_offset[1]
            current_offset_y = p_offset[2]
        end
        
        start.t_grid[row][col] = {
            -- X-axis: Calculate left/right distance normally
            x = (col - 1) * (motif.select_info.cell.size[1] + current_spacing_x) + current_offset_x,
            -- Y-axis: Force use of relative row count (screen_r) for calculation.
            -- This way, no matter which page it is, the vertical distance (Y) perfectly matches the distance of the 1st page, avoiding overlapping!
            y = screen_r * (motif.select_info.cell.size[2] + current_spacing_y) + current_offset_y
        }
        
        -- Read the engine's original character data and put it in the grid
        local selData = start.f_selGrid(i)
        if selData and selData.char ~= nil then
            start.t_grid[row][col].char = selData.char
            start.t_grid[row][col].char_ref = selData.char_ref
            start.t_grid[row][col].hidden = selData.hidden
        end
        
        -- Determine whether to skip rendering for this slot
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

-- [Core Logic 2: Mask invisible areas, render only current page content]
local old_updateDrawList = start.updateDrawList
start.updateDrawList = function()
    local drawList = {}
    if not motif or not motif.select_info or not start.t_grid then return drawList end
    
    -- Calculate current page (which rows to draw)
    local start_row = camera_y + 1
    local end_row = start_row + VISIBLE_ROWS - 1
    if end_row > motif.select_info.rows then end_row = motif.select_info.rows end

    -- Only loop and render data belonging to the current page
    for row = start_row, end_row do
        local row_grid = start.t_grid[row]
        if row_grid then
            for col = 1, motif.select_info.columns do
                local t = row_grid[col]
                local c = col - 1
                
                -- Likewise use modulo to call the 1st page's parameters
                local screen_r = (row - 1) % VISIBLE_ROWS
                
                if t and t.skip ~= 1 then
                    local cellIndex = (row - 1) * motif.select_info.columns + col
                    local charData = start.f_selGrid(cellIndex)
                    
                    -- Get render parameters (distinguish between 2D and 3D modes)
                    local function getTransforms(base)
                        -- If it's flat 2D, return base parameters directly without any 3D deformation calculations
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
                        
                        -- If it's 3D, strictly limit to reading the 1st page's perspective view deformation parameters
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
                        -- 1. Draw cell background
                        if (charData.char ~= nil and (charData.hidden == 0 or charData.hidden == 3)) or motif.select_info.showemptyboxes then
                            local item = getTransforms(motif.select_info.cell.bg)
                            item.anim = motif.select_info.cell.bg.AnimData
                            item.x = motif.select_info.pos[1] + t.x
                            item.y = motif.select_info.pos[2] + t.y
                            table.insert(drawList, item)
                        end
                        
                        -- 2. Draw question mark (random select)
                        if charData.char == 'randomselect' or charData.hidden == 3 then
                            local item = getTransforms(motif.select_info.cell.random)
                            item.anim = motif.select_info.cell.random.AnimData
                            item.x = motif.select_info.pos[1] + t.x + motif.select_info.portrait.offset[1]
                            item.y = motif.select_info.pos[2] + t.y + motif.select_info.portrait.offset[2]
                            table.insert(drawList, item)
                            
                        -- 3. Draw character small portrait
                        elseif charData.char_ref ~= nil and charData.hidden == 0 then
                            local item = getTransforms(motif.select_info.portrait)
                            item.anim = charData.cell_data
                            item.x = motif.select_info.pos[1] + t.x + motif.select_info.portrait.offset[1]
                            item.y = motif.select_info.pos[2] + t.y + motif.select_info.portrait.offset[2]
                            
                            -- Fix scaling ratios for some HD/special character small portraits
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

-- [Core Logic 3: Listen to player cursor, trigger paging logic]
hook.add("start.f_selectScreen", "ScrollSelect_Loop", function()
    -- This line ensures the original camera doesn't go rogue
    if not original_pos_y then original_pos_y = motif.select_info.pos[2] end

    -- If you enabled the "Fast Paging" function, execute here
    if ENABLE_FAST_JUMP then
        for p = 1, 2 do
            if start.p[p] and not start.p[p].selEnd and start.c[p] then
                local curr_y = start.c[p].selY
                if cursor_tracker[p].last_y == -1 then cursor_tracker[p].last_y = curr_y end
                local diff = curr_y - cursor_tracker[p].last_y
                local pData = start.f_getCursorData(p)

                -- Downward sequential press detection
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
                -- Upward sequential press detection
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

    -- Normal state: Get which row the 1P or 2P cursor is currently on
    local target_row = 0
    if start.p[1] and not start.p[1].selEnd then 
        target_row = start.c[1].selY
    elseif start.p[2] and not start.p[2].selEnd then 
        target_row = start.c[2].selY 
    end

    -- Calculate which page the current row should trigger (0 = 1st page, 5 = 2nd page, 10 = 3rd page...)
    local new_camera_y = math.floor(target_row / VISIBLE_ROWS) * VISIBLE_ROWS

    -- Only notify the engine to refresh the screen when the page changes (greatly reduces frame drops)
    if new_camera_y ~= camera_y then
        camera_y = new_camera_y
        start.needUpdateDrawList = true
    end
end)

return scroll_mod

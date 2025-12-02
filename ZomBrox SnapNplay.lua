----------------------------------------------------------------
-- SNAP & PLAY RECORDER WITH SEARCHIMAGENEW + COORD SWIPE + PREVIEW
-- Single-file AnkuLua script
----------------------------------------------------------------

TRUE = true
ROOT = scriptPath()
local SCRIPT_STEPS = {}
local IMG_COUNTER = 1

----------------------------------------------------------------
-- Libraries
----------------------------------------------------------------
dofile(scriptPath() .. "commonLib.lua")
dofile(scriptPath() .. "luaLib.lua")


----------------------------------------------------------------
-- Config variables
----------------------------------------------------------------
CFG_FOLDER_NAME = ""
CFG_IMMERSIVE   = false
CFG_ACCURACY    = 0.85
CFG_DEBUG       = false
CFG_SWIPE_DURATION = 0.4
PATH_TO_IMAGES_FOLDER = ""
LOG_TOAST = true
LOG_FILE = ""

----------------------------------------------------------------
-- Input guards
----------------------------------------------------------------
local function sanitizeFolderName(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        name = os.date("Project_%Y%m%d_%H%M%S")
    end
    -- replace problematic characters so we don't write outside the script dir
    name = name:gsub("[^%w%-_]", "_")
    return name
end

local function clampAccuracy(val)
    val = tonumber(val) or CFG_ACCURACY
    if val < 0.5 then val = 0.5 end
    if val > 0.99 then val = 0.99 end
    return val
end

local function clampSwipeDuration(val)
    val = tonumber(val) or CFG_SWIPE_DURATION
    if val < 0.05 then val = 0.05 end
    if val > 5 then val = 5 end
    return val
end

local function safeMkdir(path)
    if not path or path == "" then return end
    local ok = false
    if mkdir then ok = pcall(mkdir, path) end
    if not ok then
        local lfs_ok, lfs = pcall(require, "lfs")
        if lfs_ok and lfs then pcall(lfs.mkdir, path) end
    end
end

----------------------------------------------------------------
-- Screen + Regions (will be re-evaluated after dialog)
----------------------------------------------------------------
local screen    = getAppUsableScreenSize()
local SW, SH    = screen:getX(), screen:getY()
local DESIGN_W, DESIGN_H = SW, SH

local Screen_Center     = string.format("%d,%d", SW/2, SH/2)
local Home_Screen_Region= Region((SW/2)-20, 0, 40, 40)
local Upper_Half        = Region(0, 0, SW, SH/2)
local Upper_Left        = Region(0, 0, SW/2, SH/2)
local Upper_Right       = Region(SW/2, 0, SW/2, SH/2)
local Lower_Half        = Region(0, SH/2, SW, SH/2)
local Lower_Left        = Region(0, SH/2, SW/2, SH/2)
local Lower_Right       = Region(SW/2, SH/2, SW/2, SH/2)
local Lower_Most_Half   = Region(0, SH - SH/14, SW, SH/14)
local Agnes_Region      = Region(0, math.floor(SH * 0.08),
                                 math.floor(SW * 0.30),
                                 math.floor(SH * 0.42))

-- Map region names to Region objects (for detection / reference)
local REGION_MAP = {
    { Agnes_Region,    "Agnes_Region"    },
    { Lower_Most_Half, "Lower_Most_Half" },
    { Upper_Left,      "Upper_Left"      },
    { Upper_Right,     "Upper_Right"     },
    { Upper_Half,      "Upper_Half"      },
    { Lower_Left,      "Lower_Left"      },
    { Lower_Right,     "Lower_Right"     },
    { Lower_Half,      "Lower_Half"      },
}

----------------------------------------------------------------
-- Helper: detect which named region a point belongs to
----------------------------------------------------------------
local function pointIn(reg, x, y)
    return x >= reg:getX()
       and x <= reg:getX() + reg:getW()
       and y >= reg:getY()
       and y <= reg:getY() + reg:getH()
end

local function detectRegionFromPoint(x, y)
    -- check named regions first
    for _, pair in ipairs(REGION_MAP) do
        local R, name = pair[1], pair[2]
        if pointIn(R, x, y) then
            return name
        end
    end

    -- simple fallback by quadrants
    if y < SH/2 then
        if x < SW/2 then return "Upper_Left" else return "Upper_Right" end
    else
        if x < SW/2 then return "Lower_Left" else return "Lower_Right" end
    end
end

----------------------------------------------------------------
-- Dialogs
----------------------------------------------------------------
local dialogs = {

    config = function()
        dialogInit()
        addTextView("\nPROJECT SETUP\n-----------------------")
        newRow()
        addTextView("Folder Name: ")
        addEditText("CFG_FOLDER_NAME", "MyProject")

        newRow()
        addTextView("Immersive Mode: ")
        addCheckBox("CFG_IMMERSIVE", "", false)

        newRow()
        addTextView("Image Accuracy (0.7–0.99): ")
        addEditNumber("CFG_ACCURACY", 0.85)

        newRow()
        addTextView("Debug Mode: ")
        addCheckBox("CFG_DEBUG", "", false)

        newRow()
        addTextView("Swipe Duration (s): ")
        addEditNumber("CFG_SWIPE_DURATION", 0.4)

        dialogShowFullScreen("Start New Project")
    end,

    action_menu = function()
        dialogInit()
        addTextView("FOLDER: " .. CFG_FOLDER_NAME ..
                    " | Steps: " .. #SCRIPT_STEPS)
        addSeparator()
        addRadioGroup("REC_OP", 1)
        addRadioButton("1. Find Image & Click", 1)
        addRadioButton("2. Find Image & Wait", 2)
        addRadioButton("3. Click Region (box)", 3)
        addRadioButton("4. Swipe (drag)", 4)
        addRadioButton("5. Wait Seconds", 5)
        addRadioButton("6. If Image A then B", 6)
        addSeparator()
        addRadioButton(">>> FINISH & SAVE <<<", 99)
        addRadioButton("EXIT", 100)
        dialogShowFullScreen("Zombrox Recorder")
    end,

    askFilename = function(defaultName)
        dialogInit()
        addTextView("Rename snapshot (no .png):")
        newRow()
        addEditText("USER_IMG_NAME", defaultName)
        dialogShow("Snapshot Name")
    end,

    get_wait_time = function()
        dialogInit()
        addTextView("Seconds to wait:")
        addEditNumber("WAIT_TIME", 2)
        dialogShow("Wait Time")
    end
}

----------------------------------------------------------------
-- INITIAL CONFIG
----------------------------------------------------------------
dialogs.config()

-- update values after dialog
CFG_FOLDER_NAME = sanitizeFolderName(CFG_FOLDER_NAME)
CFG_ACCURACY    = clampAccuracy(CFG_ACCURACY)
CFG_IMMERSIVE   = CFG_IMMERSIVE == true
CFG_DEBUG       = CFG_DEBUG == true
CFG_SWIPE_DURATION = clampSwipeDuration(CFG_SWIPE_DURATION)
screen    = getAppUsableScreenSize()
SW, SH    = screen:getX(), screen:getY()

Screen_Center     = string.format("%d,%d", SW/2, SH/2)
Home_Screen_Region= Region((SW/2)-20, 0, 40, 40)
Upper_Half        = Region(0, 0, SW, SH/2)
Upper_Left        = Region(0, 0, SW/2, SH/2)
Upper_Right       = Region(SW/2, 0, SW/2, SH/2)
Lower_Half        = Region(0, SH/2, SW, SH/2)
Lower_Left        = Region(0, SH/2, SW/2, SH/2)
Lower_Right       = Region(SW/2, SH/2, SW/2, SH/2)
Lower_Most_Half   = Region(0, SH - SH/14, SW, SH/14)
Agnes_Region      = Region(0, math.floor(SH * 0.08),
                           math.floor(SW * 0.30),
                           math.floor(SH * 0.42))

REGION_MAP = {
    { Agnes_Region,    "Agnes_Region"    },
    { Lower_Most_Half, "Lower_Most_Half" },
    { Upper_Left,      "Upper_Left"      },
    { Upper_Right,     "Upper_Right"     },
    { Upper_Half,      "Upper_Half"      },
    { Lower_Left,      "Lower_Left"      },
    { Lower_Right,     "Lower_Right"     },
    { Lower_Half,      "Lower_Half"      },
}

setImmersiveMode(CFG_IMMERSIVE)

-- Set script dimensions BEFORE creating paths
SCRIPT_DIMENSION = CFG_IMMERSIVE and getRealScreenSize():getX() or getAppUsableScreenSize():getX()
Settings:setScriptDimension(true, SCRIPT_DIMENSION)
Settings:setCompareDimension(true, SCRIPT_DIMENSION)

-- Create folder and set image path
PATH_TO_IMAGES_FOLDER = ROOT .. CFG_FOLDER_NAME .. "/"
safeMkdir(PATH_TO_IMAGES_FOLDER)
setImagePath(PATH_TO_IMAGES_FOLDER)
LOG_FILE = PATH_TO_IMAGES_FOLDER .. "playback.log"

----------------------------------------------------------------
-- Recorder helpers
----------------------------------------------------------------
local function log(msg)
    local line = os.date("%H:%M:%S ") .. msg
    if LOG_TOAST then toast(msg) end
    if LOG_FILE and LOG_FILE ~= "" then
        pcall(function()
            local f = io.open(LOG_FILE, "a+")
            if f then f:write(line .. "\n") f:close() end
        end)
    end
end

local function saveImageCrop(region, baseName)
    local filename = baseName .. ".png"
    region:save(filename)  -- saves into PATH_TO_IMAGES_FOLDER
    return filename
end

local function addStep(actionType, data, description)
    local step = { type = actionType, data = data, desc = description }
    table.insert(SCRIPT_STEPS, step)
    toast("Recorded: " .. description)
end

local function getRegionUser()
    toast("Draw a region")
    local action, locTable = getTouchEvent()
    if action == "dragDrop" or action == "swipe" then
        local l1, l2 = locTable[1], locTable[2]
        local x = math.min(l1.x, l2.x)
        local y = math.min(l1.y, l2.y)
        local w = math.abs(l1.x - l2.x)
        local h = math.abs(l1.y - l2.y)
        local reg = Region(x, y, w, h)
        reg:highlight(0.5)
        return reg
    end
    return nil
end

-- visual preview for swipe
local function previewSwipe(p1, p2)
    local size = 50
    local r1 = Region(p1.x - size/2, p1.y - size/2, size, size)
    local r2 = Region(p2.x - size/2, p2.y - size/2, size, size)

    local minX = math.min(p1.x, p2.x)
    local maxX = math.max(p1.x, p2.x)
    local minY = math.min(p1.y, p2.y)
    local maxY = math.max(p1.y, p2.y)
    local box = Region(minX, minY, maxX - minX, maxY - minY)

    setHighlightStyle(0x66ffff00, true)
    r1:highlight()
    r2:highlight()
    box:highlight()
    wait(0.5)
    r1:highlightOff()
    r2:highlightOff()
    box:highlightOff()
end

local function getSwipeUser()
    toast("Swipe / drag from point A to point B")
    local action, locTable = getTouchEvent()
    
    -- Debug: show what action was detected
    if action then
        toast("Detected action: " .. tostring(action))
    else
        toast("No action detected")
        return nil, nil
    end
    
    if action == "swipe" or action == "dragDrop" then
        local p1 = locTable[1]
        local p2 = locTable[#locTable] or locTable[2]
        
        if p1 and p2 then
            -- Extract coordinates using getX() and getY() methods
            local x1, y1 = p1:getX(), p1:getY()
            local x2, y2 = p2:getX(), p2:getY()
            
            toast(string.format("Swipe: (%d,%d) -> (%d,%d)", x1, y1, x2, y2))
            
            -- Create simple point tables for storage
            local point1 = {x = x1, y = y1}
            local point2 = {x = x2, y = y2}
            
            previewSwipe(point1, point2)
            return point1, point2
        else
            toast("Error: Missing swipe points")
        end
    else
        toast("Please use swipe gesture, not " .. tostring(action))
    end
    
    return nil, nil
end

----------------------------------------------------------------
-- Helper functions (SearchImageNew / ClickImg / WaitExists)
----------------------------------------------------------------
function get_file_name(path)
    return string.match(path, "([^/]+)$") or path
end

function Press(loc, times)
    times = times or 1
    for i = 1, times do
        click(loc)
        wait(0.1)
    end
end

-- NOTE: this function body is used in generated scripts, so it still
-- contains CFG_ACCURACY inside the header template.
function SearchImageNew(target, boxRegion, maxScore, Color, Mask, Time)
    if (target.target) then
        boxRegion, maxScore, Color, Mask, Time, target =
          target.region, target.score, target.color, target.mask, target.ttime, target.target
    end
    Time, Color, Mask, maxScore = Time or 0, Color or false, Mask or false, maxScore or CFG_ACCURACY
    local TImage = target
    if type(target) ~= "table" then TImage = {target} end
    local result = {x = nil, y = nil, xy = nil, name = nil, score=maxScore}
    local Search_Timer = Timer()
    repeat
        for i, t in ipairs(TImage) do
            local PatternBuilder, Cur_Image
            PatternBuilder = Pattern(t)
            if (Color) then PatternBuilder = PatternBuilder:color() end
            if (Mask)  then PatternBuilder = PatternBuilder:mask()  end
            if (boxRegion) then
                Cur_Image = boxRegion:exists(PatternBuilder, 0)
            else
                Cur_Image = exists(PatternBuilder, 0)
            end
            if (Cur_Image) then
                local Cur_Score = Cur_Image:getScore()
                if (Cur_Score >= maxScore) then
                    local center = Cur_Image:getCenter()
                    local X, Y   = center:getX(), center:getY()
                    local W, H   = Cur_Image:getW(), Cur_Image:getH()
                    local SX, SY = Cur_Image:getX(), Cur_Image:getY()
                    local R      = Region(X - (W / 2), Y - (H / 2), W, H)
                    maxScore = Cur_Score
                    result = {
                        x = X, y = Y, xy = center, name = get_file_name(TImage[i]),
                        score=maxScore, w = W, h = H, r = R, sx = SX, sy = SY,
                        loc = Location(X,Y)
                    }
                end
            else
                Cur_Image = nil
            end
        end
    until(result.name) or (Search_Timer:check() > Time)
    Search_Timer = nil
    target, boxRegion, maxScore, Color, Mask, Time = nil, nil, nil, nil, nil, nil
    return result
end

function ClickImg(image, region, score, color, mask, waitTime)
    score    = score    or CFG_ACCURACY
    waitTime = waitTime or 0
    color    = color    or false
    mask     = mask     or false

    local timer = Timer()
    repeat
        local result = SearchImageNew(image, region, score, color, mask, 0)
        if result and result.xy then
            Press(result.xy, 1)
            return true, result
        end
        if waitTime > 0 then
            wait(0.2)
        end
    until (waitTime == 0) or (timer:check() >= waitTime)
    return false, nil
end

function WaitExists(image, timeout, region, score, color, mask)
    timeout = timeout or 0
    score   = score   or CFG_ACCURACY
    local timer = Timer()
    repeat
        local result = SearchImageNew(image, region, score, color, mask, 0)
        if (result and result.name) then
            return true, result
        end
        wait(0.2)
    until (timer:check() >= timeout)
    return false
end

----------------------------------------------------------------
-- Generator: produce output .lua file using recorded steps
----------------------------------------------------------------
local function generateScript()
    local outputPath = ROOT .. CFG_FOLDER_NAME .. ".lua"
    local f = io.open(outputPath, "w+")
    if not f then
        simpleDialog("Error", "Cannot write file:\\n" .. outputPath)
        return
    end

    local immersiveLiteral = (CFG_IMMERSIVE == true) and "true" or "false"
    local debugLiteral = (CFG_DEBUG == true) and "true" or "false"
    local header = table.concat({
        "----------------------------------------------------------------",
        "-- GENERATED SCRIPT: %s",
        "-- Auto-created by Snap & Play Recorder ZomBrox Advanced Version",
        "----------------------------------------------------------------",
        "",
        "local CFG_IMMERSIVE = %s",
        "local CFG_ACCURACY  = %s",
        "local CFG_DEBUG     = %s",
        "",
        "local root    = scriptPath()",
        "local imgPath = root .. \"%s/\"",
        "local function safeMkdir(path)",
        "    if not path or path == \"\" then return end",
        "    local ok = false",
        "    if mkdir then ok = pcall(mkdir, path) end",
        "    if not ok then",
        "        local lfs_ok, lfs = pcall(require, \"lfs\")",
        "        if lfs_ok and lfs then pcall(lfs.mkdir, path) end",
        "    end",
        "end",
        "safeMkdir(imgPath)",
        "local LOG_TOAST = true",
        "local LOG_FILE = imgPath .. \"playback.log\"",
        "setImmersiveMode(CFG_IMMERSIVE)",
        "local DESIGN_W = %d",
        "local DESIGN_H = %d",
        "Settings:setScriptDimension(true, DESIGN_W)",
        "Settings:setCompareDimension(true, DESIGN_W)",
        "setImagePath(imgPath)",
        "",
        "local screen = getAppUsableScreenSize()",
        "local SW, SH = screen:getX(), screen:getY()",
        "",
        "local Upper_Half        = Region(0, 0, SW, SH/2)",
        "local Upper_Left        = Region(0, 0, SW/2, SH/2)",
        "local Upper_Right       = Region(SW/2, 0, SW/2, SH/2)",
        "local Lower_Half        = Region(0, SH/2, SW, SH/2)",
        "local Lower_Left        = Region(0, SH/2, SW/2, SH/2)",
        "local Lower_Right       = Region(SW/2, SH/2, SW/2, SH/2)",
        "local Lower_Most_Half   = Region(0, SH - SH/14, SW, SH/14)",
        "local Agnes_Region      = Region(0, math.floor(SH * 0.08),",
        "                                 math.floor(SW * 0.30),",
        "                                 math.floor(SH * 0.42))",
        "",
        "local function log(msg)",
        "    local line = os.date(\"%%H:%%M:%%S \" ) .. msg",
        "    if LOG_TOAST then toast(msg) end",
        "    if LOG_FILE and LOG_FILE ~= \"\" then",
        "        pcall(function()",
        "            local f2 = io.open(LOG_FILE, \"a+\")",
        "            if f2 then f2:write(line .. \"\\n\") f2:close() end",
        "        end)",
        "    end",
        "end",
        "",
        "local function debug(msg)",
        "    if CFG_DEBUG then",
        "        log(\"[DEBUG] \" .. msg)",
        "    end",
        "end",
        "",
        "----------------------------------------------------------------",
        "-- Helper functions (SearchImageNew / ClickImg / WaitExists)",
        "----------------------------------------------------------------",
        "function get_file_name(path)",
        "    return string.match(path, \"([^/]+)$\") or path",
        "end",
        "",
        "function Press(loc, times)",
        "    times = times or 1",
        "    for i = 1, times do",
        "        click(loc)",
        "        wait(0.1)",
        "    end",
        "end",
        "",
        "function SearchImageNew(target, boxRegion, maxScore, Color, Mask, Time)",
        "    if (target.target) then",
        "        boxRegion, maxScore, Color, Mask, Time, target =",
        "          target.region, target.score, target.color, target.mask, target.ttime, target.target",
        "    end",
        "    Time, Color, Mask, maxScore = Time or 0, Color or false, Mask or false, maxScore or %s",
        "    local TImage = target",
        "    if type(target) ~= \"table\" then TImage = {target} end",
        "    local result = {x = nil, y = nil, xy = nil, name = nil, score=maxScore}",
        "    local Search_Timer = Timer()",
        "    repeat",
        "        for i, t in ipairs(TImage) do",
        "            local PatternBuilder, Cur_Image",
        "            PatternBuilder = Pattern(t)",
        "            if (Color) then PatternBuilder = PatternBuilder:color() end",
        "            if (Mask)  then PatternBuilder = PatternBuilder:mask()  end",
        "            if (boxRegion) then",
        "                Cur_Image = boxRegion:exists(PatternBuilder, 0)",
        "            else",
        "                Cur_Image = exists(PatternBuilder, 0)",
        "            end",
        "            if (Cur_Image) then",
        "                local Cur_Score = Cur_Image:getScore()",
        "                if (Cur_Score >= maxScore) then",
        "                    local center = Cur_Image:getCenter()",
        "                    local X, Y   = center:getX(), center:getY()",
        "                    local W, H   = Cur_Image:getW(), Cur_Image:getH()",
        "                    local SX, SY = Cur_Image:getX(), Cur_Image:getY()",
        "                    local R      = Region(X - (W / 2), Y - (H / 2), W, H)",
        "                    maxScore = Cur_Score",
        "                    result = {",
        "                        x = X, y = Y, xy = center, name = get_file_name(TImage[i]),",
        "                        score=maxScore, w = W, h = H, r = R, sx = SX, sy = SY,",
        "                        loc = Location(X,Y)",
        "                    }",
        "                end",
        "            else",
        "                Cur_Image = nil",
        "            end",
        "        end",
        "    until(result.name) or (Search_Timer:check() > Time)",
        "    Search_Timer = nil",
        "    target, boxRegion, maxScore, Color, Mask, Time = nil, nil, nil, nil, nil, nil",
        "    return result",
        "end",
        "",
        "function ClickImg(image, region, score, color, mask, waitTime)",
        "    score    = score    or %s",
        "    waitTime = waitTime or 0",
        "    color    = color    or false",
        "    mask     = mask     or false",
        "",
        "    local timer = Timer()",
        "    repeat",
        "        local result = SearchImageNew(image, region, score, color, mask, 0)",
        "        if result and result.xy then",
        "            Press(result.xy, 1)",
        "            return true, result",
        "        end",
        "        if waitTime > 0 then",
        "            wait(0.2)",
        "        end",
        "    until (waitTime == 0) or (timer:check() >= waitTime)",
        "    return false, nil",
        "end",
        "",
        "function WaitExists(image, timeout, region, score, color, mask)",
        "    timeout = timeout or 0",
        "    score   = score   or %s",
        "    local timer = Timer()",
        "    repeat",
        "        local result = SearchImageNew(image, region, score, color, mask, 0)",
        "        if (result and result.name) then",
        "            return true, result",
        "        end",
        "        wait(0.2)",
        "    until (timer:check() >= timeout)",
        "    return false",
        "end",
        "",
        "----------------------------------------------------------------",
        "-- SCRIPT STEPS",
        "----------------------------------------------------------------",
        ""
    }, "\n")
    header = string.format(header, CFG_FOLDER_NAME, immersiveLiteral, CFG_ACCURACY, debugLiteral, CFG_FOLDER_NAME, DESIGN_W, DESIGN_H, CFG_ACCURACY, CFG_ACCURACY, CFG_ACCURACY)
    f:write(header)

    -- Generate code for each recorded step
    f:write("\nlog(\"Script started\")\n")
    f:write("debug(\"Total steps: \" .. " .. #SCRIPT_STEPS .. ")\n\n")

    for i, step in ipairs(SCRIPT_STEPS) do
        f:write("-- Step " .. i .. ": " .. step.desc .. "\n")
        f:write("debug(\"Executing step " .. i .. ": " .. step.desc:gsub('\"', '\\\"') .. "\")\n")

        if step.type == "click_img" then
            local regionVar = step.data.region or "nil"
            f:write("debug(\"Searching for image: " .. step.data.img .. " in region: " .. regionVar .. "\")\n")
            f:write("local success, result = ClickImg(\"" .. step.data.img .. "\", " .. regionVar .. ", CFG_ACCURACY, false, false, 10)\n")
            f:write("if success then\n")
            f:write("    log(\"Clicked: " .. step.data.img .. "\")\n")
            f:write("    debug(\"Click position: \" .. result.x .. \",\" .. result.y .. \" | Score: \" .. result.score)\n")
            f:write("else\n")
            f:write("    log(\"Failed to find: " .. step.data.img .. "\")\n")
            f:write("    debug(\"Image not found after 10s timeout\")\n")
            f:write("end\n\n")

        elseif step.type == "wait_img" then
            local regionVar = step.data.region or "nil"
            f:write("debug(\"Searching for image: " .. step.data.img .. " in region: " .. regionVar .. "\")\n")
            f:write("local found, result = WaitExists(\"" .. step.data.img .. "\", 10, " .. regionVar .. ", CFG_ACCURACY, false, false)\n")
            f:write("if found then\n")
            f:write("    log(\"Waited and found: " .. step.data.img .. "\")\n")
            f:write("    debug(\"Found at position: \" .. result.x .. \",\" .. result.y .. \" | Score: \" .. result.score)\n")
            f:write("else\n")
            f:write("    log(\"Timed out waiting for: " .. step.data.img .. "\")\n")
            f:write("end\n\n")

        elseif step.type == "click_region" then
            f:write(string.format("debug(\"Clicking region at %d,%d\")\n", math.floor(step.data.x), math.floor(step.data.y)))
            f:write(string.format("Press(Location(%d, %d), 1)\n\n", math.floor(step.data.x), math.floor(step.data.y)))

        elseif step.type == "swipe" then
            local dur = tonumber(step.data.dur) or 0.4
            local x1, y1 = math.floor(step.data.x1), math.floor(step.data.y1)
            local x2, y2 = math.floor(step.data.x2), math.floor(step.data.y2)
            f:write(string.format("debug(\"Swiping from %d,%d to %d,%d\")\n", x1, y1, x2, y2))
            f:write(string.format("swipe(Location(%d, %d), Location(%d, %d), %.2f)\n", x1, y1, x2, y2, dur))
            f:write("log(\"Swiped\")\n")
            f:write("wait(0.5)\n\n")

        elseif step.type == "wait" then
            local sec = tonumber(step.data.sec) or 1
            f:write(string.format("debug(\"Waiting %s seconds\")\n", sec))
            f:write(string.format("wait(%s)\n\n", sec))

        elseif step.type == "if_img_else" then
            local ra = step.data.regionA or "nil"
            local rb = step.data.regionB or "nil"
            f:write("debug(\"Conditional: checking for " .. step.data.imgA .. "\")\n")
            f:write("local foundA = WaitExists(\"" .. step.data.imgA .. "\", 5, " .. ra .. ", CFG_ACCURACY, false, false)\n")
            f:write("if foundA then\n")
            f:write("    log(\"Found A: " .. step.data.imgA .. ", skipping B\")\n")
            f:write("    debug(\"Condition A met, not checking B\")\n")
            f:write("else\n")
            f:write("    log(\"A not found, trying B: " .. step.data.imgB .. "\")\n")
            f:write("    debug(\"Checking alternative: " .. step.data.imgB .. "\")\n")
            f:write("    ClickImg(\"" .. step.data.imgB .. "\", " .. rb .. ", CFG_ACCURACY, false, false, 10)\n")
            f:write("end\n\n")
        end
    end

    f:write("\nlog(\"Script completed successfully!\")\n")
    f:write("debug(\"All " .. #SCRIPT_STEPS .. " steps executed\")\n")

    f:close()
    log("Generated script: " .. outputPath)
end
----------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------
while TRUE do
    dialogs.action_menu()

    if REC_OP == 100 then
        break
    elseif REC_OP == 99 then
        generateScript()
        simpleDialog("Success",
            "Created:\n" ..
            CFG_FOLDER_NAME .. ".lua\nand folder:\n" ..
            CFG_FOLDER_NAME .. "/")
        break
    else
        -- normal actions
        if REC_OP == 1 then
            local reg = getRegionUser()
            if reg then
                local default = "step_" .. IMG_COUNTER .. "_click"
                dialogs.askFilename(default)
                local imgName  = USER_IMG_NAME
                local fileName = saveImageCrop(reg, imgName)

                local cx = reg:getX() + reg:getW()/2
                local cy = reg:getY() + reg:getH()/2
                local regionName = detectRegionFromPoint(cx, cy)

                addStep("click_img",
                        { img = fileName, region = regionName },
                        "Click Image (" .. regionName .. ")")
                IMG_COUNTER = IMG_COUNTER + 1
            end

        elseif REC_OP == 2 then
            local reg = getRegionUser()
            if reg then
                local default = "step_" .. IMG_COUNTER .. "_wait"
                dialogs.askFilename(default)
                local imgName  = USER_IMG_NAME
                local fileName = saveImageCrop(reg, imgName)

                local cx = reg:getX() + reg:getW()/2
                local cy = reg:getY() + reg:getH()/2
                local regionName = detectRegionFromPoint(cx, cy)

                addStep("wait_img",
                        { img = fileName, region = regionName },
                        "Wait Image (" .. regionName .. ")")
                IMG_COUNTER = IMG_COUNTER + 1
            end

        elseif REC_OP == 3 then
            -- Click Region: user draws a box; we click its center
            local reg = getRegionUser()
            if reg then
                local cx = reg:getX() + reg:getW()/2
                local cy = reg:getY() + reg:getH()/2
                local regionName = detectRegionFromPoint(cx, cy)
                addStep("click_region",
                        { x = cx, y = cy, region = regionName },
                        "Click Region (" .. regionName .. ")")
            end

        elseif REC_OP == 4 then
            local p1, p2 = getSwipeUser()
            if p1 and p2 then
                addStep("swipe",
                        { x1 = p1.x, y1 = p1.y, x2 = p2.x, y2 = p2.y, dur = CFG_SWIPE_DURATION },
                        "Swipe")
            end

        elseif REC_OP == 5 then
            dialogs.get_wait_time()
            addStep("wait", { sec = WAIT_TIME },
                    "Wait " .. WAIT_TIME .. "s")

        elseif REC_OP == 6 then
            -- IF Image A THEN else Image B
            -- first snap: A
            local regA = getRegionUser()
            if regA then
                local defaultA = "if_" .. IMG_COUNTER .. "_A"
                dialogs.askFilename(defaultA)
                local imgAName  = USER_IMG_NAME
                local fileAName = saveImageCrop(regA, imgAName)

                local cxA = regA:getX() + regA:getW()/2
                local cyA = regA:getY() + regA:getH()/2
                local regionA = detectRegionFromPoint(cxA, cyA)

                -- second snap: B
                local regB = getRegionUser()
                if regB then
                    local defaultB = "if_" .. IMG_COUNTER .. "_B"
                    dialogs.askFilename(defaultB)
                    local imgBName  = USER_IMG_NAME
                    local fileBName = saveImageCrop(regB, imgBName)

                    local cxB = regB:getX() + regB:getW()/2
                    local cyB = regB:getY() + regB:getH()/2
                    local regionB = detectRegionFromPoint(cxB, cyB)

                    addStep(
                        "if_img_else",
                        {
                            imgA    = fileAName,
                            regionA = regionA,
                            imgB    = fileBName,
                            regionB = regionB
                        },
                        "If " .. regionA .. " then else " .. regionB
                    )
                    IMG_COUNTER = IMG_COUNTER + 1
                else
                    -- user canceled second image; clean up first snapshot
                    os.remove(PATH_TO_IMAGES_FOLDER .. fileAName)
                end
            end
        end
    end

    wait(0.3)
end


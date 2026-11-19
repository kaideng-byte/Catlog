--[[
Cat continence log - KOReader plugin (v2: multiple litterboxes + entry editing)

Log:      <koreader data dir>/catlog.csv     (Kindle: /mnt/us/koreader/catlog.csv)
Settings: <koreader settings dir>/catlog.lua (litterbox list + current box)

CSV columns: datetime,event,place,detail,note
  place = a litterbox label, or "accident"
]]

local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local LuaSettings = require("luasettings")
local Menu = require("ui/widget/menu")
local TextViewer = require("ui/widget/textviewer")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local Screen = Device.screen

local HEADER = "datetime,event,place,detail,note"

local CatLog = WidgetContainer:extend{
    name = "catlog",
    is_doc_only = false,
}

---------------------------------------------------------------- helpers

local function logPath()
    return DataStorage:getDataDir() .. "/catlog.csv"
end

local function trim(s)
    return (tostring(s or ""):match("^%s*(.-)%s*$"))
end

local function clean(s)
    s = tostring(s or "")
    s = s:gsub("[,\r\n]", " ")
    return trim(s)
end

local function split(line)
    local out = {}
    for field in (line .. ","):gmatch("([^,]*),") do
        table.insert(out, field)
    end
    return out
end

local function pad(f)
    while #f < 5 do f[#f + 1] = "" end
    return f
end

local function readLines()
    local lines = {}
    local f = io.open(logPath(), "r")
    if f then
        for line in f:lines() do
            if line ~= "" then table.insert(lines, line) end
        end
        f:close()
    end
    return lines
end

local function writeLines(lines)
    local f = io.open(logPath(), "w")
    if not f then return false end
    f:write(table.concat(lines, "\n"), "\n")
    f:close()
    return true
end

local function ensureHeader()
    if #readLines() == 0 then writeLines({ HEADER }) end
end

local function validDateTime(s)
    local y, mo, d, h, mi = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d)$")
    if not y then return false end
    mo, d, h, mi = tonumber(mo), tonumber(d), tonumber(h), tonumber(mi)
    return mo >= 1 and mo <= 12 and d >= 1 and d <= 31 and h <= 23 and mi <= 59
end

local function detailOptions(event)
    if event == "poop" then
        return { "normal", "soft", "hard", "diarrhea", "blood" }
    end
    return { "small", "normal", "large", "blood" }
end

local function describe(line)
    local f = pad(split(line))
    local where = f[3] == "accident" and "ACCIDENT" or f[3]
    local s = string.format("%s  %s - %s", f[1], f[2], where)
    if f[4] ~= "" then s = s .. " - " .. f[4] end
    if f[5] ~= "" then s = s .. " [" .. f[5] .. "]" end
    return s
end

local function toast(text)
    UIManager:show(InfoMessage:new{ text = text, timeout = 3 })
end

---------------------------------------------------------------- setup

function CatLog:onDispatcherRegisterActions()
    Dispatcher:registerAction("catlog_open", {
        category = "none",
        event = "CatLogOpen",
        title = _("Cat continence log"),
        general = true,
    })
end

function CatLog:init()
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/catlog.lua")
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function CatLog:addToMainMenu(menu_items)
    menu_items.catlog = {
        text = _("Cat continence log"),
        sorting_hint = "tools",
        callback = function() self:showMain() end,
    }
end

function CatLog:onCatLogOpen()
    self:showMain()
    return true
end

function CatLog:closeDialog()
    if self.dialog then
        UIManager:close(self.dialog)
        self.dialog = nil
    end
end

function CatLog:askText(title, initial, on_done)
    local dlg
    dlg = InputDialog:new{
        title = title,
        input = initial or "",
        buttons = {
            {
                { text = _("Cancel"), callback = function()
                    UIManager:close(dlg)
                    on_done(nil)
                end },
                { text = _("Save"), is_enter_default = true, callback = function()
                    local text = dlg:getInputText()
                    UIManager:close(dlg)
                    on_done(text)
                end },
            },
        },
    }
    UIManager:show(dlg)
    dlg:onShowKeyboard()
end

---------------------------------------------------------------- litterboxes

function CatLog:getBoxes()
    local boxes = self.settings:readSetting("boxes")
    if type(boxes) ~= "table" or #boxes == 0 then
        boxes = { "Box 1" }
        self.settings:saveSetting("boxes", boxes)
        self.settings:flush()
    end
    return boxes
end

function CatLog:setBoxes(boxes)
    self.settings:saveSetting("boxes", boxes)
    self.settings:flush()
end

function CatLog:getCurrentBox()
    local boxes = self:getBoxes()
    local cur = self.settings:readSetting("current_box")
    for i, b in ipairs(boxes) do
        if b == cur then return cur end
    end
    return boxes[1]
end

function CatLog:setCurrentBox(label)
    self.settings:saveSetting("current_box", label)
    self.settings:flush()
end

-- Returns cleaned label, or nil plus an error message
function CatLog:validateLabel(raw, ignore)
    local label = clean(raw)
    if label == "" then return nil, _("The label can't be empty.") end
    if label:lower() == "accident" then
        return nil, _("\"accident\" is reserved. Pick another label.")
    end
    for i, b in ipairs(self:getBoxes()) do
        if b:lower() == label:lower() and b ~= ignore then
            return nil, _("A litterbox with that label already exists.")
        end
    end
    return label
end

function CatLog:showBoxPicker()
    self:closeDialog()
    local current = self:getCurrentBox()
    local rows = {}
    for i, b in ipairs(self:getBoxes()) do
        table.insert(rows, {
            { text = (b == current and "* " or "") .. b, callback = function()
                self:setCurrentBox(b)
                self:showMain()
            end },
        })
    end
    table.insert(rows, { { text = _("Back"), callback = function() self:showMain() end } })
    self.dialog = ButtonDialog:new{ title = _("Which litterbox?"), buttons = rows }
    UIManager:show(self.dialog)
end

function CatLog:showManageBoxes()
    self:closeDialog()
    local current = self:getCurrentBox()
    local rows = {}
    for i, b in ipairs(self:getBoxes()) do
        table.insert(rows, {
            { text = b .. (b == current and "  (current)" or ""), callback = function()
                self:showBoxOptions(b)
            end },
        })
    end
    table.insert(rows, { { text = _("+ Add litterbox"), callback = function() self:addBox() end } })
    table.insert(rows, { { text = _("Back"), callback = function() self:showMain() end } })
    self.dialog = ButtonDialog:new{ title = _("Litterboxes (tap one to edit)"), buttons = rows }
    UIManager:show(self.dialog)
end

function CatLog:showBoxOptions(label)
    self:closeDialog()
    self.dialog = ButtonDialog:new{
        title = label,
        buttons = {
            {
                { text = _("Rename"), callback = function() self:renameBox(label) end },
                { text = _("Delete"), callback = function() self:deleteBox(label) end },
            },
            {
                { text = _("Make current"), callback = function()
                    self:setCurrentBox(label)
                    self:showManageBoxes()
                end },
                { text = _("Back"), callback = function() self:showManageBoxes() end },
            },
        },
    }
    UIManager:show(self.dialog)
end

function CatLog:addBox()
    self:closeDialog()
    self:askText(_("New litterbox label"), "", function(text)
        if text then
            local label, err = self:validateLabel(text)
            if label then
                local boxes = self:getBoxes()
                table.insert(boxes, label)
                self:setBoxes(boxes)
            else
                toast(err)
            end
        end
        self:showManageBoxes()
    end)
end

function CatLog:renameBox(old)
    self:closeDialog()
    self:askText(_("Rename litterbox"), old, function(text)
        if text then
            local label, err = self:validateLabel(text, old)
            if label and label ~= old then
                local boxes = self:getBoxes()
                for i, b in ipairs(boxes) do
                    if b == old then boxes[i] = label end
                end
                self:setBoxes(boxes)
                if self:getCurrentBox() == old then self:setCurrentBox(label) end
                -- relabel past entries too
                local lines = readLines()
                for i = 2, #lines do
                    local f = pad(split(lines[i]))
                    if f[3] == old then
                        f[3] = label
                        lines[i] = table.concat(f, ",", 1, 5)
                    end
                end
                writeLines(lines)
            elseif err then
                toast(err)
            end
        end
        self:showManageBoxes()
    end)
end

function CatLog:deleteBox(label)
    self:closeDialog()
    local boxes = self:getBoxes()
    if #boxes <= 1 then
        toast(_("You need at least one litterbox."))
        self:showManageBoxes()
        return
    end
    UIManager:show(ConfirmBox:new{
        text = string.format(_("Delete litterbox \"%s\"?\n\nPast entries keep this label."), label),
        ok_text = _("Delete"),
        ok_callback = function()
            for i, b in ipairs(boxes) do
                if b == label then
                    table.remove(boxes, i)
                    break
                end
            end
            self:setBoxes(boxes)
            self:showManageBoxes()
        end,
        cancel_callback = function() self:showManageBoxes() end,
    })
end

---------------------------------------------------------------- logging

function CatLog:addEntry(event, place)
    ensureHeader()
    local lines = readLines()
    table.insert(lines, string.format("%s,%s,%s,,", os.date("%Y-%m-%d %H:%M"), event, clean(place)))
    return writeLines(lines)
end

-- changes: { [field_index] = value }
function CatLog:setFields(idx, changes)
    local lines = readLines()
    if idx < 2 or not lines[idx] then return false end
    local f = pad(split(lines[idx]))
    for k, v in pairs(changes) do f[k] = clean(v) end
    lines[idx] = table.concat(f, ",", 1, 5)
    return writeLines(lines)
end

function CatLog:showMain()
    self:closeDialog()
    local box = self:getCurrentBox()
    self.dialog = ButtonDialog:new{
        title = _("Cat continence log"),
        buttons = {
            {
                { text = _("PEE: ") .. box, callback = function() self:log("pee", box) end },
                { text = _("POOP: ") .. box, callback = function() self:log("poop", box) end },
            },
            {
                { text = _("ACCIDENT: pee"), callback = function() self:log("pee", "accident") end },
                { text = _("ACCIDENT: poop"), callback = function() self:log("poop", "accident") end },
            },
            {
                { text = _("Switch litterbox  (now: ") .. box .. ")", callback = function()
                    self:showBoxPicker()
                end },
            },
            {
                { text = _("History"), callback = function() self:showHistory() end },
                { text = _("Weekly summary"), callback = function() self:showSummary() end },
            },
            {
                { text = _("Edit entries"), callback = function() self:showEditList() end },
                { text = _("Undo last"), callback = function() self:undoLast() end },
            },
            {
                { text = _("Manage litterboxes"), callback = function() self:showManageBoxes() end },
                { text = _("Close"), callback = function() self:closeDialog() end },
            },
        },
    }
    UIManager:show(self.dialog)
end

function CatLog:log(event, place)
    self:closeDialog()
    if self:addEntry(event, place) then
        self:showDetail(event, place)
    else
        toast(_("Could not write the log file."))
    end
end

-- Buttons that set the detail field of entry idx, then call after()
function CatLog:detailRows(event, idx, after)
    local row1, row2 = {}, {}
    for i, opt in ipairs(detailOptions(event)) do
        local btn = { text = opt, callback = function()
            self:setFields(idx, { [4] = opt })
            after()
        end }
        table.insert(i <= 3 and row1 or row2, btn)
    end
    local rows = { row1 }
    if #row2 > 0 then table.insert(rows, row2) end
    return rows
end

-- Optional follow-up. The entry is already saved.
function CatLog:showDetail(event, place)
    self:closeDialog()
    local idx = #readLines()
    local rows = self:detailRows(event, idx, function() self:showMain() end)
    table.insert(rows, {
        { text = _("Add note"), callback = function()
            self:editNote(idx, function() self:showMain() end)
        end },
        { text = _("Skip"), callback = function() self:showMain() end },
    })
    local where = place == "accident" and "accident" or place
    self.dialog = ButtonDialog:new{
        title = string.format(_("Saved: %s (%s). Add detail?"), event, where),
        buttons = rows,
    }
    UIManager:show(self.dialog)
end

function CatLog:editNote(idx, after)
    self:closeDialog()
    local lines = readLines()
    local current = lines[idx] and pad(split(lines[idx]))[5] or ""
    self:askText(_("Note"), current, function(text)
        if text then self:setFields(idx, { [5] = text }) end
        after()
    end)
end

function CatLog:undoLast()
    self:closeDialog()
    local lines = readLines()
    if #lines < 2 then
        toast(_("Nothing to undo."))
        self:showMain()
        return
    end
    UIManager:show(ConfirmBox:new{
        text = _("Delete the last entry?\n\n") .. describe(lines[#lines]),
        ok_text = _("Delete"),
        ok_callback = function()
            table.remove(lines)
            writeLines(lines)
            self:showMain()
        end,
        cancel_callback = function() self:showMain() end,
    })
end

---------------------------------------------------------------- editing

function CatLog:showEditList()
    self:closeDialog()
    local lines = readLines()
    local items = {}
    for i = #lines, 2, -1 do
        local idx = i
        table.insert(items, {
            text = describe(lines[i]),
            callback = function()
                if self.menu then UIManager:close(self.menu) end
                self:editEntry(idx)
            end,
        })
        if #items >= 200 then break end
    end
    if #items == 0 then
        toast(_("No entries yet."))
        self:showMain()
        return
    end
    self.menu = Menu:new{
        title = _("Tap an entry to edit (newest first)"),
        item_table = items,
        is_borderless = true,
        is_popout = false,
        covers_fullscreen = true,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
    }
    UIManager:show(self.menu)
end

function CatLog:editEntry(idx)
    self:closeDialog()
    local lines = readLines()
    if idx < 2 or not lines[idx] then
        self:showEditList()
        return
    end
    local f = pad(split(lines[idx]))
    local other = f[2] == "pee" and "poop" or "pee"
    self.dialog = ButtonDialog:new{
        title = describe(lines[idx]),
        buttons = {
            {
                { text = _("Date / time"), callback = function() self:editTime(idx) end },
                { text = _("Change to ") .. other, callback = function()
                    -- detail options differ per event, so clear the detail
                    self:setFields(idx, { [2] = other, [4] = "" })
                    self:editEntry(idx)
                end },
            },
            {
                { text = _("Place"), callback = function() self:editPlace(idx) end },
                { text = _("Detail"), callback = function() self:editDetail(idx) end },
            },
            {
                { text = _("Note"), callback = function()
                    self:editNote(idx, function() self:editEntry(idx) end)
                end },
                { text = _("Delete entry"), callback = function() self:confirmDelete(idx) end },
            },
            {
                { text = _("Back to list"), callback = function() self:showEditList() end },
            },
        },
    }
    UIManager:show(self.dialog)
end

function CatLog:editTime(idx)
    self:closeDialog()
    local lines = readLines()
    local f = pad(split(lines[idx]))
    self:askText(_("Date and time (YYYY-MM-DD HH:MM)"), f[1], function(text)
        if text then
            text = trim(text)
            if validDateTime(text) then
                idx = self:setDateTime(idx, text)
            else
                toast(_("Use the format YYYY-MM-DD HH:MM, e.g. 2026-11-19 14:30"))
            end
        end
        self:editEntry(idx)
    end)
end

-- Changes the timestamp, re-sorts entries chronologically, returns the new index
function CatLog:setDateTime(idx, value)
    local lines = readLines()
    local f = pad(split(lines[idx]))
    f[1] = value
    lines[idx] = table.concat(f, ",", 1, 5)
    local entries = {}
    for i = 2, #lines do
        table.insert(entries, { line = lines[i], key = split(lines[i])[1], orig = i })
    end
    table.sort(entries, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        return a.orig < b.orig
    end)
    local out = { lines[1] }
    local new_idx = idx
    for i, e in ipairs(entries) do
        table.insert(out, e.line)
        if e.orig == idx then new_idx = i + 1 end
    end
    writeLines(out)
    return new_idx
end

function CatLog:editPlace(idx)
    self:closeDialog()
    local rows = {}
    for i, b in ipairs(self:getBoxes()) do
        table.insert(rows, { { text = b, callback = function()
            self:setFields(idx, { [3] = b })
            self:editEntry(idx)
        end } })
    end
    table.insert(rows, { { text = _("ACCIDENT"), callback = function()
        self:setFields(idx, { [3] = "accident" })
        self:editEntry(idx)
    end } })
    table.insert(rows, { { text = _("Back"), callback = function() self:editEntry(idx) end } })
    self.dialog = ButtonDialog:new{ title = _("Where did it happen?"), buttons = rows }
    UIManager:show(self.dialog)
end

function CatLog:editDetail(idx)
    self:closeDialog()
    local lines = readLines()
    local f = pad(split(lines[idx]))
    local rows = self:detailRows(f[2], idx, function() self:editEntry(idx) end)
    table.insert(rows, {
        { text = _("Clear detail"), callback = function()
            self:setFields(idx, { [4] = "" })
            self:editEntry(idx)
        end },
        { text = _("Back"), callback = function() self:editEntry(idx) end },
    })
    self.dialog = ButtonDialog:new{ title = _("Detail"), buttons = rows }
    UIManager:show(self.dialog)
end

function CatLog:confirmDelete(idx)
    self:closeDialog()
    local lines = readLines()
    UIManager:show(ConfirmBox:new{
        text = _("Delete this entry?\n\n") .. describe(lines[idx]),
        ok_text = _("Delete"),
        ok_callback = function()
            local current = readLines()
            table.remove(current, idx)
            writeLines(current)
            self:showEditList()
        end,
        cancel_callback = function() self:editEntry(idx) end,
    })
end

---------------------------------------------------------------- reports

function CatLog:showHistory()
    self:closeDialog()
    local lines = readLines()
    local out = {}
    for i = #lines, 2, -1 do
        table.insert(out, describe(lines[i]))
        if #out >= 40 then break end
    end
    if #out == 0 then out = { _("No entries yet.") } end
    UIManager:show(TextViewer:new{
        title = _("Last entries (newest first)"),
        text = table.concat(out, "\n"),
        close_callback = function() self:showMain() end,
    })
end

function CatLog:showSummary()
    self:closeDialog()
    local lines = readLines()
    local days, order = {}, {}
    for i = 2, #lines do
        local f = pad(split(lines[i]))
        local day = f[1]:sub(1, 10)
        if not days[day] then
            days[day] = { pee = 0, poop = 0, acc = 0 }
            table.insert(order, day)
        end
        local d = days[day]
        if f[2] == "pee" then d.pee = d.pee + 1 end
        if f[2] == "poop" then d.poop = d.poop + 1 end
        if f[3] == "accident" then d.acc = d.acc + 1 end
    end
    table.sort(order, function(a, b) return a > b end)

    local out
    if #order == 0 then
        out = { _("No entries yet.") }
    else
        out = { "Date        Pee  Poop  Accidents" }
        local included, total_acc = {}, 0
        for i = 1, math.min(7, #order) do
            local day = order[i]
            local d = days[day]
            included[day] = true
            total_acc = total_acc + d.acc
            table.insert(out, string.format("%s   %2d   %2d    %2d", day, d.pee, d.poop, d.acc))
        end
        table.insert(out, "")
        table.insert(out, string.format("Accidents in these %d day(s): %d", math.min(7, #order), total_acc))

        -- totals per place over the same days
        local per_place, place_order = {}, {}
        for i = 2, #lines do
            local f = pad(split(lines[i]))
            if included[f[1]:sub(1, 10)] then
                local p = f[3] == "accident" and "ACCIDENT" or f[3]
                if not per_place[p] then
                    per_place[p] = 0
                    table.insert(place_order, p)
                end
                per_place[p] = per_place[p] + 1
            end
        end
        table.sort(place_order)
        table.insert(out, "")
        table.insert(out, "By place:")
        for i, p in ipairs(place_order) do
            table.insert(out, string.format("  %s: %d", p, per_place[p]))
        end
    end
    UIManager:show(TextViewer:new{
        title = _("Summary (last 7 logged days)"),
        text = table.concat(out, "\n"),
        monospace_font = true,
        close_callback = function() self:showMain() end,
    })
end

return CatLog

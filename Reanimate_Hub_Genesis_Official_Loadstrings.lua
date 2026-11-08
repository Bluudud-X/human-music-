--[[
    Reanimate Hub  |  Phase 1: UI
    Framework: Rayfield Gen2 (https://docs.sirius.menu/rayfield-gen2)
]]

----------------------------------------------------------------
-- Config
----------------------------------------------------------------
local Config = {
    Title = "Reanimate Hub",
    TwentyFourBase = "https://raw.githubusercontent.com/BloxinStud10/24-Hours/refs/heads/main/Loadstrings/",
    GenesisBase = "https://raw.githubusercontent.com/GenesisFE/Genesis/main/Loadstrings/",
    FDlessUrl = "https://raw.githubusercontent.com/Bluudud-X/human-music-/refs/heads/main/FDless_merged_min.lua",
    AutoRigPlaceId = 95964727828755, -- "autorig" experience, for making custom rigs
    StellarisPlaceId = 112144950473007, -- "24 Stellaris" experience, the 24 Hours accessories game
    FoundationPlaceId = 14133411956, -- "Foundation" experience, the Genesis rig game
    BaseplatePlaceId = 123974602339071, -- "[UP] Just a baseplate."
    NoobyUrl = "https://raw.githubusercontent.com/Elliot12-wq/Uh-reanimation-modded-by-nooby/main/NOOBY'S%20UH%20MODDED%20REANIMATION.lua.txt",
}

----------------------------------------------------------------
-- Theme: black + cyan outlines + white text
----------------------------------------------------------------
local CYAN = Color3.fromRGB(0, 230, 255)
local MUTED_CYAN = Color3.fromRGB(0, 140, 160)
local BLACK = Color3.fromRGB(0, 0, 0)
local DARK = Color3.fromRGB(10, 10, 12)
local WHITE = Color3.fromRGB(255, 255, 255)

local Theme = {
    WindowColor = BLACK,
    SurfaceStroke = CYAN,
    LiveAnimation = false,

    TitlingColor = WHITE,
    ContentColor = WHITE,
    ElementTextHoverColor = WHITE,
    ActionColor = CYAN,

    TabColor = WHITE,
    TabBackground = DARK,
    TabStroke = CYAN,

    ElementGradient = DARK,
    ElementStroke = CYAN,
    ElementStrokeHover = WHITE,
    ElementStrokeHoverTransparency = 0,

    AccentColor = CYAN,
    AccentStroke = CYAN,
    SliderBackground = DARK,
    SliderProgress = CYAN,
    SliderStroke = MUTED_CYAN,
    SliderHandle = WHITE,
    ToggleTrack = DARK,
    ToggleKnobOff = MUTED_CYAN,
    DropdownHighlight = MUTED_CYAN,

    FieldBackground = DARK,
    PlaceholderColor = MUTED_CYAN,
    FieldGlow = BLACK,
}

----------------------------------------------------------------
-- Custom FDless manager (runs before Rayfield loads)
-- The merged FDless file is a hook layer: once loaded, it swaps the FDless source that
-- scripts loaded afterwards (Genesis, 24 Hours) try to use for the custom one. It exposes
-- its own shutdown as TerminateFDless(), which stops the reanimate it captured and
-- restores every hook it installed. After that it must be loaded again to be reinstalled.
----------------------------------------------------------------
local FDless = { StartError = nil }

local function genv()
    return (getgenv and getgenv()) or _G
end

function FDless.IsRunning()
    return type(genv().TerminateFDless) == "function" or type(_G.TerminateFDless) == "function"
end

-- Returns true on success, or false plus an error message. No UI exists yet at this point.
function FDless.Start()
    if FDless.IsRunning() then
        return true
    end
    local fetched, source = pcall(game.HttpGet, game, Config.FDlessUrl)
    if not fetched or type(source) ~= "string" or source == "" then
        return false, "Failed to download FDless: " .. tostring(source)
    end
    local fn, compileErr = loadstring(source)
    if not fn then
        return false, "FDless failed to compile: " .. tostring(compileErr)
    end
    local ran, runErr = pcall(fn)
    if not ran or not FDless.IsRunning() then
        return false, "FDless did not start: " .. tostring(runErr)
    end
    return true
end

-- Safe to call any number of times; only ever calls FDless's own TerminateFDless.
function FDless.Stop()
    local terminate = genv().TerminateFDless or _G.TerminateFDless
    if type(terminate) ~= "function" then
        return true -- nothing running
    end
    local ok, err = pcall(terminate)
    if not ok then
        warn("[Reanimate Hub] TerminateFDless error: " .. tostring(err))
        return false
    end
    return true
end

-- Global entry point from the spec, for other scripts to call.
_G.StopFDless = FDless.Stop

do
    local started, err = FDless.Start()
    if not started then
        FDless.StartError = err
        warn("[Reanimate Hub] " .. tostring(err))
    end
end

----------------------------------------------------------------
-- Rayfield + window
----------------------------------------------------------------
local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
end)
if not ok or not Rayfield then
    warn("[Reanimate Hub] Failed to load Rayfield Gen2: " .. tostring(Rayfield))
    return
end

local window = Rayfield:CreateWindow({
    name = Config.Title,
    sidebarLayout = false, -- horizontal top tabs
    theme = Theme,
})

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local Hub = { Window = window, Tabs = {} }

function Hub.Notify(title, content)
    window:Notify({ title = title, content = content, duration = 4 })
end

-- Rayfield tabs have no subtitle property, so the subtitle is a body-only Text card.
local function makeTab(name, subtitle)
    local tab = window:CreateTab({ name = name })
    tab:CreateText({ text = subtitle })
    Hub.Tabs[name] = tab
    return tab
end

if FDless.StartError then
    Hub.Notify("Custom FDless", "Failed to start. See console.")
end

local function notWired(feature)
    return function()
        Hub.Notify(feature, "Not implemented yet.")
    end
end

----------------------------------------------------------------
-- Reanimation loader manager (Nooby only for now)
----------------------------------------------------------------
local Loader = {}

-- Only the hub's custom FDless is stopped. Nooby's own FDless is never touched here.
function Loader.StopHubFDless()
    return FDless.Stop()
end

function Loader.Teleport(label, placeId)
    local ok, err = pcall(function()
        game:GetService("TeleportService"):Teleport(placeId, game:GetService("Players").LocalPlayer)
    end)
    if not ok then
        Hub.Notify(label, "Teleport failed.")
        warn("[Reanimate Hub] " .. label .. " teleport failed: " .. tostring(err))
    end
end

-- Runs a remote loadstring file unchanged (original third-party script is not modified).
function Loader.RunRemote(label, url, transform)
    local fetched, source = pcall(game.HttpGet, game, url)
    if not fetched or type(source) ~= "string" or source == "" then
        Hub.Notify(label, "Failed to download the script.")
        warn("[Reanimate Hub] " .. label .. " download failed: " .. tostring(source))
        return false
    end

    if transform then
        local transformed, result, transformErr = pcall(transform, source)
        if not transformed or type(result) ~= "string" then
            Hub.Notify(label, "Could not prepare the official Genesis loadstring.")
            warn("[Reanimate Hub] " .. label .. " transform error: " .. tostring(result or transformErr))
            return false
        end
        source = result
    end

    local fn, compileErr = loadstring(source)
    if not fn then
        Hub.Notify(label, "Script failed to compile.")
        warn("[Reanimate Hub] " .. label .. " compile error: " .. tostring(compileErr))
        return false
    end
    task.spawn(function()
        local ran, runErr = pcall(fn)
        if not ran then
            Hub.Notify(label, "Script errored while running.")
            warn("[Reanimate Hub] " .. label .. " runtime error: " .. tostring(runErr))
        end
    end)
    return true
end

function Loader.LaunchNooby()
    if not Loader.StopHubFDless() then
        Hub.Notify("Nooby Reanimate", "Could not stop the hub's FDless. Aborted.")
        return
    end

    local fetched, source = pcall(game.HttpGet, game, Config.NoobyUrl)
    if not fetched or type(source) ~= "string" or source == "" then
        Hub.Notify("Nooby Reanimate", "Failed to download the script.")
        warn("[Reanimate Hub] Nooby download failed: " .. tostring(source))
        return
    end

    local fn, compileErr = loadstring(source)
    if not fn then
        Hub.Notify("Nooby Reanimate", "Script failed to compile.")
        warn("[Reanimate Hub] Nooby compile error: " .. tostring(compileErr))
        return
    end

    task.spawn(function()
        local ran, runErr = pcall(fn)
        if not ran then
            Hub.Notify("Nooby Reanimate", "Script errored while running.")
            warn("[Reanimate Hub] Nooby runtime error: " .. tostring(runErr))
        end
    end)
end

----------------------------------------------------------------
-- Tab modules
----------------------------------------------------------------
-- Genesis scripts. Each original loadstring file only sets option globals and then loads the
-- script from the repo's Obfuscations folder. The hub sets the same globals from its own
-- controls and loads that same script, so the third-party script itself is untouched.
-- fdless = false: the original file has no FDless options block, so none are set for it.
local GenesisShared = {
    { key = "fling", kind = "toggle", default = true, name = "Fling", desc = "Toggle fling." },
    { key = "placeholders", kind = "toggle", default = true, name = "Placeholders", desc = "Adds transparent parts showing your hats when you don't have real ones." },
    { key = "highlightflingtargets", kind = "toggle", default = true, name = "Highlight fling targets", desc = "Highlight fling targets." },
    { key = "allowshiftlock", kind = "toggle", default = true, name = "Shiftlock", desc = "Adds shiftlock to the patchma rig." },
    { key = "ctrltp", kind = "toggle", default = true, name = "Control click TP", desc = "Adds control click tp." },
    { key = "clickfling", kind = "toggle", default = false, name = "Click fling", desc = "Adds click flinging regardless of attacks." },
    { key = "flingtargetting", kind = "choice", default = 3, name = "Fling reproot method", desc = "How fling re-roots its target.", choices = {
        { 3, "3 - sethiddenproperty" },
        { 2, "2 - setscriptable" },
        { 1, "1 - no unc (can be tampered with and detected)" },
        { 0, "0 - off (prediction fling)" },
    } },
    { key = "flingdirection", kind = "choice", default = 0, name = "Fling direction", desc = "Direction you are flinging people in.", choices = {
        { 0, "0 - upwards" },
        { 1, "1 - downwards" },
        { 2, "2 - horizontal" },
    } },
    { key = "flingchangestate", kind = "choice", default = 3, name = "Fling enhancements", desc = "Extra fling behavior.", choices = {
        { 0, "0 - none" },
        { 1, "1 - changestate physics (fling with whole body)" },
        { 2, "2 - disable sitting" },
        { 3, "3 - all (changestate physics and disable sitting)" },
    } },
    { key = "respawntp", kind = "choice", default = 3, name = "Respawn TP mode", desc = "Where your body goes on respawn.", choices = {
        { 0, "0 - stay at spawn" },
        { 1, "1 - randomtp close" },
        { 2, "2 - behind fake character" },
        { 3, "3 - hide body" },
    } },
    { key = "disguiscripts", kind = "toggle", default = true, name = "Disable PlayerGui scripts", desc = "Disable scripts inside of PlayerGui." },
    { key = "discharscripts", kind = "toggle", default = true, name = "Disable character scripts", desc = "Disable character scripts." },
    { key = "breakjointsmethod", kind = "choice", default = 4, name = "BreakJoints mode", desc = "How the character is broken.", choices = {
        { 1, "1 - health+breakjoints (the most support)" },
        { 2, "2 - health or breakjoints" },
        { 3, "3 - breakjoints" },
        { 4, "4 - serverbreakjoints (replicatesignal)" },
    } },
    { key = "hidedeatheffect", kind = "toggle", default = true, name = "Hide death effect", desc = "Hides the red damage border when you die (respawn)." },
    { key = "simrad", kind = "toggle", default = true, name = "Simulation radius", desc = "Sets simulation radius." },
}

local GenesisScripts = {
    { name = "AK-47", fdless = true },
    { name = "Ban Hammer", fdless = true },
    { name = "Banisher", fdless = false },
    { name = "Dearsister", fdless = true },
    { name = "Gale Fighter", fdless = true },
    { name = "Goner", fdless = true },
    { name = "Good Cop Bad Cop", fdless = true },
    { name = "Karambit", fdless = false },
    { name = "Krystal Dance", fdless = true },
    { name = "Lightning Cannon", fdless = true, options = {
        { key = "lightmode", kind = "toggle", default = false, name = "Light mode", desc = "Overwrite black mode colors with white." },
        { key = "effects", kind = "toggle", default = true, name = "Effects", desc = "Toggle effects. Turn off if you experience performance issues." },
        { key = "timemultiplier", kind = "slider", default = 1, range = { 0.1, 10 }, increment = 0.1, name = "Animation speed", desc = "Animation speed multiplier (0.1 to 10)." },
        { key = "walkspeedmultiplier", kind = "number", default = 1, name = "Walkspeed multiplier", desc = "Default 1. Can be negative." },
    } },
    { name = "Linked Sword", fdless = false, options = {
        { key = "DisableFlingHealthBar", kind = "toggle", default = false, name = "Disable fling health bar", desc = "Sets DisableFlingHealthBar before launch." },
    } },
    { name = "Minigun", fdless = true },
    { name = "Motorcycle", fdless = true },
    { name = "Neko", fdless = false, options = {
        { key = "DisableFlingHealthBar", kind = "toggle", default = false, name = "Disable fling health bar", desc = "Sets DisableFlingHealthBar before launch." },
    } },
    { name = "Neptunian V", fdless = true },
    { name = "Pistol", fdless = false },
    { name = "Puppet Master", fdless = true, options = {
        { key = "DisableRedAnimatedText", kind = "toggle", default = false, name = "Disable red animated text", desc = "Disables the animated text that keeps popping up on screen. Does not disable Kills, Target or Script Title." },
    } },
    { name = "Sadist Genocider", fdless = true },
    { name = "Sin Dragon", fdless = true, options = {
        { key = "transparent", kind = "toggle", default = true, name = "Transparent parts", desc = "Toggle clientsided parts (dragon head, claws, etc)." },
        { key = "effects", kind = "toggle", default = true, name = "Effects", desc = "Toggle clientsided effects (punch effect, laser effect, etc). Turn off if you use an emulator and are lagging." },
    } },
    { name = "Sniper", fdless = true },
    { name = "Star Glitcher", fdless = false, options = {
        { key = "DisableFX", kind = "toggle", default = false, name = "Disable all effects", desc = "Could help with performance issues." },
    } },
    { name = "Studio Dummy", fdless = true },
}

-- Current option values, set by the controls below. Defaults match the original loadstring files.
local GenesisValues = { scripts = {} }

local function genesisEnv()
    return (getgenv and getgenv()) or _G
end

-- Adds one control for an option and keeps `store[opt.key]` in sync with it.
local function addGenesisOption(tab, opt, store, flagPrefix)
    if store[opt.key] == nil then
        store[opt.key] = opt.default
    end
    local currentValue = store[opt.key]
    local flag = flagPrefix .. "_" .. opt.key

    if opt.kind == "toggle" then
        tab:CreateToggle({
            name = opt.name, description = opt.desc, value = currentValue,
            flag = flag, forgetState = true,
            callback = function(v) store[opt.key] = v end,
        })
    elseif opt.kind == "choice" then
        local labels, byLabel, defaultLabel = {}, {}, nil
        for _, choice in ipairs(opt.choices) do
            table.insert(labels, choice[2])
            byLabel[choice[2]] = choice[1]
            if choice[1] == currentValue then defaultLabel = choice[2] end
        end
        tab:CreateDropdown({
            name = opt.name, description = opt.desc, options = labels, value = defaultLabel,
            flag = flag, forgetState = true,
            callback = function(selected)
                if type(selected) == "table" then selected = selected[1] end
                if byLabel[selected] ~= nil then store[opt.key] = byLabel[selected] end
            end,
        })
    elseif opt.kind == "slider" then
        tab:CreateSlider({
            name = opt.name, description = opt.desc, range = opt.range, increment = opt.increment,
            value = currentValue, flag = flag, forgetState = true,
            callback = function(v) store[opt.key] = v end,
        })
    elseif opt.kind == "number" then
        tab:CreateInput({
            name = opt.name, description = opt.desc, numeric = true, value = tostring(currentValue),
            flag = flag, forgetState = true,
            callback = function(text)
                local n = tonumber(text)
                if n then store[opt.key] = n end
            end,
        })
    end
end

-- Fetches the official Genesis Loadstrings wrapper. Its original Obfuscations loadstring
-- remains intact; only the wrapper's option assignment values are synchronized to this UI.
local function genesisLiteral(value)
    if type(value) == "boolean" then
        return tostring(value)
    elseif type(value) == "number" then
        return string.format("%.14g", value)
    elseif type(value) == "string" then
        return string.format("%q", value)
    end
    return "nil"
end

local function applyGenesisOptions(source, overrides)
    local output, found = {}, {}
    for line in (source .. "\\n"):gmatch("(.-)\\n") do
        line = line:gsub("\\r$", "")
        local indent, key, spacing, oldValue, suffix = line:match("^(%s*)([%a_][%w_]*)(%s*=%s*)([^%s]+)(.*)$")
        if key and overrides[key] ~= nil then
            line = indent .. key .. spacing .. genesisLiteral(overrides[key]) .. suffix
            found[key] = true
        end
        table.insert(output, line)
    end

    local missing = {}
    for key, _ in pairs(overrides) do
        if not found[key] then
            table.insert(missing, key)
        end
    end
    if #missing > 0 then
        return nil, "Official wrapper did not declare: " .. table.concat(missing, ", ")
    end
    return table.concat(output, "\\n")
end

local function launchGenesis(script)
    -- Every Genesis wrapper is launched only after this hub's custom FDless hook layer.
    if not FDless.IsRunning() then
        local started, startErr = FDless.Start()
        if not started then
            Hub.Notify("Genesis FE", "FDless failed to start. Script launch aborted.")
            warn("[Reanimate Hub] Genesis FDless start failed: " .. tostring(startErr))
            return
        end
    end

    local overrides = {}
    local scriptValues = GenesisValues.scripts[script.name] or {}
    if script.fdless then
        for _, opt in ipairs(GenesisShared) do
            overrides[opt.key] = scriptValues[opt.key]
        end
    end
    for _, opt in ipairs(script.options or {}) do
        overrides[opt.key] = scriptValues[opt.key]
    end

    local function syncOptions(wrapperSource)
        local updated, err = applyGenesisOptions(wrapperSource, overrides)
        if not updated then
            return nil, err
        end
        return updated
    end

    local encodedName = script.name:gsub(" ", "%%20")
    local wrapperUrl = Config.GenesisBase .. encodedName
    Loader.RunRemote(script.name, wrapperUrl, syncOptions)
end

local function buildGenesis()
    local tab = makeTab("Genesis FE", "Where it all started for me")
    local settingsTab
    local settingsScriptName

    local function openGenesisSettings(script)
        if settingsTab and settingsScriptName == script.name then
            settingsTab:Select()
            return
        end

        -- Keep only one temporary settings page so the top navigation does not fill up.
        if settingsTab then
            settingsTab:Remove()
            settingsTab = nil
            settingsScriptName = nil
        end

        local values = GenesisValues.scripts[script.name]
        if not values then
            values = {}
            GenesisValues.scripts[script.name] = values
        end

        settingsTab = window:CreateTab({ name = script.name .. " Settings" })
        settingsScriptName = script.name

        settingsTab:CreateButton({
            name = "Back to Genesis FE",
            description = "Return to the Genesis script list.",
            callback = function()
                tab:Select()
            end,
        })

        settingsTab:CreateText({
            text = "Configure " .. script.name .. " here, then press Launch. These settings are saved separately for this script.",
        })

        if script.fdless then
            settingsTab:CreateSection({ name = "FDless Options" })
            for _, opt in ipairs(GenesisShared) do
                addGenesisOption(settingsTab, opt, values, "genesis_" .. script.name)
            end
        end

        if script.options and #script.options > 0 then
            settingsTab:CreateSection({ name = "Script Options" })
            for _, opt in ipairs(script.options) do
                addGenesisOption(settingsTab, opt, values, "genesis_" .. script.name)
            end
        end

        settingsTab:CreateSection({ name = "Launch" })
        settingsTab:CreateButton({
            name = "Launch " .. script.name,
            description = "Start this Genesis script with the settings above.",
            callback = function()
                launchGenesis(script)
            end,
        })

        settingsTab:Select()
    end

    tab:CreateSection({ name = "Rig" })
    tab:CreateButton({
        name = "Join Genesis rig game",
        description = "Teleports you to Foundation, the Genesis rig game. The hub closes when you leave this server.",
        callback = function()
            Loader.Teleport("Foundation", Config.FoundationPlaceId)
        end,
    })

    tab:CreateSection({ name = "Scripts" })
    for _, script in ipairs(GenesisScripts) do
        GenesisValues.scripts[script.name] = GenesisValues.scripts[script.name] or {}

        local hasSettings = script.fdless or (script.options and #script.options > 0)
        local note = hasSettings
            and "Opens this script's settings page."
            or "No settings available — launches immediately."

        tab:CreateButton({
            name = script.name,
            description = note,
            callback = function()
                if hasSettings then
                    openGenesisSettings(script)
                else
                    launchGenesis(script)
                end
            end,
        })
    end
end

local TwentyFourScripts = {
    { name = "FE Brimstone", file = "Brimstone.txt", desc = "The last Forsaken..." },
    { name = "FE Dual Solaris V2 [Beta]", file = "DualSolarisV2.txt" },
    { name = "FE Dubstep Gun", file = "DubstepGun.txt" },
    { name = "FE Hacklord", file = "Hacklord.txt" },
    { name = "FE Star Glitcher V2", file = "StarGlitcherV2.txt" },
    { name = "FE Star Glitcher V1", file = "StarGlitcher.txt", desc = "Discontinued version" },
}

local function build24Hours()
    local tab = makeTab("24 Hours", "Oh my God, isn't that the guy from Forsaken")
    tab:CreateSection({ name = "Accessories" })
    tab:CreateButton({
        name = "Join 24 Stellaris",
        description = "Teleports you to the game with the accessories for these scripts. The hub closes when you leave this server.",
        callback = function()
            Loader.Teleport("24 Stellaris", Config.StellarisPlaceId)
        end,
    })
    tab:CreateSection({ name = "Scripts" })
    for _, script in ipairs(TwentyFourScripts) do
        tab:CreateButton({
            name = script.name,
            description = script.desc,
            callback = function()
                Loader.RunRemote(script.name, Config.TwentyFourBase .. script.file)
            end,
        })
    end
end

local function buildNooby()
    local tab = makeTab("Nooby Reanimate", "Ah ha ha you're a noob ha ha noob ha ha")
    tab:CreateSection({ name = "Launch" })
    tab:CreateButton({
        name = "Launch Nooby's UH Modded Reanimation",
        description = "Stops the hub's FDless if running, then loads Nooby's script.",
        callback = Loader.LaunchNooby,
    })
end

local function buildHats()
    local tab = makeTab("Hats", "Hats and Auto Rig tools")
    tab:CreateSection({ name = "Auto Rig" })
    tab:CreateButton({
        name = "Join Auto Rig game",
        description = "Teleports you to the autorig experience for making custom rigs. The hub closes when you leave this server.",
        callback = function()
            Loader.Teleport("Auto Rig", Config.AutoRigPlaceId)
        end,
    })
    tab:CreateSection({ name = "Baseplate" })
    tab:CreateButton({
        name = "Join Just a baseplate",
        description = "Teleports you to [UP] Just a baseplate. The hub closes when you leave this server.",
        callback = function()
            Loader.Teleport("Just a baseplate", Config.BaseplatePlaceId)
        end,
    })
end

local function buildCredits()
    local tab = makeTab("Credits", "Credits")
    tab:CreateText({ name = "Credits", text = "To be filled in." })
end

----------------------------------------------------------------
-- Init
----------------------------------------------------------------
buildGenesis()
build24Hours()
buildNooby()
buildHats()
buildCredits()

return Hub
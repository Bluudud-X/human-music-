--[[
    Reanimate Hub  |  Phase 1: UI
    Framework: Rayfield Gen2 (https://docs.sirius.menu/rayfield-gen2)
]]

----------------------------------------------------------------
-- Config
----------------------------------------------------------------
local Config = {
    Title = "24 Hours Hub",
    TwentyFourBase = "https://raw.githubusercontent.com/BloxinStud10/24-Hours/refs/heads/main/Loadstrings/",
    FDlessUrl = "https://raw.githubusercontent.com/Bluudud-X/human-music-/refs/heads/main/FDless_merged_min.lua",
    AutoRigPlaceId = 95964727828755, -- "autorig" experience, for making custom rigs
    StellarisPlaceId = 112144950473007, -- "24 Stellaris" experience, the 24 Hours accessories game
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
-- Custom FDless manager (started before 24 Hours scripts)
-- The merged FDless file is a hook layer: once loaded, it swaps the FDless source that
-- scripts loaded afterwards (24 Hours) try to use for the custom one. It exposes
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
        warn("[24 Hours Hub] TerminateFDless error: " .. tostring(err))
        return false
    end
    return true
end

-- Global entry point from the spec, for other scripts to call.
_G.StopFDless = FDless.Stop

----------------------------------------------------------------
-- Rayfield + window
----------------------------------------------------------------
local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
end)
if not ok or not Rayfield then
    warn("[24 Hours Hub] Failed to load Rayfield Gen2: " .. tostring(Rayfield))
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
        warn("[24 Hours Hub] " .. label .. " teleport failed: " .. tostring(err))
    end
end

-- Runs a remote loadstring file unchanged.
function Loader.RunRemote(label, url)
    local fetched, source = pcall(game.HttpGet, game, url)
    if not fetched or type(source) ~= "string" or source == "" then
        Hub.Notify(label, "Failed to download the script.")
        warn("[24 Hours Hub] " .. label .. " download failed: " .. tostring(source))
        return false
    end

    local fn, compileErr = loadstring(source)
    if not fn then
        Hub.Notify(label, "Script failed to compile.")
        warn("[24 Hours Hub] " .. label .. " compile error: " .. tostring(compileErr))
        return false
    end

    task.spawn(function()
        local ran, runErr = pcall(fn)
        if not ran then
            Hub.Notify(label, "Script errored while running.")
            warn("[24 Hours Hub] " .. label .. " runtime error: " .. tostring(runErr))
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
        warn("[24 Hours Hub] Nooby download failed: " .. tostring(source))
        return
    end

    local fn, compileErr = loadstring(source)
    if not fn then
        Hub.Notify("Nooby Reanimate", "Script failed to compile.")
        warn("[24 Hours Hub] Nooby compile error: " .. tostring(compileErr))
        return
    end

    task.spawn(function()
        local ran, runErr = pcall(fn)
        if not ran then
            Hub.Notify("Nooby Reanimate", "Script errored while running.")
            warn("[24 Hours Hub] Nooby runtime error: " .. tostring(runErr))
        end
    end)
end

----------------------------------------------------------------
-- 24 Hours script collection.\nlocal TwentyFourScripts = {
    { name = "FE Brimstone", file = "Brimstone.txt", desc = "The last Forsaken..." },
    { name = "FE Dual Solaris V2 [Beta]", file = "DualSolarisV2.txt" },
    { name = "FE Dubstep Gun", file = "DubstepGun.txt" },
    { name = "FE Hacklord", file = "Hacklord.txt" },
    { name = "FE Star Glitcher V2", file = "StarGlitcherV2.txt" },
    { name = "FE Star Glitcher V1", file = "StarGlitcher.txt", desc = "Discontinued version" },
}

local function build24Hours()
    local tab = makeTab("24 Hours", "24 Hours scripts and accessories")
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
            description = script.desc or "Loads this 24 Hours script. Custom FDless is started automatically first.",
            callback = function()
                local started, startErr = FDless.Start()
                if not started then
                    Hub.Notify("Custom FDless", "Could not start FDless. Script launch cancelled.")
                    warn("[24 Hours Hub] FDless start failed: " .. tostring(startErr))
                    return
                end
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

local function buildFDless()
    local tab = makeTab("FDless", "Manage the hub's custom FDless hook and reanimation.")
    tab:CreateSection({ name = "Controls" })
    tab:CreateButton({
        name = "Start Custom FDless",
        description = "Installs the custom FDless hook layer and displays its STOP FDLESS button.",
        callback = function()
            local started, err = FDless.Start()
            if started then
                Hub.Notify("Custom FDless", "Started.")
            else
                Hub.Notify("Custom FDless", "Failed to start.")
                warn("[24 Hours Hub] FDless start failed: " .. tostring(err))
            end
        end,
    })
    tab:CreateButton({
        name = "Stop Custom FDless",
        description = "Stops tracked FDless reanimations, restores its hooks, and removes its stop button.",
        callback = function()
            FDless.Stop()
            Hub.Notify("Custom FDless", "Stop requested.")
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
build24Hours()
buildFDless()
buildNooby()
buildHats()
buildCredits()

return Hub
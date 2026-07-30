-- Stay Quiet, They Might Pass - Shared (logic gated by isServerOrSP)
-- Distant/anonymous world sounds (e.g. meta gun): chance to spawn a population horde on a ring
-- around the nearest player, marching toward the noise via createHordeFromTo.
-- Works in singleplayer and MP: run when isServer() or not isClient() (SP + dedicated server).

StayQuiet = StayQuiet or {}

-- Config: all ranges use MIN/MAX; value is random in [MIN, MAX] when used. Set MIN=MAX for fixed behavior.
StayQuiet.MIN_RADIUS_MIN = 150
StayQuiet.MIN_RADIUS_MAX = 250
StayQuiet.CHANCE_PERCENT_MIN = 2
StayQuiet.CHANCE_PERCENT_MAX = 10
StayQuiet.COOLDOWN_HOURS_MIN = 0.5
StayQuiet.COOLDOWN_HOURS_MAX = 1.5
StayQuiet.HORDE_SIZE_MIN = 20
StayQuiet.HORDE_SIZE_MAX = 60
-- Ring distance from player (tiles). Unloaded is fine — population manager handles off-map.
StayQuiet.SPAWN_DIST_MIN = 80
StayQuiet.SPAWN_DIST_MAX = 150

StayQuiet.ready = false
StayQuiet.lastHordeTime = -999
StayQuiet.nextCooldownHours = 0.75

-- When true: log each createHordeFromTo (size, spawn, target, distances).
StayQuiet.logSpawns = true
-- When true: log OnWorldSound checks (skip reasons + trigger) for nil-source sounds with radius >= MIN_RADIUS_MIN.
StayQuiet.logTriggers = true
-- Debug: set true to test. Press G. OnKeyPressed is client-only; MP uses sendClientCommand to server.
StayQuiet.debugMode = false
-- Prefer matching Keyboard.KEY_G when Lua exposes it. 34 = legacy LWJGL KEY_G.
StayQuiet.debugKeys = { 34 }

local STAYQUIET_MOD_ID = "StayQuietTheyMightPass"

local function rollInt(minVal, maxVal)
    if maxVal <= minVal then return minVal end
    return minVal + ZombRand(maxVal - minVal + 1)
end

local function rollFloat(minVal, maxVal)
    if maxVal <= minVal then return minVal end
    return minVal + (maxVal - minVal) * ZombRand(10001) / 10000
end

local function debugKeyMatches(key)
    if Keyboard and Keyboard.KEY_G and key == Keyboard.KEY_G then
        return true
    end
    local keys = StayQuiet.debugKeys
    if type(keys) == "table" then
        for _, k in ipairs(keys) do
            if key == k then return true end
        end
    end
    return false
end

local function getLocalPlayerForDebug()
    local p = getPlayer and getPlayer()
    if p then return p end
    if getSpecificPlayer then
        return getSpecificPlayer(0)
    end
    return nil
end

-- Nearest living player to (x,y) for centering the spawn ring. SP: local player. Server: online players.
local function getRingCenterPlayer(nearX, nearY)
    if isServer() and getOnlinePlayers then
        local players = getOnlinePlayers()
        if players then
            local best, bestDist = nil, nil
            local n = players.size and players:size() or 0
            for i = 0, n - 1 do
                local p = players.get and players:get(i) or players[i + 1]
                if p and not p:isDead() then
                    local dx = p:getX() - nearX
                    local dy = p:getY() - nearY
                    local d = dx * dx + dy * dy
                    if not bestDist or d < bestDist then
                        best, bestDist = p, d
                    end
                end
            end
            if best then return best end
        end
    end
    return getLocalPlayerForDebug()
end

local function isServerOrSP()
    return isServer() or not isClient()
end

local function logSpawnHorde(hordeLine, detailLine, warnLine)
    if not StayQuiet.logSpawns then return end
    print("[StayQuiet] " .. tostring(hordeLine))
    print("[StayQuiet] " .. tostring(detailLine))
    if warnLine then
        print("[StayQuiet] " .. tostring(warnLine))
    end
end

local function logTrigger(msg)
    if not StayQuiet.logTriggers then return end
    print("[StayQuiet] " .. tostring(msg))
end

local function getGameTimeHours()
    local gt = getGameTime and getGameTime()
    if not gt or not gt.getWorldAgeHours then return 0 end
    return gt:getWorldAgeHours()
end

-- Spawn on a ring around the nearest player; population horde marches toward the noise.
-- Returns horde size requested (0 on failure). Engine owns pathing via createHordeFromTo.
local function spawnHorde(soundX, soundY, soundZ, reason)
    reason = reason or "spawn"
    if not isServerOrSP() then return 0 end
    if not createHordeFromTo then
        logSpawnHorde(
            "HORDE FAIL",
            "SPAWN reason=" .. tostring(reason) .. " createHordeFromTo missing",
            "WARN createHordeFromTo not available"
        )
        return 0
    end

    local player = getRingCenterPlayer(soundX, soundY)
    if not player then
        logSpawnHorde(
            "HORDE FAIL",
            string.format(
                "SPAWN reason=%s target=%d,%d,%d FAIL no player for ring",
                reason,
                math.floor(soundX),
                math.floor(soundY),
                math.floor(soundZ)
            ),
            "WARN no player to center spawn ring"
        )
        return 0
    end

    local playerX, playerY = player:getX(), player:getY()
    local angle = ZombRand(1000) / 1000.0 * 2 * math.pi
    local distFromPlayer = rollInt(StayQuiet.SPAWN_DIST_MIN, StayQuiet.SPAWN_DIST_MAX)
    local spawnX = playerX + distFromPlayer * math.cos(angle)
    local spawnY = playerY + distFromPlayer * math.sin(angle)
    local targetX = soundX
    local targetY = soundY
    local hordeSize = rollInt(StayQuiet.HORDE_SIZE_MIN, StayQuiet.HORDE_SIZE_MAX)

    createHordeFromTo(spawnX, spawnY, targetX, targetY, hordeSize)

    local distToNoise = math.sqrt((spawnX - targetX) ^ 2 + (spawnY - targetY) ^ 2)
    logSpawnHorde(
        string.format(
            "HORDE createHordeFromTo size=%d allowed=%d..%d",
            hordeSize,
            StayQuiet.HORDE_SIZE_MIN,
            StayQuiet.HORDE_SIZE_MAX
        ),
        string.format(
            "SPAWN reason=%s spawn=%.0f,%.0f target=%.0f,%.0f,%.0f distFromPlayer=%d distToNoise=%.0f",
            reason,
            spawnX,
            spawnY,
            targetX,
            targetY,
            soundZ,
            distFromPlayer,
            distToNoise
        ),
        nil
    )
    return hordeSize
end

local function onWorldSound(x, y, z, radius, volume, source)
    if not isServerOrSP() then return end
    if not StayQuiet.ready then return end
    if source ~= nil then return end
    local logThis = StayQuiet.logTriggers and radius >= StayQuiet.MIN_RADIUS_MIN
    if not StayQuiet.debugMode then
        local minRadius = rollInt(StayQuiet.MIN_RADIUS_MIN, StayQuiet.MIN_RADIUS_MAX)
        if radius < minRadius then
            if logThis then
                logTrigger(string.format(
                    "SKIP radius=%d need>=%d vol=%d at %d,%d,%d",
                    radius, minRadius, volume, math.floor(x), math.floor(y), math.floor(z)
                ))
            end
            return
        end
        local now = getGameTimeHours()
        if now - StayQuiet.lastHordeTime < StayQuiet.nextCooldownHours then
            if logThis then
                logTrigger(string.format(
                    "SKIP cooldown left=%.2fh at %d,%d,%d radius=%d",
                    StayQuiet.nextCooldownHours - (now - StayQuiet.lastHordeTime),
                    math.floor(x), math.floor(y), math.floor(z), radius
                ))
            end
            return
        end
        local chance = rollInt(StayQuiet.CHANCE_PERCENT_MIN, StayQuiet.CHANCE_PERCENT_MAX)
        if ZombRand(100) >= chance then
            if logThis then
                logTrigger(string.format(
                    "SKIP chance roll failed need<%d at %d,%d,%d radius=%d",
                    chance, math.floor(x), math.floor(y), math.floor(z), radius
                ))
            end
            return
        end
    end
    if logThis or StayQuiet.logTriggers then
        logTrigger(string.format(
            "TRIGGER OnWorldSound at %d,%d,%d radius=%d vol=%d",
            math.floor(x), math.floor(y), math.floor(z), radius, volume
        ))
    end
    local got = spawnHorde(x, y, z, "OnWorldSound")
    if got and got > 0 then
        StayQuiet.lastHordeTime = getGameTimeHours()
        StayQuiet.nextCooldownHours = rollFloat(StayQuiet.COOLDOWN_HOURS_MIN, StayQuiet.COOLDOWN_HOURS_MAX)
    elseif StayQuiet.logTriggers then
        logTrigger("TRIGGER spawn failed got=0 (cooldown not applied)")
    end
end

local function onGameStart()
    StayQuiet.ready = true
    logTrigger("ready (logTriggers=" .. tostring(StayQuiet.logTriggers) .. " debugMode=" .. tostring(StayQuiet.debugMode) .. " createHordeFromTo)")
end

-- Debug: G (see debugKeys). Runs on client; SP/host calls spawn here, MP client asks server.
local function onKeyPressed(key)
    if not StayQuiet.debugMode then return end
    if not debugKeyMatches(key) then return end
    local player = getLocalPlayerForDebug()
    if not player then
        return
    end
    local x, y, z = player:getX(), player:getY(), player:getZ()
    if isServerOrSP() then
        spawnHorde(x, y, z, "debugKey")
    elseif sendClientCommand then
        sendClientCommand(player, STAYQUIET_MOD_ID, "debugSpawnHorde", { x = x, y = y, z = z })
    end
end

Events.OnGameStart.Add(onGameStart)
Events.OnWorldSound.Add(onWorldSound)
Events.OnKeyPressed.Add(onKeyPressed)

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= STAYQUIET_MOD_ID or command ~= "debugSpawnHorde" then return end
    if not isServer() then return end
    if not StayQuiet.debugMode or not args then return end
    local x, y, z = args.x, args.y, args.z
    if not x or not y or not z then return end
    spawnHorde(x, y, z, "clientCommand")
end)

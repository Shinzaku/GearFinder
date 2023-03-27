addon.name      = "gearfinder";
addon.author    = "Shinzaku";
addon.version   = "1.0";
addon.desc      = "Find gear in inventory based on filterable stats; Generate sets based on criteria";

require "common";
local imgui = require("imgui");
local json = require("json");
local res = AshitaCore:GetResourceManager();
require "helpers";
require "augments";
require "gui";
local allStats = require("allstats");
local slipData = require("slips");
local ffi       = require('ffi');
local d3d       = require('d3d8');
local C         = ffi.C;
local d3d8dev   = d3d.get_device();
local memPatterns = T{
    delveAugFunc = "8BC34725FFFF0000C644242000668B0C45????????",
    miscAugFunc = "663D80047244663DDF04773E25FFFF????8D0485????????",
    statAugFunc = "81E2FFFF000033C903D28BFA8A97????????",
    unityAugFunc = "83C408C39090A1????????C390",
    evoAugFunc = "393A0F849B0000008B72F8????74",
    bagAccess = "A1????????8B88B4000000C1E907F6C101E9",
}
local memAddress = T{
    delveAugMap = nil,
    augCalcMap = nil,
    statCalcMap = nil,
    unityAugMap = nil,
    evoAugMap = nil,
    wardrobeFlags = nil,
}

ffi.cdef[[
    HRESULT __stdcall D3DXCreateTextureFromFileInMemoryEx(IDirect3DDevice8* pDevice, LPCVOID pSrcData, UINT SrcDataSize, UINT Width, UINT Height, UINT MipLevels, DWORD Usage, D3DFORMAT Format, D3DPOOL Pool, DWORD Filter, DWORD MipFilter, D3DCOLOR ColorKey, D3DXIMAGE_INFO* pSrcInfo, PALETTEENTRY* pPalette, IDirect3DTexture8** ppTexture);
]];

-- Addon activity/actions
local rtGlobals = T{
    actions = T{
        idle = 1,
        caching = 2,
        optimizing = 3,
    },
    rtBase = 1;
    batchSize = 150;
    lastCache = 0;
    cAction = 1;
    routines = T{},
};

local gearGlobals = T{
    gearCache = T{},
    resCache = T{},
    workingStats = T{},
    orderedStats = T{},
    searchFilters = T{},
    savedSets = T{},
    workingSet = T{
        { slot=0, name="main", item=T{}, texture=nil, equipStatus=nil },
        { slot=1, name="sub", item=T{}, texture=nil, equipStatus=nil },
        { slot=2, name="range", item=T{}, texture=nil, equipStatus=nil },
        { slot=3, name="ammo", item=T{}, texture=nil, equipStatus=nil },
        { slot=4, name="head", item=T{}, texture=nil, equipStatus=nil },
        { slot=9, name="neck", item=T{}, texture=nil, equipStatus=nil },
        { slot=11, name="ear1", item=T{}, texture=nil, equipStatus=nil },
        { slot=12, name="ear2", item=T{}, texture=nil, equipStatus=nil },
        { slot=5, name="body", item=T{}, texture=nil, equipStatus=nil },
        { slot=6, name="hands", item=T{}, texture=nil, equipStatus=nil },
        { slot=13, name="ring1", item=T{}, texture=nil, equipStatus=nil },
        { slot=14, name="ring2", item=T{}, texture=nil, equipStatus=nil },
        { slot=15, name="back", item=T{}, texture=nil, equipStatus=nil },
        { slot=10, name="waist", item=T{}, texture=nil, equipStatus=nil },
        { slot=7, name="legs", item=T{}, texture=nil, equipStatus=nil },
        { slot=8, name="feet", item=T{}, texture=nil, equipStatus=nil },
    },
    hoveredTooltip = T{ item=nil, text="" },
    equipDelay = 0,
};

local uiConfig = T{
    is_open = { true, },
    main_pos = { 0, 0 },
    selecting_gear = { false, },
    select_pos_offset = { 0, 0 },
    select_slot = 0,
    select_set_index = 0,
    style = T{
        colTitleBg = { 0.4, 0.4, 0.4, 1.0 },
        colTitleBgActive = { 0.16, 0.29, 0.48, 1.0 },
        colTitleBgCollapsed = { 0.4, 0.4, 0.4, 0.51 },
        colProgressBar = { 0.92, 0.49, 0.50, 1.0 },
        colEquipButton = { 0.3, 0.3, 0.3, 1.0 },
        colEquipButtonHovered = { 0.92, 0.49, 0.50, 0.75},
        colListLabel = { 0.6, 0.6, 0.6, 1.0 },
        colListActive = { 0.7, 1.0, 0.83, 1.0 },
        colWindowBg = { 0.15, 0.15, 0.15, 0.9 },
        colChildBg = { 0.2, 0.2, 0.2, 0.95 },
        colError = { 0.90, 0.20, 0.23, 0.75 },
    },
    awfont_icons = T{
        trashcan = "\xef\x87\xb8",
        fire = "\xef\x81\xad",
        ice = "\xef\x8b\x9c",
        wind = "\xef\x9c\xae",
        earth = "\xef\x8e\xa5",
        lightning = "\xef\x83\xa7",
        water = "\xef\x9d\xb3",
        light = "\xef\x86\x85",
        dark = "\xef\x86\x86",
        augslot = "\xef\x86\x92",
    },
    filterOps = T{
        "=",
        "!=",
        "<",
        "<=",
        ">",
        ">=",
    }
}

-- Sets
local defCategoryOrder = T{
    Weapons = 1,
    Shield = 2,
    Attributes = 3,
    Stats = 4,
    Utility = 5,
    Skills = 6,
    Traits = 7,
    Unique = 8,
    ["Pet: Attributes"] = 9,
    ["Pet: Stats"] = 10,
    ["Pet: Utility"] = 11,
    ["Pet: Skills"] = 12,
}

local HelpString = "\30\67Check the main window for all available options\n" ..
"\30\67If issues found, please submit an issue at:\n\30\92https://github.com/Shinzaku/GearFinder/";

function TryAddToCache(id, slot, ibag, slipId, ext)
    local rItem = res:GetItemById(id);
    if (rItem and (rItem.Type == 4 or rItem.Type == 5) and rItem.Skill < 48) then
        local co = coroutine.create(function()
            local resItem = GetResCacheItemById(rItem.Id, gearGlobals);
            if (not resItem) then
                resItem = T{
                    id = rItem.Id,
                    equipSlots = rItem.Slots,
                    jobs = rItem.Jobs,
                    lvl = rItem.Level,
                    ilvl = rItem.ItemLevel,
                    su = rItem.SuperiorLevel,
                    name = rItem.Name[1],
                };
                gearGlobals.resCache:insert(resItem);
                resItem.stats = ParseResourceDescription(rItem.Id, allStats)
            end
        end);
        local co2 = coroutine.create(function()
            local cacheItem = T{
                id = rItem.Id,
                bag = ibag,
                slot = slot,
                slip = slipId,
                working = false,
                augStats = nil,
            };
            if (cacheItem.id > 0 and ext) then
                cacheItem.augStats = T{};
                cacheItem.augStats.base = T{};
                ParseAugments(memAddress, ext, cacheItem.augStats, allStats);
            end

            gearGlobals.gearCache:insert(cacheItem);
        end);
        rtGlobals.routines:insert(co);
        rtGlobals.routines:insert(co2);
    end
end

function CacheGear()
    gearGlobals.gearCache = T{};
    local inv = AshitaCore:GetMemoryManager():GetInventory();
    for ibag=0,16 do
		for idx=0,inv:GetContainerCountMax(ibag) do
			local iData = inv:GetContainerItem(ibag,idx);
			if(iData == nil) then
				break;
			end

            if (iData.Id >= 29312 and iData.Id <= 29339) then
                local extData = iData.Extra:totable();
                for ix,iId in pairs(slipData[tostring(iData.Id)]) do
                    local byteOffset = math.floor((ix - 1) / 8) + 1;
                    local bitOffset = (ix - 1) % 8;
                    local currByte = extData[byteOffset];
                    if (bit.band(currByte, 2 ^ bitOffset) == (2 ^ bitOffset)) then
                        TryAddToCache(iId, iData.Index, ibag, iData.Id, nil);
                    end
                end
            elseif (iData.Id > 0 and iData.Id ~= 65535) then
                TryAddToCache(iData.Id, iData.Index, ibag, 0, iData.Extra);
            end
		end
	end
    rtGlobals.cAction = rtGlobals.actions.caching;
    PPrint(("Caching gear... Please wait"));
end

function ReadWriteCache(mode)
    -- TODO
    local cachePath = ("%sconfig\\addons\\%s\\%s-%d\\"):format(AshitaCore:GetInstallPath(), addon.name, GetPlayerEntity().Name, GetPlayerEntity().ServerId);
    local resCachePath = cachePath .. "res.json";
    local gearCachePath = cachePath .. "gear.json";
    local fileResCache = io.open(resCachePath, mode);
    local fileGearCache = io.open(gearCachePath, mode);
    if (fileResCache == nil or fileGearCache == nil) then
        PPrint(cachePath);
        PPrint("No cache found");
        return;
    end
    if (mode == "r") then
        gearGlobals.resCache = json.decode(fileResCache:read("*a"));
        gearGlobals.gearCache = json.decode(fileGearCache:read("*a"));
    elseif (mode == "w") then
        fileResCache:write(json.encode(gearGlobals.resCache));
        fileGearCache:write(json.encode(gearGlobals.gearCache));
    end

    fileResCache:close();
    fileGearCache:close();
    return;
end

function SetEquippedToWorking()
    for i,v in pairs(gearGlobals.workingSet) do
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local equipment = inv:GetEquippedItem(v.slot);
        local index = equipment.Index;
        local bag = 0;
        local itemId = 0;

        if (index == nil or index == 0) then
            -- Do nothing; Skip over
        else
            if (index < 2048) then
                bag = 0;
            elseif (index < 2560) then
                bag = 8;
                index = index - 2048;
            elseif (index < 2816) then
                bag = 10;
                index = index - 2560;
            elseif (index < 3072) then
                bag = 11;
                index = index - 2816;
            elseif (index < 3328) then
                bag = 12;
                index = index - 3072;
            elseif (index < 3584) then
                bag = 13;
                index = index - 3328;
            elseif (index < 3840) then
                bag = 14;
                index = index - 3584;
            elseif (index < 4096) then
                bag = 15;
                index = index - 3840;
            elseif (index < 4352) then
                bag = 16;
                index = index - 4096;
            end

            itemId = inv:GetContainerItem(bag, index).Id;

            if (itemId == 0) then
                -- Skip over
            else
                for ci,cg in pairs(gearGlobals.gearCache) do
                    if (cg.id == itemId and cg.bag == bag and cg.slot == index) then
                            SetWorkingSlot(i, cg);
                        break;
                    end
                end
            end
        end
    end
    UpdateWorkingStats();
end

function SetWorkingStats(activeCategories, newWorkingStats, k, p)
    if (k:find("converts")) then
        if (not newWorkingStats["hp"]) then
            newWorkingStats["hp"] = CreateNewStat(0, 0, false, false);
        end
        if (not newWorkingStats["mp"]) then
            newWorkingStats["mp"] = CreateNewStat(0, 0, false, false);
        end

        if (k:find("HPMP")) then
            newWorkingStats["hp"].convertDiff = newWorkingStats["hp"].convertDiff - p.base;
            newWorkingStats["mp"].convertDiff = newWorkingStats["mp"].convertDiff + p.base;
        else
            newWorkingStats["hp"].convertDiff = newWorkingStats["hp"].convertDiff + p.base;
            newWorkingStats["mp"].convertDiff = newWorkingStats["mp"].convertDiff - p.base;
        end
    else
        if (not newWorkingStats[k]) then
            newWorkingStats[k] = CreateNewStat(p.base, p.aug, p.percent, false);
            newWorkingStats[k].min = newWorkingStats[k].min + p.min;
            newWorkingStats[k].max = newWorkingStats[k].max + p.max;
            activeCategories:insert(allStats[k].category);
        elseif (k ~= "wtype" and k ~= "dmg" and k ~= "delay" and k ~= "shsize") then
            newWorkingStats[k].base = newWorkingStats[k].base + p.base;
            newWorkingStats[k].aug = newWorkingStats[k].aug + p.aug;
            newWorkingStats[k].min = newWorkingStats[k].min + p.min;
            newWorkingStats[k].max = newWorkingStats[k].max + p.max;
        end
    end
end

function UpdateWorkingStats()
    local newWorkingStats = T{};
    local activeCategories = T{};
    for i,v in pairs(gearGlobals.workingSet) do
        if (v.item.id) then
            local resItem = GetResCacheItemById(v.item.id, gearGlobals);
            if (resItem) then
                local resStats = resItem.stats;
                if (resStats.base) then
                    for k,p in pairs(resStats.base) do
                        SetWorkingStats(activeCategories, newWorkingStats, k, p);
                    end
                end
                if (v.item.augStats) then
                    for k,p in pairs(v.item.augStats.base) do
                        SetWorkingStats(activeCategories, newWorkingStats, k, p);
                    end
                end
            end
        end
    end

    for i,v in ipairs(gearGlobals.orderedStats) do
        v.visible = false;
        for k,m in ipairs(activeCategories) do
            if (v.category == m) then
                v.visible = true;
            end
        end
    end

    -- Show comparison and/or delta
    gearGlobals.workingStats = newWorkingStats;
end

function SetWorkingSlot(setIndex, itemData)
    if (gearGlobals.workingSet[setIndex].item) then
        gearGlobals.workingSet[setIndex].item.working = false;
    end

    if (itemData) then
        -- TODO
        -- Conditionally check for multi-slot gear
        -- Check for dual-wield
        -- Check for range + ammo combo
        itemData.working = true;
        gearGlobals.workingSet[setIndex].item = itemData;
        gearGlobals.workingSet[setIndex].texture = LoadTexture(res:GetItemById(itemData.id), ffi, C, d3d, d3d8dev);
    else
        gearGlobals.workingSet[setIndex].item = T{};
        gearGlobals.workingSet[setIndex].texture = nil;
    end

    uiConfig.selecting_gear[1] = false;
    UpdateWorkingStats();
end



ashita.events.register("command", "command_callback1", function (e)
    local args = e.command:args();
    if (#args == 0 or args[1] ~= "/gfind") then
        return;
    else
        e.blocked = true;
        if (not args[2]) then
            uiConfig.is_open[1] = not uiConfig.is_open[1];
        elseif (args[2] == "help") then
            PPrint(HelpString);
        end
    end
end);

ashita.events.register("load", "load_cb", function()
    memAddress.delveAugMap = ashita.memory.read_uint32(ashita.memory.find('FFXiMain.dll',  0,  memPatterns.delveAugFunc,  0,  0) + 17);
    memAddress.augCalcMap = ashita.memory.read_uint32(ashita.memory.find('FFXiMain.dll',  0,  memPatterns.miscAugFunc,  0,  0) + 27);
    memAddress.statCalcMap = ashita.memory.read_uint32(ashita.memory.find('FFXiMain.dll',  0,  memPatterns.statAugFunc,  0,  0) + 14);
    memAddress.unityAugMap = ashita.memory.read_uint32(ashita.memory.read_uint32(ashita.memory.find('FFXiMain.dll',  0,  memPatterns.unityAugFunc,  0,  0) + 7));
    memAddress.evoAugMap = ashita.memory.read_uint32(ashita.memory.find('FFXiMain.dll',  0,  memPatterns.evoAugFunc,  0,  0) + 25);
    memAddress.wardrobeFlags = ashita.memory.read_uint32(ashita.memory.read_uint32(ashita.memory.find('FFXiMain.dll',  0,  memPatterns.bagAccess,  1,  0)));
    for i,v in pairs(memAddress) do
        if (v == nil) then
            PPrint("Not all memory addresses found - May crash from augment parsing or bag visibility checks");
            break;
        end
    end

    -- Init stat ordering
    for k,v in pairs(allStats) do
        local orderedExists = false;
        for l,m in ipairs(gearGlobals.orderedStats) do
            if (m.category and m.category == allStats[k].category) then
                m.stats:insert(k);
                orderedExists = true;
            end
        end
        if (not orderedExists) then
            local newCategory = { visible=false, category=allStats[k].category, stats=T{} };
            newCategory.stats:insert(k);
            gearGlobals.orderedStats:insert(newCategory);
        end
    end

    local sortCategoryOrder = (function(a, b)
        return defCategoryOrder[a.category] < defCategoryOrder[b.category];
    end);
    local sortOrder = (function(a, b)
        return allStats[a].order < allStats[b].order;
    end);
    table.sort(gearGlobals.orderedStats, sortCategoryOrder);
    for _,v in ipairs(gearGlobals.orderedStats) do
        table.sort(v.stats, sortOrder);
    end

    local pl = GetPlayerEntity();
    if (pl) then
        local configPath = ("%sconfig\\addons\\%s\\%s-%d\\"):format(AshitaCore:GetInstallPath(), addon.name, pl.Name, pl.ServerId);
        if (not ashita.fs.exists(configPath)) then
            ashita.fs.create_directory(configPath);
        end

        ReadWriteCache("r");
    else
        assert("Unable to load - player not found");
    end
end);

ashita.events.register("d3d_present", "present_cb", function ()
    if (rtGlobals.cAction > rtGlobals.actions.idle and #rtGlobals.routines > 0 and rtGlobals.rtBase <= #rtGlobals.routines) then
        local batchFinished = true;
        for ri=rtGlobals.rtBase,rtGlobals.rtBase + rtGlobals.batchSize do
            if (ri <= #rtGlobals.routines) then
                if (coroutine.status(rtGlobals.routines[ri]) == "suspended") then
                    coroutine.resume(rtGlobals.routines[ri]);
                    batchFinished = false;
                end
            end
        end

        local nextBatch = rtGlobals.rtBase + rtGlobals.batchSize;
        if (batchFinished) then
            rtGlobals.rtBase = nextBatch;
        end
    elseif (rtGlobals.cAction > rtGlobals.actions.idle and #rtGlobals.routines > 0) then
        rtGlobals.routines = T{};
        rtGlobals.rtBase = 1;

        if (rtGlobals.cAction == rtGlobals.actions.caching) then
            local sortByBag = (function(a, b)
                return a.bag < b.bag;
            end);
            table.sort(gearGlobals.gearCache, sortByBag);
            gearGlobals.resCache:sort((function(a, b) return a.id < b.id end));
            rtGlobals.lastCache = os.time();
            ReadWriteCache("w");
            PPrint(("Cache complete with %d items"):format(#gearGlobals.gearCache));
        end

        rtGlobals.cAction = rtGlobals.actions.idle;
    end

    -- Variable checks
    if (os.clock() >= gearGlobals.equipDelay) then
        gearGlobals.equipDelay = 0;
        for _,v in ipairs(gearGlobals.workingSet) do
            v.equipStatus = nil;
        end
    end

    DrawGUI(imgui, uiConfig, ffi, gearGlobals, allStats, rtGlobals, memAddress);
end);
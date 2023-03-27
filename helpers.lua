function PPrint(str)
    print("\30\110[GearFinder] : \30\067" .. str);
end

function LoadTexture(iData, ffi, C, d3d, d3d8dev)
    local newTex = nil;
    local texture_ptr = ffi.new('IDirect3DTexture8*[1]');
    local res = C.D3DXCreateTextureFromFileInMemoryEx(d3d8dev, iData.Bitmap, 0x980, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0, ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, texture_ptr);
    if (res ~= C.S_OK) then
        error(('Failed to load image texture: %08X (%s)'):fmt(res, d3d.get_error(res)));
    end;
    newTex = ffi.new('IDirect3DTexture8*', texture_ptr[0]);
    d3d.gc_safe_release(newTex);

    if (not newTex) then
        PPrint("Texture load failed");
    end
    return newTex;
end

function CreateNewStat(b, a, p, range)
    local newStat = T{ base=0, aug=0, min=0, max=0, percent=p, convertDiff=0 };
    if (range) then
        newStat.min = b;
        newStat.max = a;
        return newStat;
    else
        newStat.base = b;
        newStat.aug = a;
        return newStat;
    end
end

function GetWeaponTypeInfo(id)
    local wTypes = T{
        { "Hand-to-Hand", GetDamageType(1) },
        { "Dagger", GetDamageType(2) },
        { "Sword", GetDamageType(3) },
        { "Great Sword", GetDamageType(3) },
        { "Axe", GetDamageType(3) },
        { "Great Axe", GetDamageType(3) },
        { "Scythe", GetDamageType(3) },
        { "Polearm", GetDamageType(2) },
        { "Katana", GetDamageType(3) },
        { "Great Katana", GetDamageType(3) },
        { "Club", GetDamageType(1) },
        { "Staff", GetDamageType(1) },
        --25 "Bow",
        --26 "Gun",
        --27 "Ammo",
        -- 41 "String Instrument",
        -- 42 "Wind Instrument",
        -- 45 "Handbell"
    }

    return wTypes[id];
end

function GetDamageType(id)
    local dTypes = T{
        "Blunt",
        "Piercing",
        "Slashing",
    }

    return dTypes[id];
end

function GetElementName(id)
end

function GetShieldStats(size)
    local shieldData = T{
        { -20, 55 },
        { -40, 40 },
        { -50, 45 },
        { -65, 30 },
        { -75, 50 },
        { -60, 108 },
    }

    return shieldData[size];
end

function ScrubFFXISpecialCharacters(str)
    if (str) then
        str = str:replace("\x81\x60", "~");
        str = str:replace("\xEF\x1F", "FireResist");
        str = str:replace("\xEF\x20", "IceResist");
        str = str:replace("\xEF\x21", "WindResist");
        str = str:replace("\xEF\x22", "EarthResist");
        str = str:replace("\xEF\x23", "LtngResist");
        str = str:replace("\xEF\x24", "WaterResist");
        str = str:replace("\xEF\x25", "LightResist");
        str = str:replace("\xEF\x26", "DarkResist");
        str = str:replace("\x25", "%%");
        return str;
    end
    return "";
end

function ParseResourceDescription(iId, allStats)
    local rItem = AshitaCore:GetResourceManager():GetItemById(iId);
    local itemStats = T{};
    itemStats.base = T{};
    local parsePet = false;
    local desc = rItem.Description[1];

    local stats = itemStats.base;
    if (desc) then
        local blocks = ashita.regex.split(desc, ": ");
        for bix,bstr in pairs(blocks) do
            bstr = "\n" .. bstr .. ":\n";
            bstr = ScrubFFXISpecialCharacters(bstr);

            local batchCounter = 0;
            for _k,att in pairs(allStats) do
                local key = _k;
                if ((not key:contains("pet") and not parsePet) or (key:contains("pet") and parsePet) or (att.category=="Skills" and bstr:contains("skill"))) then
                    if (att.parent) then
                        key = att.parent;
                    end
                    if (key == "dmg" and rItem.Type == 4 and rItem.Damage > 0 and not stats["dmg"]) then
                        stats[key] = CreateNewStat(rItem.Damage, 0, false);
                    elseif (key == "delay" and rItem.Type == 4 and rItem.Delay > 0 and not stats["delay"]) then
                        stats[key] = CreateNewStat(rItem.Delay, 0, false);
                    elseif (key == "wtype" and rItem.Type == 4 and rItem.Skill > 0 and not stats["wtype"]) then
                        stats[key] = CreateNewStat(rItem.Skill, 0, false);
                    elseif (key == "shsize" and rItem.Type == 5 and rItem.ShieldSize > 0 and not stats["shsize"]) then
                        stats[key] = CreateNewStat(rItem.ShieldSize, 0, false);
                    elseif (att.match ~= "" and not stats[key]) then
                        if (key:find("converts")) then
                            local matches = ashita.regex.search(bstr, att.match);
                            if (matches) then
                                local amt = tonumber(matches[1][2]);
                                stats[key] = CreateNewStat(amt, 0, false, false);
                            end
                        else
                            local fullMatch = att.match .. "(\\d+)?~?(\\d+)?(%)?";
                            local matches = ashita.regex.search(bstr, fullMatch);
                            if (matches) then
                                local oper = matches[1][2];
                                local amt = tonumber(matches[1][3]);
                                local max = tonumber(matches[1][4]);
                                local percCheck = matches[1][5];
                                local isPercent = false;
                                if ((oper == "-") or (att.defsign and att.defsign < 0)) then
                                    amt = amt * -1;
                                end
                                if (percCheck ~= "") then
                                    isPercent = true;
                                end
                                if (not amt) then
                                    amt = 1;
                                end

                                if (amt >= att.min or att.min == 0) then
                                    if (max) then
                                        stats[key] = CreateNewStat(amt, max, isPercent, true);
                                    else
                                        stats[key] = CreateNewStat(amt, 0, isPercent, false);
                                    end
                                end
                            end
                        end
                    end
                    batchCounter = batchCounter + 1;
                    if (batchCounter % 10 == 0) then
                        coroutine.yield();
                    end
                end
            end

            -- Set flag for next block
            if (bstr:contains("Pet:") or bstr:contains("Wyvern:") or bstr:contains("Avatar:") or bstr:contains("Automaton:")) then
                parsePet = true;
            elseif (bstr:contains("Daytime:")) then
                itemStats.daytime = T{};
                stats = itemStats.daytime;
            elseif (bstr:contains("Nighttime:")) then
                itemStats.nighttime = T{};
                stats = itemStats.nighttime;
            elseif (bstr:contains("Assault:")) then
                itemStats.assault = T{};
                stats = itemStats.assault;
            elseif (bstr:contains("Salvage:")) then
                itemStats.salvage = T{};
                stats = itemStats.salvage;
            elseif (bstr:contains("Campaign:")) then
                itemStats.campaign = T{};
                stats = itemStats.campaign;
            elseif (bstr:contains("Dynamis (D):")) then
                itemStats.dynamisD = T{};
                stats = itemStats.dynamisD;
            elseif (bstr:contains("Dynamis:")) then
                itemStats.dynamis = T{};
                stats = itemStats.dynamis;
            elseif (bstr:contains("Domain Invasion:")) then
                itemStats.domainInvasion = T{};
                stats = itemStats.domainInvasion;
            elseif (bstr:contains("Latent:") or bstr:contains("Latent effect:")) then
                itemStats.latent = T{};
                stats = itemStats.latent;
            elseif (bstr:contains("Citizen of San d'Oria:")) then
                itemStats.citizenSandOria = T{};
                stats = itemStats.citizenSandOria;
            elseif (bstr:contains("Citizen of Bastok:")) then
                itemStats.citizenBastok = T{};
                stats = itemStats.citizenBastok;
            elseif (bstr:contains("Citizen of Windurst:")) then
                itemStats.citizenWindurst = T{};
                stats = itemStats.citizenWindurst;
            elseif (bstr:contains("asleep:")) then
                itemStats.asleep = T{};
                stats = itemStats.asleep;
            elseif (bstr:contains("Set:")) then
                itemStats.set = T{};
                stats = itemStats.set;
            end
        end
    end

    return itemStats;
end

function GetInventoryBagName(bag)
    local bags = T{
        "Gobbiebag",
        "Safe",
        "Storage",
        "Temporary",
        "Locker",
        "Satchel",
        "Sack",
        "Case",
        "Wardrobe",
        "Safe 2",
        "Wardrobe 2",
        "Wardrobe 3",
        "Wardrobe 4",
        "Wardrobe 5",
        "Wardrobe 6",
        "Wardrobe 7",
        "Wardrobe 8",
        "Recycle",
    };

    return bags[bag];
end

function GetItemTooltip(item, gearGlobals, allStats, uiConfig)
    local tooltip = "";
    local rItem = AshitaCore:GetResourceManager():GetItemById(item.id);
    local desc = ScrubFFXISpecialCharacters(rItem.Description[1]);
    local levelText = ("Lv%d\n"):format(rItem.Level);
    if (rItem.ItemLevel ~= 0) then
        local ilvl = rItem.ItemLevel;
        if (ilvl > 119) then
            ilvl = 119;
        end
        levelText = ("Lv%d\t\t<ILvl: %d>\n"):format(rItem.Level, ilvl);
    end
    tooltip = tooltip .. levelText .. desc;
    for _,v in ipairs(gearGlobals.orderedStats) do
        for i,key in ipairs(v.stats) do
            if (item.augStats) then
                local stat = item.augStats.base[key];
                if (stat and stat.aug ~= 0) then
                    local augName = allStats[key].longName;
                    if (key:find("pet")) then
                        augName = "Pet: " .. augName;
                    end
                    local valDisplay = "";
                    if (stat.aug > 0) then
                        valDisplay = "+";
                    end
                    valDisplay = valDisplay .. stat.aug;
                    if (stat.percent) then
                        valDisplay = valDisplay .. "%%";
                    end
                    tooltip = tooltip .. ("\n%s %s %s"):format(uiConfig.awfont_icons.augslot, augName, valDisplay);
                end
            end
        end
    end

    if (item.slip > 0) then
        tooltip = tooltip .. ("\n(In Storage Slip %02d)"):format(item.slip - 29311);
    end

    return tooltip;
end

function GetResCacheItemById(id, gearGlobals)
    for i,v in pairs(gearGlobals.resCache) do
        if (v.id == id) then
            return v;
        end
    end

    return nil;
end

function GetStatTotal(item, resItem, key)
    local stat = 0;
    for i,v in pairs(resItem.stats.base) do
        if (i == key) then
            stat = stat + v.base;
            stat = stat + v.min;
        end
    end
    if (item.augStats) then
        for i,v in pairs(item.augStats.base) do
            if (i == key) then
                stat = stat + v.aug;
            end
        end
    end

    return stat;
end

function InEquippableBag(item, memAddress)
    local flags = ashita.memory.read_uint8(memAddress.wardrobeFlags + 0xB4);
    if (item.slip ~= 0 or (item.bag >= 1 and item.bag <= 7) or item.bag == 9 or item.bag == 17) then
        return false;
    elseif (item.bag >= 11 and item.bag <= 16) then
        return bit.band(bit.rshift(flags, item.bag - 9), 0x01) ~= 0;
    end

    return true;
end

function SendEquipsetPacket(gearGlobals, memAddress)
    local equipset = gearGlobals.workingSet:copy(true);
    equipset = equipset:sort((function(a, b) return a.slot < b.slot end));
    local count = 0;
    local equipAddend = T{}
    for _,v in pairs(equipset) do
        local equipBuildSuccess = false;
        if (v.item.id ~= nil and InEquippableBag(v.item, memAddress)) then
            count = count + 1;
            equipBuildSuccess = true;
            equipAddend:insert(v.item.slot);
            equipAddend:insert(v.slot);
            equipAddend:insert(v.item.bag);
            equipAddend:insert(0);
        end

        for k,m in ipairs(gearGlobals.workingSet) do
            if (m.item.id ~= nil and m.item.id == v.item.id) then
                m.equipStatus = equipBuildSuccess;
            end
        end
    end
    local equipsetPacket = struct.pack("bbbbi", 0x51, 0x24, 0, 0, count):totable();
    for _,v in ipairs(equipAddend) do
        equipsetPacket:insert(v);
    end

    if (count > 0) then
        AshitaCore:GetPacketManager():AddOutgoingPacket(0x051, equipsetPacket);
        gearGlobals.equipDelay = os.clock() + 3;
        PPrint("Attempted to equip items");
    else
        gearGlobals.equipDelay = os.clock() + 1;
        PPrint("No equippable items in working set");
    end
end
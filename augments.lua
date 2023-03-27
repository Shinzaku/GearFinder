function ParseAugments(memAddress, ext, stats, allStats)
    local augSys = struct.unpack("B", ext, 0x01);
    local augFlag = struct.unpack("B", ext, 0x02);
    local augs = T{};

    if (augSys == 2) then
        if (bit.band(augFlag, 0x10) ~= 0) then
            -- Unknown type
            local parseid = bit.band(struct.unpack("I", ext, 0x05), 0xFF);
            if (parseid == 0) then
                parseid = 1;
            end
            augs:insert({ id=parseid, val=struct.unpack("H", ext, 0x07) });
        elseif (bit.band(augFlag, 0x20) ~= 0) then
            -- Delve/Paths
            for i=1,3 do
                local parseid = struct.unpack("B", ext, (i * 2) + 0x05);
                local parseval = struct.unpack("B", ext, (i * 2) + 0x06);
                local finalVal = parseval + 1;
                local stringidBase = ashita.memory.read_uint16(memAddress.delveAugMap + (parseid * 2));

                local nonAttr = bit.band(stringidBase, 0x800) == 0;
                local stringid = 0;
                local petAug = false;
                if (nonAttr) then
                    stringid = bit.band(stringidBase, 0x7FF);
                else
                    stringid = bit.band(stringidBase, 0x7F);
                end

                if (stringid ~= 0) then
                    if (bit.rshift(stringidBase, 0xE) == 1 or bit.rshift(stringidBase, 0xE) == 2) then
                        petAug = true;
                    end

                    if ((parseid > 1 and parseid < 0x60) and (bit.band(parseid, 1) ~= 0)) then
                        finalVal = parseval + 0x101;
                    end
                    if (bit.band(bit.rshift(stringid, 0xC), 1) ~= 0) then
                        finalVal = finalVal * -1;
                    end

                    if (not nonAttr) then
                        local attrId = 0;
                        for m=1,7 do
                            local statOffset = m - 1;
                            if (bit.band(bit.lshift(1, statOffset), stringid) ~= 0) then
                                attrId = statOffset + 0xB;
                                break;
                            end
                        end
                        if (attrId > 0) then
                            stringid = attrId;
                        end
                    end

                    augs:insert({ id=stringid, val=finalVal, pet=petAug });
                end
            end
        elseif (bit.band(augFlag, 0x8) ~= 0) then
            -- Synth shield
        elseif (bit.band(augFlag, 0x80) ~= 0) then
            -- Evolith
            local evoData = T{}
            evoData[1] = bit.band(struct.unpack("B", ext, 9), 0xF); -- Aug Type (circle, triangle, etc)? :: Required to display augment
            evoData[2] = bit.band(struct.unpack("B", ext, 12), 0x7); -- Aug Element?
            evoData[3] = bit.rshift(struct.unpack("H", ext, 9), 12);
            evoData[4] = bit.rshift(struct.unpack("B", ext, 8), 4);
            evoData[5] = bit.band(bit.rshift(struct.unpack("H", ext, 11), 11), 0x7);
            evoData[6] = bit.band(struct.unpack("B", ext, 11), 0xF);
            evoData[7] = bit.band(struct.unpack("B", ext, 10), 0xF);
            evoData[8] = bit.rshift(struct.unpack("H", ext, 9), 14) + 4 * bit.rshift(struct.unpack("H", ext, 0x07), 15);
            evoData[9] = bit.rshift(struct.unpack("B", ext, 9), 4);

            for i=1,3 do
                local packedAug = struct.unpack("H", ext, (i * 2) + 1);
                local augId = bit.band(packedAug, 0x7FF);
                local augVal = bit.band(bit.rshift(packedAug, 11), 0xF);
                local arrIx = i + ((i - 1) * 2);
                local augType = evoData[arrIx];
                local augElement = evoData[arrIx + 1];
                local augUnk = evoData[arrIx + 2];
                if (augType ~= 0) then
                    if (augId ~= 0) then
                        local idOffset = 10 * augId;
                        local augCond = ashita.memory.read_uint16(memAddress.evoAugMap + idOffset * 2);
                        local augStat = ashita.memory.read_uint16(memAddress.evoAugMap + 2 + (idOffset * 2));
                        --Unknown: ashita.memory.read_uint16(memAddress.evoAugMap + 4 + (idOffset * 4) + augType);
                    end
                end
            end
        else
            -- Mission rewards, Magian, Skirmish, and Oseem
            local trialNum = 0;
            if (bit.band(augFlag, 0x40) ~= 0) then
                trialNum = struct.unpack("H", ext, 0x0B);
            end

            local numAugs = 5 - ((trialNum ~= 0) and 1 or 0);
            local outS = "";
            for ai=1,numAugs do
                local packedAug = struct.unpack("H", ext, 3 + ((ai - 1) * 2));
                local parseid = bit.band(packedAug, 0x7FF);
                local parseval = bit.rshift(packedAug, 0xB);
                local parsedAugs = T{};
                parsedAugs = ParseMiscAugs(memAddress, packedAug, parseid, parseval);
                for dai,daa in pairs(parsedAugs) do
                    augs:insert(daa);
                end
            end
        end
    elseif (augSys == 3 and augFlag > 127) then
        --Unity, Dynamis, and Odyssey
        local augVisible = struct.unpack("I", ext, 0x09);
        local augRank = bit.band(bit.rshift(struct.unpack("I", ext, 0x05), 18), 0x1F);
        if (augVisible ~= 0) then
            for ui=0,3 do
                local augCheck = ashita.memory.read_uint16(memAddress.unityAugMap + (2 * (ui + 6 * augVisible)) + 64);
                local mapOffset = memAddress.unityAugMap + (augCheck * 76) + 12352;
                local augVal = ashita.memory.read_int16(mapOffset + (2 * augRank) + 12);
                local augId = ashita.memory.read_uint16(mapOffset + 8);
                local petAug = false;
                ::GetUnityAug::
                if (augVal ~= 0) then
                    if (augId <= 2053) then
                        if (augId == 353) then
                            augs:insert({ id=53, val=(augVal * 10), pet=petAug });
                        elseif (augId == 2049) then
                            GetUnityAugSet({ 9, 10, 11, 12, 13, 14, 15, 16, 17 }, mapOffset, augVal, petAug, augs);
                        elseif (augId == 2050) then
                            local allAttrCheck = ashita.memory.read_uint16(mapOffset + 10);
                            if (allAttrCheck ~= 127) then
                                -- 2002 -> 2008
                                GetUnityAugSet({ 11, 12, 13, 14, 15, 16, 17 }, mapOffset, augVal, petAug, augs);
                            else
                                -- 2009
                                for stId=1,7 do
                                    augs:insert({ id=(stId + 10), val=augVal, pet=petAug });
                                end
                            end
                        elseif (augId == 2051) then
                            GetUnityAugSet({ 1, 2, 3, 4, 5, 6, 7, 8 }, mapOffset, augVal, petAug, augs);
                        elseif (augId == 2052) then
                            GetUnityAugSet({ 18, 20, 24 }, mapOffset, augVal, petAug, augs);
                        elseif (augId == 2053) then
                            GetUnityAugSet({ 19, 21, 133, 362 }, mapOffset, augVal, petAug, augs);
                        elseif (augId < 2048) then
                            augs:insert({ id=augId, val=augVal, pet=petAug });
                        end
                    elseif (augId <= 2056) then
                        if (augId == 2054) then
                            GetUnityAugSet({ 23, 134, 22, 25 }, mapOffset, augVal, petAug, augs);
                        elseif (augId == 2055) then
                            GetUnityAugSet({ 18, 20, 19, 133, 23 }, mapOffset, augVal, petAug, augs);
                        elseif (augId == 2056) then
                            GetUnityAugSet({ 24, 133, 362, 134, 25 }, mapOffset, augVal, petAug, augs);
                        end
                    elseif (augId == 2076) then
                        augs:insert({ id=47, val=augVal, pet=true });
                    elseif (augId == 4096) then
                        -- 2009
                        for stId=1,7 do
                            augs:insert({ id=(stId + 10), val=augVal, pet=petAug });
                        end
                    elseif (augId >= 2064 and augId <= 2075) then
                        augId = ashita.memory.read_uint16(mapOffset + 10);
                        petAug = true;
                        goto GetUnityAug;
                    end
                end
            end
        end
    end

    if (#augs > 0) then
        for i,v in pairs(augs) do
            for _ix,statDef in pairs(allStats) do
                local stIx = _ix;
                if ((stIx:find("pet") and v.pet) or (not stIx:find("pet") and not v.pet)) then
                    if (statDef.parent) then
                        stIx = statDef.parent;
                    end
                    if (statDef.augids) then
                        for aix,aid in ipairs(statDef.augids) do
                            if (v.id == aid) then
                                if (not stats.base[stIx]) then
                                    local rstring = AshitaCore:GetResourceManager():GetString("augments", v.id);
                                    local isPercent = rstring:find("%%%%") ~= nil;
                                    stats.base[stIx] = CreateNewStat(0, 0, isPercent, false);
                                end
                                stats.base[stIx].aug = stats.base[stIx].aug + v.val;
                            end
                        end
                    end
                end
            end
        end
    end
end

function ParseMiscAugs (memAddress, packedAug, parseid, parseval)
    local stringid, finalVal = parseid, parseval;
    local augs = T{};

    if (parseid == 0) then
        return augs;
    end

    if (parseid < 128) then
        finalVal = finalVal + 1;
        if (parseid <= 4) then
            augs:insert({ id=9, val=(bit.lshift(parseid, 5) - 32) + finalVal, pet=false });
        elseif (parseid <= 8) then
            augs:insert({ id=9, val=(5 - parseid) * 32 - finalVal, pet=false });
        elseif (parseid <= 12) then
            augs:insert({ id=10, val=(parseid - 9) * 32 + finalVal, pet=false });
        elseif (parseid <= 16) then
            augs:insert({ id=10, val=(13 - parseid) * 32 - finalVal, pet=false });
        elseif (parseid <= 18) then
            augs:insert({ id=9, val=(parseid - 17) * 32 + finalVal, pet=false });
            augs:insert({ id=10, val=(parseid - 17) * 32 + finalVal, pet=false });
        elseif (parseid <= 20) then
            augs:insert({ id=9, val=(parseid - 19) * 32 + finalVal, pet=false });
            augs:insert({ id=10, val=(19 - parseid) * 32 - finalVal, pet=false });
        elseif (parseid <= 22) then
            augs:insert({ id=9, val=(21 - parseid) * 32 - finalVal, pet=false });
            augs:insert({ id=10, val=(parseid - 21) * 32 + finalVal, pet=false });
        elseif (parseid <= 38) then
            stringid = 18 + math.floor((parseid - 23) / 2);
            if (bit.band(parseid, 1) == 0) then
                finalVal = finalVal * -1;
            end
            augs:insert({ id=stringid, val=finalVal, pet=false });
        elseif (parseid <= 40) then
            if (bit.band(parseid, 1) == 0) then
                finalVal = finalVal * -1;
            end
            augs:insert({ id=29, val=finalVal, pet=false });
        elseif (parseid <= 43) then
            augs:insert({ id=(parseid - 15), val=finalVal, pet=false });
        elseif (parseid == 44) then
            augs:insert({ id=142, val=finalVal, pet=false });
            augs:insert({ id=195, val=finalVal, pet=false });
        elseif (parseid <= 46) then
            if (bit.band(parseid, 1) == 0) then
                finalVal = finalVal * -1;
            end
            augs:insert({ id=30, val=finalVal, pet=false });
        elseif (parseid <= 48) then
            if (bit.band(parseid, 1) == 0) then
                finalVal = finalVal * -1;
            end
            augs:insert({ id=31, val=finalVal, pet=false });
        elseif (parseid <= 57) then
            if (parseid >= 53 and parseid <= 56) then
                finalVal = finalVal * -1;
            end
            augs:insert({ id=(parseid - 17), val=finalVal, pet=false });
        elseif (parseid == 58) then
            augs:insert({ id=41, val=(finalVal * -1), pet=false });
        elseif (parseid <= 61) then
            augs:insert({ id=(parseid - 11), val=finalVal, pet=false });
        elseif (parseid <= 66) then
            finalVal = finalVal + 32;
            if (parseid == 62) then
                stringid = 18;
            elseif (parseid == 63) then
                stringid = 20;
            elseif (parseid == 64) then
                stringid = 24;
            elseif (parseid == 65) then
                stringid = 19;
            elseif (parseid == 66) then
                stringid = 21;
            end
            augs:insert({ id=stringid, val=(finalVal + 32), pet=false });
        elseif (parseid == 67) then
            augs:insert({ id=51, val=finalVal, pet=false });
        elseif (parseid == 68) then
            augs:insert({ id=18, val=finalVal, pet=false });
            augs:insert({ id=19, val=finalVal, pet=false });
        elseif (parseid == 69) then
            augs:insert({ id=20, val=finalVal, pet=false });
            augs:insert({ id=21, val=finalVal, pet=false });
        elseif (parseid == 70) then
            augs:insert({ id=24, val=finalVal, pet=false });
            augs:insert({ id=133, val=finalVal, pet=false });
        elseif (parseid == 71) then
            augs:insert({ id=41, val=finalVal, pet=false });
        elseif (parseid == 72) then
            augs:insert({ id=1280, val=finalVal, pet=false });
        elseif (parseid == 73) then
            augs:insert({ id=1280, val=(finalVal + 32), pet=false });
        elseif (parseid == 74) then
            augs:insert({ id=1281, val=finalVal, pet=false });
        elseif (parseid == 75) then
            augs:insert({ id=1281, val=(finalVal + 32), pet=false });
        elseif (parseid == 76) then
            augs:insert({ id=30, val=(finalVal + 32), pet=false });
        elseif (parseid == 77) then
            augs:insert({ id=31, val=((finalVal + 32) * -1), pet=false });
        elseif (parseid <= 79) then
            if (bit.band(parseid, 1) == 0) then
                finalVal = finalVal * 2;
            else
                finalVal = finalVal * 3;
            end
            augs:insert({ id=9, val=finalVal, pet=false });
        elseif (parseid == 80) then
            augs:insert({ id=24, val=finalVal, pet=false });
            augs:insert({ id=362, val=finalVal, pet=false });
        elseif (parseid == 81) then
            augs:insert({ id=22, val=finalVal, pet=false });
            augs:insert({ id=25, val=finalVal, pet=false });
        elseif (parseid <= 83) then
            if (bit.band(parseid, 1) == 0) then
                finalVal = finalVal * 2;
            else
                finalVal = finalVal * 3;
            end
            augs:insert({ id=10, val=finalVal, pet=false });
        elseif (parseid == 96 or parseid == 106) then
            augs:insert({ id=18, val=finalVal, pet=true });
            augs:insert({ id=20, val=finalVal, pet=true });
        elseif (parseid == 97 or parseid == 107) then
            augs:insert({ id=19, val=finalVal, pet=true });
            augs:insert({ id=21, val=finalVal, pet=true });
        elseif (parseid == 98) then
            augs:insert({ id=22, val=finalVal, pet=true });
        elseif (parseid == 99) then
            augs:insert({ id=23, val=finalVal, pet=true });
        elseif (parseid == 100) then
            augs:insert({ id=24, val=finalVal, pet=true });
        elseif (parseid == 101) then
            augs:insert({ id=133, val=finalVal, pet=true });
        elseif (parseid == 102) then
            augs:insert({ id=26, val=finalVal, pet=true });
        elseif (parseid == 103) then
            augs:insert({ id=27, val=(finalVal * -1), pet=true });
        elseif (parseid == 104) then
            augs:insert({ id=28, val=finalVal, pet=true });
        elseif (parseid == 105) then
            augs:insert({ id=28, val=(finalVal * -1), pet=true });
        elseif (parseid == 108) then
            augs:insert({ id=24, val=finalVal, pet=true });
            augs:insert({ id=133, val=finalVal, pet=true });
        elseif (parseid == 109) then
            augs:insert({ id=143, val=finalVal, pet=true });
            augs:insert({ id=26, val=finalVal, pet=true });
        elseif (parseid == 110) then
            augs:insert({ id=137, val=finalVal, pet=true });
        elseif (parseid == 111) then
            augs:insert({ id=32, val=finalVal, pet=true });
        elseif (parseid == 112) then
            augs:insert({ id=41, val=(finalVal * -1), pet=true });
        elseif (parseid == 113) then
            augs:insert({ id=20, val=finalVal, pet=true });
        elseif (parseid == 114) then
            augs:insert({ id=21, val=finalVal, pet=true });
        elseif (parseid == 115) then
            augs:insert({ id=142, val=finalVal, pet=true });
        elseif (parseid == 116) then
            augs:insert({ id=195, val=finalVal, pet=true });
        elseif (parseid == 117) then
            augs:insert({ id=25, val=finalVal, pet=true });
        elseif (parseid == 118) then
            augs:insert({ id=37, val=(finalVal * -1), pet=true });
        elseif (parseid == 119) then
            augs:insert({ id=134, val=finalVal, pet=true });
        elseif (parseid == 120) then
            augs:insert({ id=133, val=finalVal, pet=true });
        elseif (parseid == 121) then
            augs:insert({ id=52, val=finalVal, pet=true });
        elseif (parseid == 122) then
            augs:insert({ id=53, val=(finalVal * 20), pet=true });
        elseif (parseid == 123) then
            augs:insert({ id=143, val=finalVal, pet=true });
        elseif (parseid == 124) then
            augs:insert({ id=18, val=finalVal, pet=true });
            augs:insert({ id=20, val=finalVal, pet=true });
            augs:insert({ id=19, val=finalVal, pet=true });
            augs:insert({ id=21, val=finalVal, pet=true });
        elseif (parseid == 125) then
            augs:insert({ id=24, val=finalVal, pet=true });
            augs:insert({ id=362, val=finalVal, pet=true });
        elseif (parseid == 126) then
            augs:insert({ id=362, val=finalVal, pet=true });
        elseif (parseid == 127) then
            augs:insert({ id=38, val=(finalVal * -1), pet=true });
        elseif (finalVal > 0) then
            augs:insert({ id=parseid, val=finalVal, pet=false });
        end
        goto FoundAugIds;
    elseif (parseid > 255) then
        if (parseid <= 319) then
            stringid = stringid - 1;
            finalVal = finalVal + 1;
            augs:insert({ id=stringid, val=finalVal, pet=false });
            goto FoundAugIds;
        end
        if (parseid <= 383) then
            finalVal = finalVal + 1;
            if (parseid == 339) then
                finalVal = 5 * finalVal;
            elseif (parseid == 342 or parseid == 360) then
                finalVal = 10 * finalVal;
            elseif (parseid == 353) then
                finalVal = 50 * finalVal;
            end

            augs:insert({ id=stringid, val=finalVal, pet=false });
            goto FoundAugIds;
        end
        if (parseid < 512 or parseid > 639) then
            if (parseid < 640 or parseid > 703) then
                if (parseid >= 740 and parseid <= 767) then
                    finalVal = finalVal + 1;
                    if (parseid >= 744) then
                        if (parseid >= 746) then
                            if (parseid >= 750) then
                                if (parseid >= 752) then
                                    if (parseid >= 756) then
                                        if (parseid >= 760) then
                                            if (parseid >= 764) then
                                                finalVal = 32 * (764 - parseid) - finalVal;
                                                augs:insert({ id=46, val=finalVal, pet=false });
                                            else
                                                finalVal = finalVal + 32 * (parseid - 760);
                                                augs:insert({ id=46, val=finalVal, pet=false });
                                            end
                                        else
                                            finalVal = 32 * (756 - parseid) - finalVal;
                                            augs:insert({ id=46, val=finalVal, pet=false });
                                        end
                                    else
                                        finalVal = finalVal + 32 * (parseid - 752);
                                        augs:insert({ id=46, val=finalVal, pet=false });
                                    end
                                else
                                    finalVal = 32 * (750 - parseid) - finalVal;
                                    augs:insert({ id=30, val=finalVal, pet=false });
                                end
                            else
                                finalVal = finalVal + 32 * (parseid - 746);
                                augs:insert({ id=30, val=finalVal, pet=false });
                            end
                        else
                            finalVal = 32 * (744 - parseid) - finalVal;
                            augs:insert({ id=30, val=finalVal, pet=false });
                        end
                    else
                        finalVal = finalVal + 32 * (parseid - 740);
                        augs:insert({ id=30, val=finalVal, pet=false });
                    end
                    goto FoundAugIds;
                end
                if (parseid < 768 or parseid > 831) then
                    if (parseid >= 832 and parseid <= 839) then
                        if (packedAug >= 0x4000) then
                            stringid = parseid - 383;
                            finalVal = finalVal + 5;
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            goto FoundAugIds;
                        end
                    end
                    if (parseid >= 840 and parseid <= 857) then
                        if (packedAug >= 0x4000) then
                            stringid = parseid - 383;
                            finalVal = finalVal + 1;
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            goto FoundAugIds;
                        end
                    end
                    if (parseid < 896 or parseid > 911) then
                        if (parseid >= 912 and parseid <= 914) then
                            stringid = finalVal + 16 * (parseid - 878);
                            finalVal = 1;
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            goto FoundAugIds;
                        end
                        if (parseid >= 928 and parseid <= 951) then
                            stringid = parseid - 336;
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            goto FoundAugIds;
                        end
                        if (parseid >= 952 and parseid <= 959) then
                            stringid = stringid - 336;
                            finalVal = finalVal + 1;
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                        end
                        if (parseid >= 960 and parseid <= 975) then
                            stringid = parseid - 360;
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            stringid = parseid - 336;
                            finalVal = 2 * finalVal + 2;
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            goto FoundAugIds;
                        end
                        if (parseid >= 976 and parseid <= 983) then
                            stringid = parseid - 208;
                            finalVal = finalVal + 1;
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            goto FoundAugIds;
                        end
                        if ((parseid >= 984 and parseid <= 991) or (parseid >= 992 and parseid <= 999)) then
                            stringid = parseid - 360;
                            finalVal = 2 * finalVal + 2;
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            goto FoundAugIds;
                        end
                        if (parseid >= 1000 and parseid <= 1007) then
                            -- Dual augment string
                            stringid = parseid - 400;
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            stringid = parseid - 368;
                            finalVal = 2 * (3 * finalVal + 3);
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            goto FoundAugIds;
                        end
                        if (parseid >= 1008 and parseid <= 1015) then
                            -- Dual augment string
                            stringid = parseid - 400;
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            stringid = parseid - 384;
                            finalVal = 2 * (3 * finalVal + 3);
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            goto FoundAugIds;
                        end
                        if (parseid < 1024 or parseid > 1151) then
                            if (parseid < 1536 or parseid > 1663) then
                                if (parseid >= 1152 and parseid <= 1247) then
                                    -- Resuses mapping from < 127; Calculation is pulled from mapping array
                                    local idOffset = (4 * parseid) - 4608;
                                    stringid = ashita.memory.read_uint16(memAddress.augCalcMap + idOffset);
                                    local nAugs = ParseMiscAugs(memAddress, packedAug, stringid, parseval);
                                    for pi, pa in pairs(nAugs) do
                                        finalVal = pa.val * ashita.memory.read_int16(memAddress.augCalcMap + idOffset + 2);
                                        augs:insert({ id=pa.id, val=finalVal, pet=pa.pet });
                                    end
                                    goto FoundAugIds;
                                end
                                if (parseid >= 1248) then
                                    if (parseid < 1264) then
                                        finalVal = finalVal + 1;
                                        augs:insert({ id=stringid, val=finalVal, pet=false });
                                        goto FoundAugIds;
                                    end
                                    if (parseid < 1280) then
                                        finalVal = finalVal + 1;
                                        augs:insert({ id=stringid, val=finalVal, pet=false });
                                        goto FoundAugIds;
                                    end
                                    if (parseid <= 1303) then
                                        stringid = parseid - 480;
                                        finalVal = finalVal + 1;
                                        augs:insert({ id=stringid, val=finalVal, pet=false });
                                        goto FoundAugIds;
                                    end
                                end
                                if (parseid >= 1328 and parseid <= 1471) then
                                    stringid = parseid - 480;
                                    finalVal = finalVal + 1;
                                    augs:insert({ id=stringid, val=finalVal, pet=false });
                                    goto FoundAugIds;
                                end
                                if (parseid == 1472) then
                                    stringid = 54;
                                    finalVal = finalVal + 1;
                                    augs:insert({ id=stringid, val=finalVal, pet=false });
                                    goto FoundAugIds;
                                end
                                if (parseid < 1664 or parseid > 1680) then
                                    if (parseid < 1792 or parseid > 1823) then
                                        if (parseid == 2047) then
                                            stringid = 2046;
                                            finalVal = 1;
                                            augs:insert({ id=stringid, val=finalVal, pet=false });
                                            goto FoundAugIds;
                                        end
                                    else
                                        stringid = parseid - 1792;
                                        finalVal = finalVal + 1;
            
                                        if (stringid >= 14 and stringid <= 31) then
                                            if (bit.band(finalVal, 0x80000001) ~= 0) then
                                                finalVal = bit.rshift(finalVal, 1) + 1;
                                            else
                                                finalVal = bit.rshift(finalVal);
                                            end

                                            if (finalVal == 0) then
                                                finalVal = 1;
                                            end
                                        end

                                        local tempStats = T{
                                            { id=11, val=0 },
                                            { id=12, val=0 },
                                            { id=13, val=0 },
                                            { id=14, val=0 },
                                            { id=15, val=0 },
                                            { id=16, val=0 },
                                            { id=17, val=0 },
                                        }

                                        for i=1,7 do
                                            local fCheck = bit.lshift(1, i - 1);
                                            local statMapCheck1 = ashita.memory.read_uint8(memAddress.statCalcMap + (stringid * 2) + 0x100);
                                            local statMapCheck2 = ashita.memory.read_uint8(memAddress.statCalcMap + (stringid * 2) + 0x101);
                                            if (bit.band(statMapCheck1, fCheck) ~= 0) then
                                                tempStats[i].val = tempStats[i].val + finalVal;
                                            end
                                            if (bit.band(fCheck, statMapCheck2) ~= 0) then
                                                tempStats[i].val = tempStats[i].val - finalVal;
                                            end
                                        end

                                        for si,st in pairs(tempStats) do
                                            if (st.val ~= 0) then
                                                augs:insert({ id=st.id, val=st.val, pet=true });
                                            end
                                        end
                                        goto FoundAugIds;
                                    end
                                else
                                    -- Equipment signifiers
                                    -- 1664 - 1680; IE Main hand, sub, ranged, etc
                                    stringid = stringid - 1;
                                    goto FoundAugIds;
                                end
                            else
                                -- Weaponskill DMG+ augments
                                stringid = (parseid - 1536) + 640;
                                finalVal = (finalVal + 1) * 5;
                                augs:insert({ id=stringid, val=finalVal, pet=false });
                                goto FoundAugIds;
                            end
                        else
                            -- Repeat of Weaponskill DMG+ Augments
                            stringid = (parseid - 1024) + 640;
                            finalVal = (finalVal + 1) * 5;
                            augs:insert({ id=stringid, val=finalVal, pet=false });
                            goto FoundAugIds;
                        end
                    elseif (packedAug >= 0x4000) then
                        stringid = parseid - 384;
                        finalVal = finalVal + 1;
                        augs:insert({ id=stringid, val=finalVal, pet=false });
                        goto FoundAugIds;
                    end
                else
                    -- Resistances
                    stringid = parseid - 768;
                    finalVal = finalVal + 1;

                    local tempStats = T{
                        { id=1, val=0 },
                        { id=2, val=0 },
                        { id=3, val=0 },
                        { id=4, val=0 },
                        { id=5, val=0 },
                        { id=6, val=0 },
                        { id=7, val=0 },
                        { id=8, val=0 },
                    }
        
                    for i=1,8 do
                        local fCheck = bit.lshift(1, i - 1);
                        local statMapCheck1 = ashita.memory.read_uint8(memAddress.statCalcMap + (stringid * 2) + 320);
                        local statMapCheck2 = ashita.memory.read_uint8(memAddress.statCalcMap + (stringid * 2) + 321);
                        if (bit.band(statMapCheck1, fCheck) ~= 0) then
                            tempStats[i].val = tempStats[i].val + finalVal;
                        end
                        if (bit.band(fCheck, statMapCheck2) ~= 0) then
                            tempStats[i].val = tempStats[i].val - finalVal;
                        end
                    end
        
                    for si,st in pairs(tempStats) do
                        if (st.val ~= 0) then
                            augs:insert({ id=st.id, val=st.val, pet=false });
                        end
                    end

                    goto FoundAugIds;
                end
            else
                -- Memory map only has values for 640, otherwise all set to 0; Revisit if implemented
                --stringid = (parseid * 4) - 2560;
                stringid = 145;
                finalVal = (finalVal + 1) * 2
                augs:insert({ id=stringid, val=finalVal, pet=false });
                goto FoundAugIds;
            end
        else
            -- Stats
            stringid = parseid - 512;
            finalVal = finalVal + 1;
            
            if (stringid >= 14 and stringid <= 37) then
                if (bit.band(finalVal, 0x80000001) ~= 0) then
                    finalVal = bit.rshift(finalVal, 1) + 1;
                else
                    finalVal = bit.rshift(finalVal);
                end

                if (finalVal == 0) then
                    finalVal = 1;
                end
            end

            local tempStats = T{
                { id=11, val=0 },
                { id=12, val=0 },
                { id=13, val=0 },
                { id=14, val=0 },
                { id=15, val=0 },
                { id=16, val=0 },
                { id=17, val=0 },
            }

            for i=1,7 do
                local fCheck = bit.lshift(1, i - 1);
                local statMapCheck1 = ashita.memory.read_uint8(memAddress.statCalcMap + (stringid * 2));
                local statMapCheck2 = ashita.memory.read_uint8(memAddress.statCalcMap + (stringid * 2) + 1);
                if (bit.band(statMapCheck1, fCheck) ~= 0) then
                    tempStats[i].val = tempStats[i].val + finalVal;
                end
                if (bit.band(fCheck, statMapCheck2) ~= 0) then
                    tempStats[i].val = tempStats[i].val - finalVal;
                end
            end

            for si,st in pairs(tempStats) do
                if (st.val ~= 0) then
                    augs:insert({ id=st.id, val=st.val, pet=false });
                end
            end

            goto FoundAugIds;
        end
    else
        augs:insert({ id=stringid, val=finalVal + 1, pet=false });
    end

    ::FoundAugIds::
    return augs;
end

function GetUnityAugSet(augSet, mapOffset, augVal, petAug, augs)
    local offsetVal = ashita.memory.read_int16(mapOffset + 10);

    for i=1,#augSet do
        if ((bit.band(bit.lshift(1, (i - 1)), offsetVal)) ~= 0) then
            augs:insert({ id=augSet[i], val=augVal, pet=petAug });
        end
    end

    return augs;
end
function DrawGUI(imgui, uiConfig, ffi, gearGlobals, allStats, rtGlobals, memAddress)
    imgui.PushStyleColor(ImGuiCol_TitleBg, uiConfig.style.colTitleBg);
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, uiConfig.style.colTitleBgActive);
    imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, uiConfig.style.colTitleBgCollapsed);
    -- Main Menu --
    local windowFlag = 0;
    if (uiConfig.selecting_gear[1]) then
        windowFlag = ImGuiWindowFlags_NoBringToFrontOnFocus;
    end
    imgui.SetNextWindowSizeConstraints({ 540, 500 }, { 9999, 9999 });
    if (uiConfig.is_open[1] and imgui.Begin(("GearFinder-v%s##Main_Window"):fmt(addon.version), uiConfig.is_open, windowFlag or ImGuiWindowFlags_AlwaysAutoResize)) then
        local winX, winY = imgui.GetWindowPos();
        uiConfig.main_pos = { winX, winY };
        imgui.PushStyleColor(ImGuiCol_Button, uiConfig.style.colTitleBgActive);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, uiConfig.style.colTitleBgCollapsed);
        if (imgui.Button("Rebuild Cache") and rtGlobals.cAction == rtGlobals.actions.idle) then
            CacheGear();
        end
        imgui.SameLine();
        if (imgui.Button("Get Equipped") and #gearGlobals.gearCache > 0) then
            SetEquippedToWorking();
        end
        -- TODO
        -- imgui.SameLine();
        -- if (imgui.Button("Save Set")) then
            
        -- end
        imgui.SameLine();
        if (imgui.Button("Clear Set")) then
            for i=1,#gearGlobals.workingSet do
                SetWorkingSlot(i, nil);
            end
        end
        imgui.SameLine();
        local equipDisabled = gearGlobals.equipDelay > 0;
        if (not equipDisabled and imgui.Button("Equip Working Set")) then
            SendEquipsetPacket(gearGlobals, memAddress);
        elseif (equipDisabled) then
            imgui.PushStyleColor(ImGuiCol_Button, { 0.5, 0.5, 0.5, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.5, 0.5, 0.5, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.5, 0.5, 0.5, 1.0 });
            imgui.Button("Equip Working Set");
            imgui.PopStyleColor(3);
        end
        imgui.SameLine();
        imgui.Text("Gear cached: " .. #gearGlobals.gearCache);
        imgui.PopStyleColor(2);

        imgui.BeginGroup();
            -- TODO
            -- imgui.Text("Sets:");
            -- imgui.SameLine();
            -- imgui.SetNextItemWidth(173);
            -- if (imgui.BeginCombo("##" .. addon.name .. "_set_selection", "None")) then

            --     imgui.EndCombo();
            -- end
            imgui.PushStyleColor(ImGuiCol_Button, uiConfig.style.colEquipButton);
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, uiConfig.style.colEquipButtonHovered);
            imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 2);
            local avgItemLevel = 0;
            local jobLevel = AshitaCore:GetMemoryManager():GetPlayer():GetMainJobLevel();
            for eix,eit in pairs(gearGlobals.workingSet) do
                if (eit.item.id) then
                    local resItem = GetResCacheItemById(eit.item.id, gearGlobals);
                    if (resItem) then
                        if (eit.equipStatus ~= nil and eit.equipStatus == false) then
                            imgui.PushStyleColor(ImGuiCol_Button, uiConfig.style.colError);
                        end
                        if (imgui.ImageButton(tonumber(ffi.cast("uint32_t", eit.texture)), { 40, 42 })) then
                            if (uiConfig.select_slot == eit.slot and uiConfig.selecting_gear[1]) then
                                uiConfig.selecting_gear[1] = false;
                            else
                                uiConfig.selecting_gear[1] = true;
                            end
                            local cursorPosX, cursorPosY = imgui.GetCursorScreenPos();
                            local xOffset = eix % 4 ~= 0 and eix % 4 or 4;
                            uiConfig.select_pos_offset = { cursorPosX - uiConfig.main_pos[1] + ((xOffset - 1) * 56), cursorPosY - uiConfig.main_pos[2] };
                            uiConfig.select_slot = eit.slot;
                            uiConfig.select_set_index = eix;
                        end
                        if (imgui.IsItemHovered()) then
                            if (gearGlobals.hoveredTooltip.item ~= eit.item) then
                                gearGlobals.hoveredTooltip.item = eit.item;
                                gearGlobals.hoveredTooltip.text = GetItemTooltip(eit.item, gearGlobals, allStats, uiConfig);
                            end
                            imgui.BeginTooltip();
                                imgui.Text(("%s\n - %s"):format(resItem.name, GetInventoryBagName(eit.item.bag + 1)));
                                imgui.Text(gearGlobals.hoveredTooltip.text);
                            imgui.EndTooltip();
                        end
                        local realilvl = resItem.ilvl;
                        if (realilvl > 0) then
                            if (realilvl > 119) then
                                realilvl = 119;
                            end
                            if (eit.slot >= 4 and eit.slot <= 8) then
                                avgItemLevel = math.floor(avgItemLevel + ((realilvl - jobLevel) / 10));
                            elseif (eit.slot == 0) then
                                avgItemLevel = math.floor(avgItemLevel + ((realilvl - jobLevel) / 2));
                            end
                        end
                        if (eit.equipStatus ~= nil and eit.equipStatus == false) then
                            imgui.PopStyleColor(1);
                        end
                    end
                else
                    if (imgui.Button(eit.name, { 48, 48 })) then
                        if (uiConfig.select_slot == eit.slot and uiConfig.selecting_gear[1]) then
                            uiConfig.selecting_gear[1] = false;
                        else
                            uiConfig.selecting_gear[1] = true;
                        end
                        local cursorPosX, cursorPosY = imgui.GetCursorScreenPos();
                        local xOffset = eix % 4 ~= 0 and eix % 4 or 4;
                        uiConfig.select_pos_offset = { cursorPosX - uiConfig.main_pos[1] + ((xOffset - 1) * 56), cursorPosY - uiConfig.main_pos[2] };
                        uiConfig.select_slot = eit.slot;
                        uiConfig.select_set_index = eix;
                    end
                end

                if ((eix) % 4 ~= 0) then
                    imgui.SameLine();
                end
            end
            
            if (avgItemLevel > 0) then
                imgui.Text("ILvl: " .. avgItemLevel + jobLevel);
            else
                imgui.Text("ILvl: ---");
            end

            imgui.PopStyleColor(2);
            imgui.PopStyleVar(1);

            imgui.Text("Filters:");
            if (imgui.Button("Add")) then
                gearGlobals.searchFilters:insert({ stat="none", statKey=nil, val=T{}, op=1 });
            end
            imgui.SameLine();
            if (imgui.Button("Clear")) then
                gearGlobals.searchFilters = T{};
            end
            -- TODO
            -- imgui.SameLine();
            -- if (imgui.Button("Generate Set")) then
                
            -- end
            imgui.BeginChild(addon.name .. "_search_filters", { 225, -1 }, true);
                for i,v in pairs(gearGlobals.searchFilters) do
                    imgui.SetNextItemWidth(70);
                    if (imgui.BeginCombo("##filter_stat_" .. i, v.stat, ImGuiComboFlags_NoArrowButton)) then
                        if (imgui.Selectable("none##_op_" .. i)) then
                            v.stat = "none";
                            v.statKey = nil;
                        end
                        if (imgui.Selectable("Level##_op_" .. i)) then
                            v.stat = "Level";
                            v.statKey = "ILevel";
                        end
                        for _,cat in pairs(gearGlobals.orderedStats) do
                            for k,stIx in pairs(cat.stats) do
                                local dispName = allStats[stIx].name;
                                if (stIx:contains("pet")) then
                                    dispName = "Pet: " .. dispName;
                                end
                                if (imgui.Selectable(dispName .. "##_stat_" .. i)) then
                                    v.stat = dispName;
                                    v.statKey = stIx;
                                end
                            end
                        end
                        imgui.EndCombo();
                    end
                    imgui.SameLine();
                    imgui.SetNextItemWidth(50);
                    if (imgui.BeginCombo("##filter_op" .. i, uiConfig.filterOps[v.op], ImGuiComboFlags_NoArrowButton)) then
                        for k,oper in ipairs(uiConfig.filterOps) do
                            if (imgui.Selectable(oper .. "##_op_" .. i)) then
                                v.op = k;
                            end
                        end
                        imgui.EndCombo();
                    end
                    imgui.SameLine();
                    imgui.SetNextItemWidth(70);
                    imgui.InputText("##filter_val" .. i, v.val, 5);
                end
            imgui.EndChild();
        imgui.EndGroup();

        imgui.SameLine();
        imgui.BeginGroup();
            imgui.Text("Gear Stat Overview:");
            imgui.BeginChild(addon.name .. "_stat_overview", { -1, -1 }, true);
                for i,v in ipairs(gearGlobals.orderedStats) do
                    if (v.visible and imgui.CollapsingHeader(v.category, ImGuiTreeNodeFlags_DefaultOpen)) then
                        for _,sIx in ipairs(v.stats) do
                            if (gearGlobals.workingStats[sIx]) then
                                local sdata = gearGlobals.workingStats[sIx];
                                local oper = "";
                                local stTotal = sdata.base + sdata.min + sdata.aug + sdata.convertDiff;
                                if (stTotal > 0) then
                                    oper = "+";
                                end
                                local outS = "";
                                if (sIx == "wtype") then
                                    local winfo = GetWeaponTypeInfo(sdata.base);
                                    outS = ("%s: %s (%s)"):format(allStats[sIx].longName, winfo[1], winfo[2]);
                                else
                                    local useName = allStats[sIx].longName;
                                    if (allStats[sIx].category:find("Attributes")) then
                                        useName = allStats[sIx].name;
                                    end
                                    
                                    if (sdata.min ~= 0) then
                                        outS = ("%s: %s%d ~ %d"):format(useName, oper, stTotal, (stTotal - sdata.min) + sdata.max);
                                    else
                                        outS = ("%s: %s%d"):format(useName, oper, stTotal);
                                    end
                                end
                                if (sdata.percent) then
                                    outS = outS .. "%%";
                                end
                                imgui.Text(outS);
                                local helpText = ("Base: %d, Augmented: %d"):format(sdata.base, sdata.aug);
                                if (sdata.min ~= 0) then
                                    helpText = ("%s, Min: %d, Max: %d"):format(helpText, sdata.min, sdata.max);
                                end
                                if (sdata.convertDiff ~= 0) then
                                    helpText = ("%s, Convert: %d"):format(helpText, sdata.convertDiff);
                                end
                                if (allStats[sIx].desc ~= "") then
                                    helpText = allStats[sIx].desc .. "\n" .. helpText;
                                end
                                imgui.ShowHelp(helpText);
                                if (sIx == "shsize") then
                                    local shieldData = GetShieldStats(sdata.base);
                                    if (shieldData) then
                                        imgui.Text("Base Damage Reduction: " .. shieldData[1] .. "%%");
                                        imgui.Text("Base Block Rate: " .. shieldData[2] .. "%%");
                                    end
                                end
                            end
                        end
                    end
                end
            imgui.EndChild();
        imgui.EndGroup();
    end

    -- Gear selection dropdown
    if (uiConfig.selecting_gear[1]) then
        local winX = uiConfig.main_pos[1] + uiConfig.select_pos_offset[1];
        local winY = uiConfig.main_pos[2] + uiConfig.select_pos_offset[2];
        imgui.SetNextWindowPos({ winX, winY });
        imgui.SetNextWindowSizeConstraints({ 192, 160 }, { 9999, 9999 });
        if (imgui.Begin("##slot_select" .. addon.name, uiConfig.selecting_gear, ImGuiWindowFlags_NoTitleBar or ImGuiWindowFlags_NoSavedSettings)) then
            if (imgui.Selectable(uiConfig.awfont_icons.trashcan .. " Clear Slot")) then
                SetWorkingSlot(uiConfig.select_set_index, nil);
            end
            imgui.BeginChild(addon.name .. "_selectable_gear_list", { -1, -1 }, false);
                local currJob = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob();
                local currBag = -1;
                for _,item in pairs(gearGlobals.gearCache) do
                    local checkSlot = bit.lshift(1, uiConfig.select_slot);
                    local checkJob = bit.lshift(1, currJob);
                    local resItem = GetResCacheItemById(item.id, gearGlobals);
                    if (resItem and bit.band(checkSlot, resItem.equipSlots) ~= 0 and bit.band(checkJob, resItem.jobs) ~= 0) then
                        local allMatched = true;
                        if (#gearGlobals.searchFilters > 0) then
                            for __,filter in pairs(gearGlobals.searchFilters) do
                                if (filter.statKey and filter.statKey:sub(1,1) == "I") then
                                    if (filter.statKey == "ILevel") then
                                        if ((filter.op == 1 and resItem.lvl == tonumber(filter.val:concat())) or (filter.op == 2 and resItem.lvl ~= tonumber(filter.val:concat())) or
                                        (filter.op == 3 and resItem.lvl < tonumber(filter.val:concat())) or (filter.op == 4 and resItem.lvl <= tonumber(filter.val:concat())) or
                                        (filter.op == 5 and resItem.lvl > tonumber(filter.val:concat())) or (filter.op == 6 and resItem.lvl >= tonumber(filter.val:concat()))) then
                                            -- Matched; Good job
                                        else
                                            allMatched = false;
                                        end
                                    end
                                elseif (filter.statKey and filter.statKey:sub(1) ~= "I" and filter.stat ~= "none") then
                                    local stTotal = GetStatTotal(item, resItem, filter.statKey);
                                    if ((filter.op == 1 and stTotal == tonumber(filter.val:concat())) or (filter.op == 2 and stTotal ~= tonumber(filter.val:concat())) or
                                    (filter.op == 3 and stTotal < tonumber(filter.val:concat())) or (filter.op == 4 and stTotal <= tonumber(filter.val:concat())) or
                                    (filter.op == 5 and stTotal > tonumber(filter.val:concat())) or (filter.op == 6 and stTotal >= tonumber(filter.val:concat()))) then
                                        -- Matched; good job
                                    else
                                        allMatched = false;
                                    end
                                end
                            end
                        end

                        if (allMatched) then
                            if (item.bag ~= currBag) then
                                currBag = item.bag;
                                imgui.TextColored(uiConfig.style.colListLabel, "-" .. GetInventoryBagName(currBag + 1) .. "-");
                            end
                            local selectLabel = ("%s##%d%d"):format(resItem.name, item.bag, item.slot);
                            local selected = gearGlobals.workingSet[uiConfig.select_set_index].item == item;
                            local selectFlag = 0;
                            if (item.working) then
                                selectFlag = ImGuiSelectableFlags_Disabled;
                            end
                            if (selected) then
                                imgui.PushStyleColor(ImGuiCol_TextDisabled, uiConfig.style.colListActive);
                            end
                            if (imgui.Selectable(selectLabel, false, selectFlag)) then
                                SetWorkingSlot(uiConfig.select_set_index, item);
                            end
                            if (imgui.IsItemHovered()) then
                                if (gearGlobals.hoveredTooltip.item ~= item) then
                                    gearGlobals.hoveredTooltip.item = item;
                                    gearGlobals.hoveredTooltip.text = GetItemTooltip(item, gearGlobals, allStats, uiConfig);
                                end
                                imgui.BeginTooltip();
                                    imgui.Text(gearGlobals.hoveredTooltip.text);
                                imgui.EndTooltip();
                            end
                            if (selected) then
                                imgui.PopStyleColor(1);
                            end
                        end
                    end
                end
            imgui.EndChild();

            if (not imgui.IsWindowFocused(ImGuiFocusedFlags_ChildWindows)) then
                uiConfig.selecting_gear[1] = false;
            end
        end
    end


    -- Status popup
    if((#rtGlobals.routines > 0 and rtGlobals.cAction > rtGlobals.actions.idle)) then
        imgui.PushStyleColor(ImGuiCol_PlotHistogram, uiConfig.style.colProgressBar);
        local rect = (AshitaCore:GetProperties():GetFinalFantasyRect());
        imgui.SetNextWindowPos({ rect.right / 2, rect.bottom / 2 });
        -- Progress / Loading Bar --    
        imgui.SetNextWindowSize({ 150, 50 });
        if (imgui.Begin(("ToBeNamed##v%s - Progress Bar"):fmt(addon.version), true, ImGuiWindowFlags_NoDecoration or ImGuiWindowFlags_NoSavedSettings)) then
            imgui.SetWindowFocus();
            if (rtGlobals.cAction == rtGlobals.actions.caching) then
                imgui.Text("Caching items...");
            end

            local totalFinished = 0;
            for i=1,#rtGlobals.routines do
                if (coroutine.status(rtGlobals.routines[i]) == "dead") then
                    totalFinished = totalFinished + 1;
                end
            end
            imgui.ProgressBar((totalFinished / #rtGlobals.routines));
        end
        imgui.PopStyleColor(1);
    end
    imgui.PopStyleColor(3);
end
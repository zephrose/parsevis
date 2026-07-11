local action_parse = {}

local packets = require('packets')
local res = require('resources')

local combat_events = {}

local offense_action_messages = {
	[1] = 'melee', [67] = 'crit', [15] = 'miss', [63] = 'miss',
	[352] = 'ranged', [576] = 'ranged', [577] = 'ranged',
	[353] = 'r_crit', [354] = 'r_miss',
	[185] = 'ws', [197] = 'ws', [187] = 'ws', [188] = 'ws_miss',
	[2] = 'spell', [227] = 'spell',
	[252] = 'mb', [265] = 'mb', [274] = 'mb', [379] = 'mb', [747] = 'mb', [748] = 'mb',
	[110] = 'ja', [317] = 'ja', [522] = 'ja', [802] = 'ja',
	[157] = 'Barrage',
	[77] = 'Sange',
	[264] = 'aoe'
}

local heal_messages = {
    [7] = 'cure', [24] = 'cure', [266] = 'cure', [306] = 'cure', [318] = 'cure', [673] = 'cure',
    [23] = 'ja_cure', [102] = 'ja_cure'
}

local add_effect_messages = {
    [161] = true, [163] = true, [229] = true,
    [288]=true, [289]=true, [290]=true, [291]=true, [292]=true, [293]=true, [294]=true, [295]=true,
    [296]=true, [297]=true, [298]=true, [299]=true, [300]=true, [301]=true, [302]=true, [385]=true,
    [386]=true, [387]=true, [388]=true, [389]=true, [390]=true, [391]=true, [392]=true, [393]=true,
    [394]=true, [395]=true, [396]=true, [397]=true, [398]=true, [732]=true, [767]=true, [768]=true,
    [769]=true, [770]=true
}

local add_effect_valid = {
    [1] = true, [2] = true, [3] = true, [4] = true, [11] = true, [13] = true
}

local function get_player_info(id)
    local mob = windower.ffxi.get_mob_by_id(id)
    if not mob then return nil end
    
    local is_party_or_alliance = false
    local is_pet = false
    local owner_name = nil

    if mob.is_npc then
        for _, v in pairs(windower.ffxi.get_party()) do
            if type(v) == 'table' and v.mob and v.mob.pet_index == mob.index then
                is_pet = true
                owner_name = v.name
                break
            end
        end
    else
        for _, v in pairs(windower.ffxi.get_party()) do
            if type(v) == 'table' and v.mob and v.mob.id == mob.id then
                is_party_or_alliance = true
                break
            end
        end
    end

    return {
        name = mob.name,
        is_party = is_party_or_alliance,
        is_pet = is_pet,
        owner = owner_name,
        type = mob.is_npc and (is_pet and "pet" or "mob") or "pc"
    }
end

local function record_event(actor_name, target_name, act_type, action_detail, value, is_hit)
    table.insert(combat_events, {
        timestamp = os.time(),
        actor = actor_name,
        target = target_name,
        type = act_type, -- 'offense', 'healing', 'skillchain'
        detail = action_detail, -- 'melee', 'ws', 'spell', etc
        value = value,
        hit = is_hit
    })
end

action_parse.debug_mode = false

windower.register_event('action', function(act)
    local actor = get_player_info(act.actor_id)
    if not actor then return end
    
    local is_party_actor = actor.is_party or actor.is_pet
    local display_name = actor.is_pet and (actor.name .. " (" .. actor.owner .. ")") or actor.name

    for _, targ in pairs(act.targets) do
        local target_info = get_player_info(targ.id)
        if target_info then
            local is_party_target = target_info.is_party or target_info.is_pet
            
            -- Only record if the action involves the party (as actor or target)
            if is_party_actor or is_party_target then
                local t_name = target_info.is_pet and (target_info.name .. " (" .. target_info.owner .. ")") or target_info.name
                
                for _, m in pairs(targ.actions) do
                    if m.message ~= 0 then
                        if action_parse.debug_mode and is_party_actor then
                            windower.add_to_chat(207, '[ParseVis Debug] Actor: ' .. display_name .. ' | Category: ' .. act.category .. ' | Message: ' .. m.message .. ' | Param: ' .. m.param)
                        end
                        
                        -- Check Offense/Defense
                        local off_act = offense_action_messages[m.message]
                        if off_act then
                            local is_hit = not string.find(off_act, "miss")
                            -- If actor is party, it's offense. If actor is mob and target is party, it's defense.
                            local act_cat = is_party_actor and 'offense' or 'defense'
                            
                            -- Minor edge case: if party attacks party (e.g. charmed), it will log as offense for the attacker. 
                            -- That's usually fine.
                            record_event(display_name, t_name, act_cat, off_act, m.param, is_hit)
                        end
                        
                        -- Check Healing
                        local heal_act = heal_messages[m.message]
                        if heal_act then
                            -- Only record healing if it comes from the party
                            if is_party_actor then
                                record_event(display_name, t_name, 'healing', heal_act, m.param, true)
                            end
                        end
                        
                        -- Check Add Effects (Skillchains/En-spells)
                        if m.has_add_effect and add_effect_messages[m.add_effect_message] and add_effect_valid[act.category] then
                            if is_party_actor then
                                record_event(display_name, t_name, 'skillchain', 'sc', m.add_effect_param, true)
                            end
                        end
                    end
                end
            end
        end
    end
end)

function action_parse.get_data()
    return combat_events
end

function action_parse.reset()
    combat_events = {}
end

return action_parse

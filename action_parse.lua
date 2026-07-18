local action_parse = {}

local packets = require('packets')
local res = require('resources')
local socket = require('socket')

local combat_events = {}
local timeline_events = {}
local party_jobs = {}

windower.register_event('incoming chunk', function(id, data)
    if id == 0x0DD then
        local packet = packets.parse('incoming', data)
        if packet then
            local name = packet['Name']
            local main_job = packet['Main job']
            local sub_job = packet['Sub job']
            
            if name and name ~= '' and main_job and sub_job then
                party_jobs[name] = {
                    main = res.jobs[main_job] and res.jobs[main_job].en_short or "UNK",
                    sub = res.jobs[sub_job] and res.jobs[sub_job].en_short or "UNK"
                }
            end
        end
    end
end)

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

    local party = windower.ffxi.get_party()
    if mob.is_npc then
        for k, v in pairs(party) do
            if type(v) == 'table' and string.sub(k, 1, 1) == 'p' and v.mob and v.mob.pet_index == mob.index then
                is_pet = true
                owner_name = v.name
                break
            end
        end
    else
        for k, v in pairs(party) do
            if type(v) == 'table' and string.sub(k, 1, 1) == 'p' and v.mob and v.mob.id == mob.id then
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
        timestamp = socket.gettime(),
        actor = actor_name,
        target = target_name,
        type = act_type, -- 'offense', 'healing', 'skillchain'
        detail = action_detail, -- 'melee', 'ws', 'spell', etc
        value = value,
        hit = is_hit
    })
end

local function record_timeline_event(actor_name, action_name, act_type, damage)
    if not action_parse.track_events then return end
    table.insert(timeline_events, {
        timestamp = socket.gettime(),
        actor = actor_name,
        action = action_name,
        type = act_type,
        damage = damage
    })
end

action_parse.debug_mode = false
action_parse.track_events = true

windower.register_event('action', function(act)
    local actor = get_player_info(act.actor_id)
    if not actor then return end
    
    local is_party_actor = actor.is_party or actor.is_pet
    local display_name = actor.is_pet and (actor.name .. " (" .. actor.owner .. ")") or actor.name

    local action_name = nil
    if is_party_actor then
        if act.category == 3 and res.weapon_skills[act.param] then
            action_name = res.weapon_skills[act.param].en
        elseif act.category == 4 and res.spells[act.param] then
            action_name = res.spells[act.param].en
        elseif (act.category == 6 or act.category == 13 or act.category == 14 or act.category == 15) and res.job_abilities[act.param] then
            action_name = res.job_abilities[act.param].en
        end
    end

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
                            
                            if is_party_actor and action_name and is_hit and act_cat == 'offense' then
                                record_timeline_event(display_name, action_name, off_act, m.param)
                            end
                        end
                        
                        -- Check Healing
                        local heal_act = heal_messages[m.message]
                        if heal_act then
                            -- Only record healing if it comes from the party
                            if is_party_actor then
                                record_event(display_name, t_name, 'healing', heal_act, m.param, true)
                                if action_name then
                                    record_timeline_event(display_name, action_name, 'healing', m.param)
                                end
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
    local p = windower.ffxi.get_player()
    if p and p.name and p.main_job_id and p.sub_job_id then
        party_jobs[p.name] = {
            main = res.jobs[p.main_job_id] and res.jobs[p.main_job_id].en_short or "UNK",
            sub = res.jobs[p.sub_job_id] and res.jobs[p.sub_job_id].en_short or "UNK"
        }
    end

    return {
        combat = combat_events,
        timeline = timeline_events,
        jobs = party_jobs
    }
end

function action_parse.get_and_clear_data()
    local p = windower.ffxi.get_player()
    if p and p.name and p.main_job_id and p.sub_job_id then
        party_jobs[p.name] = {
            main = res.jobs[p.main_job_id] and res.jobs[p.main_job_id].en_short or "UNK",
            sub = res.jobs[p.sub_job_id] and res.jobs[p.sub_job_id].en_short or "UNK"
        }
    end

    local data = {
        combat = combat_events,
        timeline = timeline_events,
        jobs = party_jobs
    }
    
    combat_events = {}
    timeline_events = {}
    
    return data
end

function action_parse.reset()
    combat_events = {}
    timeline_events = {}
end

return action_parse

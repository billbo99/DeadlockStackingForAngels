if not settings.startup["deadlock-enable-beltboxes"] or not settings.startup["deadlock-enable-beltboxes"].value then
    return
end

local rusty_locale = require "__rusty-locale__.locale"
local rusty_icons = require "__rusty-locale__.icons"
local rusty_recipes = require "__rusty-locale__.recipes"

local Items = require("migrations.items").items
local default_beltbox = "basic-transport-belt-beltbox"
local tech_by_product = {}

local function dedup_list(data)
    local tmp = {}
    local res = {}
    for k, v in pairs(data) do
        tmp[v] = true
    end
    for k, _ in pairs(tmp) do
        table.insert(res, k)
    end
    return res
end

local function add_result_from_recipe(result, tech)
    local result_type = result.type or "item"
    local result_name = result.name or result

    if result_type == "fluid" then
        return
    end

    if not tech_by_product[result_name] then
        tech_by_product[result_name] = {type = result_type, tech = {}}
    end
    -- if tech.name == default_beltbox or starts_with(tech.name, "deadlock-stacking-") then
    --     -- skipping beltbox technology
    -- else
    table.insert(tech_by_product[result_name].tech, tech.name)
    -- end
end

local function add_products_from_recipe(recipe, tech)
    if recipe.normal then
        if recipe.normal.result then
            add_result_from_recipe(recipe.normal.result, tech)
        elseif recipe.normal.results then
            for _, result in pairs(recipe.normal.results) do
                add_result_from_recipe(result, tech)
            end
        else
            log("hmm")
        end
    elseif recipe.result then
        add_result_from_recipe(recipe.result, tech)
    elseif recipe.results then
        for _, result in pairs(recipe.results) do
            add_result_from_recipe(result, tech)
        end
    else
        log("hmm")
    end
end

local function walk_technology()
    for _, tech in pairs(data.raw.technology) do
        if tech.effects then
            for _, effect in pairs(tech.effects) do
                if effect.type and effect.type == "unlock-recipe" and effect.recipe and data.raw.recipe[effect.recipe] then
                    add_products_from_recipe(data.raw.recipe[effect.recipe], tech)
                end
            end
        end
    end
    log("hmm")
end

local function walk_recipes()
    if not data.raw.recipe[default_beltbox] then
        default_beltbox = "deadlock-stacking-1"
    end

    for _, recipe in pairs(data.raw.recipe) do
        if recipe.enabled then
            add_products_from_recipe(recipe, default_beltbox)
        end
    end
    log("hmm")
    for _, resource in pairs(data.raw.resource) do
        if resource.minable then
            add_products_from_recipe(resource.minable, default_beltbox)
        end
    end
    log("hmm")
    for name, _ in pairs(tech_by_product) do
        if #tech_by_product[name].tech == 0 then
            table.insert(tech_by_product[name].tech, default_beltbox)
        end
    end
    log("hmm")
end

local function add_item_to_tech(name, tech)
    if data.raw.technology[tech] then
        local recipes = {}
        for _, effect in pairs(data.raw.technology[tech].effects) do
            if effect.type == "unlock-recipe" then
                recipes[effect.recipe] = true
            end
        end
        if not recipes[string.format("deadlock-stacks-stack-%s", name)] then
            table.insert(data.raw.technology[tech].effects, {type = "unlock-recipe", recipe = string.format("deadlock-stacks-stack-%s", name)})
        end
        if not recipes[string.format("deadlock-stacks-unstack-%s", name)] then
            table.insert(data.raw.technology[tech].effects, {type = "unlock-recipe", recipe = string.format("deadlock-stacks-unstack-%s", name)})
        end
    end
end

local function main()
    --Add stacking recipes
    for name, item in pairs(Items) do
        local icon = item.icon or nil
        local icon_size = item.icon_size or nil
        local techs = {}
        local item_type = "item"

        if tech_by_product[name] then
            techs = dedup_list(tech_by_product[name].tech)
            item_type = tech_by_product[name].type
        else
            techs = {item.tech}
        end

        if item.type then
            item_type = item.type
        end

        if data.raw[item_type][name] then
            -- if data.raw.item["deadlock-stack-" .. name] then
            --     deadlock.destroy_stack(name)
            -- end

            if data.raw[item_type][name].icons then
                for _, layer in pairs(data.raw[item_type][name].icons) do
                    if not layer.icon_size and data.raw[item_type][name].icon_size then
                        layer.icon_size = data.raw[item_type][name].icon_size
                    end
                end
            end
            if data.raw.item["deadlock-stack-" .. name] then
                add_item_to_tech(name, techs[1])
            else
                deadlock.add_stack(name, icon, techs[1], icon_size, item_type)
                if #techs > 1 then
                    for i = 2, #techs do
                        add_item_to_tech(name, techs[i])
                    end
                end
            end
        else
            log("not found ... data.raw[" .. item_type .. "][" .. name .. "]")
        end
    end
end

walk_technology()
walk_recipes()
main()

-- multiply a number with a unit (kJ, kW etc) at the end
local function multiply_number_unit(property, mult)
    local value, unit
    value = string.match(property, "%d+")
    if string.match(property, "%d+%.%d+") then -- catch floats
        value = string.match(property, "%d+%.%d+")
    end
    unit = string.match(property, "%a+")
    if unit == nil then
        return value * mult
    else
        return ((value * mult) .. unit)
    end
end

local function starts_with(str, start)
    return str:sub(1, #start) == start
end

-- fix any fuel values
local deadlock_stack_size = settings.startup["deadlock-stack-size"].value
for item, item_table in pairs(data.raw.item) do
    if starts_with(item, "deadlock-stack-") then
        local parent = data.raw.item[string.sub(item, 16)]
        if parent and parent.fuel_value then
            item_table.fuel_value = multiply_number_unit(parent.fuel_value, deadlock_stack_size)
            item_table.fuel_category = parent.fuel_category
            item_table.fuel_acceleration_multiplier = parent.fuel_acceleration_multiplier
            item_table.fuel_top_speed_multiplier = parent.fuel_top_speed_multiplier
            item_table.fuel_emissions_multiplier = parent.fuel_emissions_multiplier

            if parent.burnt_result and data.raw.item["deadlock-stack-" .. parent.burnt_result] then
                item_table.burnt_result = "deadlock-stack-" .. parent.burnt_result
            end
        end
    end
end

if settings.startup["angels-enable-components"] and settings.startup["angels-enable-components"].value then
    local stack = data.raw.recipe["deadlock-stacks-stack-iron-gear-wheel"]
    if stack.ingredients[1].name == "mechanical-parts" then
        stack.ingredients[1].name = "iron-gear-wheel"
    end
    local unstack = data.raw.recipe["deadlock-stacks-unstack-iron-gear-wheel"]
    if unstack.result == "mechanical-parts" then
        unstack.result = "iron-gear-wheel"
    end
end

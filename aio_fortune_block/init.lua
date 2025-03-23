-- Define rarity levels
local rarity_levels = {
    rare = 3,
    very_rare = 4,
    ultra_rare = 5
}

-- Define a list of nodes to exclude
local excluded_nodes = {
    "air",
    "ignore"
}

-- Function to check if a node is in the excluded list (by name)
local function is_excluded(node_name)
    for _, excluded in ipairs(excluded_nodes) do
        if node_name == excluded then
            return true
        end
    end
    return false
end

-- Function to assign rarity based on the node's name
local function assign_rarity(node_name)
    -- Define patterns for each rarity
    local ultra_rare_keywords = {"diamond", "tnt:tnt"}
    local very_rare_keywords = {"gold", "mese", "pick", "shovel", "axe", "sword", "tool"}
    local rare_keywords = {"iron", "copper", "ore"}

    -- Helper function to check if a node matches any keyword
    local function matches_keywords(node_name, keywords)
        for _, keyword in ipairs(keywords) do
            if node_name:find(keyword) then
                return true
            end
        end
        return false
    end

    -- Check keywords for each rarity level
    if matches_keywords(node_name, ultra_rare_keywords) then
        return rarity_levels.ultra_rare
    elseif matches_keywords(node_name, very_rare_keywords) then
        return rarity_levels.very_rare
    elseif matches_keywords(node_name, rare_keywords) then
        return rarity_levels.rare
    else
        return nil -- Exclude nodes that don't match the criteria
    end
end

-- Build a dynamic drop list by iterating over all registered items
local function build_drop_list()
    local drop_list = {}
    local all_registered = minetest.registered_items -- Includes both nodes and items

    for item_name, def in pairs(all_registered) do
        if def
           and def.description
           and def.description ~= ""
           and not is_excluded(item_name)
           -- Exclude items that are hidden unless in creative mode
           and not (def.groups and def.groups.not_in_creative_inventory and def.groups.not_in_creative_inventory > 0)
        then
            local rarity = assign_rarity(item_name)
            if rarity then
                table.insert(drop_list, {item = item_name, rarity = rarity})
            end
        end
    end
    return drop_list
end

-- Create the dynamic drop list from all registered items
local dynamic_drop_list = build_drop_list()

-- Debug: Print the list of items with their assigned rarities
for _, item in ipairs(dynamic_drop_list) do
    print(string.format("Item: %s - Rarity: %d", item.item, item.rarity))
end

-- Configuration table
local config = {
    drop_list = dynamic_drop_list,
    max_amount_multiplier = 2
}

-- Helper function to calculate the total weight
local function calculate_total_weight(drop_list)
    local total_weight = 0
    for _, item in ipairs(drop_list) do
        total_weight = total_weight + item.rarity
    end
    return total_weight
end

-- Select a random item from the drop list weighted by rarity
local function get_random_item(drop_list)
    local total_weight = calculate_total_weight(drop_list)
    local rand = math.random(1, total_weight)
    local cumulative_weight = 0

    for _, item in ipairs(drop_list) do
        cumulative_weight = cumulative_weight + item.rarity
        if rand <= cumulative_weight then
            local amount = math.random(1, item.rarity * config.max_amount_multiplier)
            return {name = item.item, amount = amount}
        end
    end

    return nil
end

-- Register the Fortune Block node
minetest.register_node("aio_fortune_block:block", {
    description = "Fortune Block",
    tiles = {"fortune_block.jpg"},
    is_ground_content = true,
    drop = "",
    groups = {cracky = 1, level = 2},
    light_source = 10,

    after_dig_node = function(pos, oldnode, oldmetadata, digger)
        local drop = get_random_item(config.drop_list)
        if drop then
            minetest.add_item(pos, drop.name .. " " .. drop.amount)
            if drop.name == "tnt:tnt" then
                minetest.set_node(pos, {name = "tnt:tnt"})
                if minetest.registered_nodes["tnt:tnt"] and
                   minetest.registered_nodes["tnt:tnt"].on_blast then
                    minetest.registered_nodes["tnt:tnt"].on_blast(pos, {}, {})
                end
            end
        end
    end,
})

-- Add ore generation for the Fortune Block
-- Add ore generation for the Fortune Block (underground and surface)
minetest.register_ore({
    ore_type       = "scatter", -- Scatter randomly in the world
    ore            = "aio_fortune_block:block", -- Fortune Block to generate
    wherein        = {"default:stone", "default:dirt", "default:dirt_with_grass", "default:sand"}, -- Generate inside stone, dirt, grass, or sand
    clust_scarcity = 15 * 15 * 15, -- High rarity (value represents 1 in X chance per chunk)
    clust_num_ores = 1, -- Number of blocks per cluster
    clust_size     = 1, -- Cluster size
    y_min          = -32000, -- Minimum y-level
    y_max          = -10, -- Maximum y-level (extends to surface level and above)
    flags          = "absheight", -- Ensure absolute height constraints
})

-- local function ItemSnapShot(e)
--     local player = game.players[e.player_index]
--     if player.admin then
--         for name, _ in pairs(game.item_prototypes) do
--             game.write_file("snapshot-" .. game.tick .. ".txt", name .. "\n", true, e.player_index)
--         end
--     end
-- end
-- commands.remove_command("item_snapshot")
-- commands.add_command("item_snapshot", "item_snapshot", ItemSnapShot)

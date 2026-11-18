SELECT n.node_object_id AS objectid, s.name AS selector_name
FROM asset_group_tag_selector_nodes n
JOIN asset_group_tag_selectors s ON s.id = n.selector_id
JOIN asset_group_tags t ON t.id = s.asset_group_tag_id
WHERE t.name = 'Tier Zero' ORDER BY objectid, selector_name;

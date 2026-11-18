SELECT s.id, s.name, s.is_default, s.disabled_at IS NULL AS enabled, s.allow_disable
FROM asset_group_tag_selectors s JOIN asset_group_tags t ON t.id = s.asset_group_tag_id
WHERE t.name = 'Tier Zero' ORDER BY s.id;

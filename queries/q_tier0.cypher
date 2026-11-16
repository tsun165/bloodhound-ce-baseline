MATCH (n:Tag_Tier_Zero) RETURN n.objectid AS objectid, n.name AS name, labels(n) AS labels ORDER BY objectid;

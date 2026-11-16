MATCH (n) RETURN n.objectid AS objectid, n.name AS name, labels(n) AS labels ORDER BY objectid;

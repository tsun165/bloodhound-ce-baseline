MATCH (g)-[:LocalToComputer]->(c:Computer)
RETURN g.objectid AS group_oid, labels(g) AS labels, c.objectid AS computer_oid, c.name AS computer
ORDER BY group_oid, computer;

MATCH (m)-[:MemberOfLocalGroup]->(g)
RETURN m.objectid AS member_oid, labels(m) AS member_labels, g.objectid AS group_oid
ORDER BY group_oid, member_oid;

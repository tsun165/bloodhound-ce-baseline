MATCH (s) WHERE (s:User OR s:Group OR s:Computer) AND NOT s:Tag_Tier_Zero
MATCH p = shortestPath((s)-[:MemberOf|Contains|AdminTo|HasSession|GenericAll|GenericWrite|WriteDacl|WriteOwner|Owns|ForceChangePassword|AddMember|AllowedToDelegate|DCSync|GPLink|AllExtendedRights|ReadLAPSPassword|AddSelf|AllowedToAct|CanRDP|CanPSRemote|ExecuteDCOM|SQLAdmin*1..]->(t:Tag_Tier_Zero))
WHERE s <> t
WITH s, collect(p) AS ps, min(length(p)) AS d
UNWIND [x IN ps WHERE length(x) = d] AS p
RETURN s.objectid AS src, d AS dist, last(nodes(p)).objectid AS dst,
       [n IN nodes(p) | n.objectid] AS node_oids, [r IN relationships(p) | type(r)] AS kinds
ORDER BY src, dst;

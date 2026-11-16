MATCH (s) WHERE (s:User OR s:Group OR s:Computer) AND NOT s:Tag_Tier_Zero
OPTIONAL MATCH p = shortestPath((s)-[:MemberOf|Contains|AdminTo|HasSession|GenericAll|GenericWrite|WriteDacl|WriteOwner|Owns|ForceChangePassword|AddMember|AllowedToDelegate|DCSync|GPLink|AllExtendedRights|ReadLAPSPassword|AddSelf|AllowedToAct|CanRDP|CanPSRemote|ExecuteDCOM|SQLAdmin*1..]->(t:Tag_Tier_Zero))
WHERE s <> t
RETURN s.objectid AS objectid, s.name AS name, min(length(p)) AS dist
ORDER BY objectid;

# Câu truy vấn đã chạy cho d0

Chép nguyên văn từ `queries/`. Tất cả chạy bằng `docker compose exec -T -e NEO4J_PASSWORD graph-db cypher-shell -u neo4j --format plain < queries/<file>` (tính đúng) hoặc `--format verbose` (hiệu năng, xem `scripts/perf.sh`).

- Bản CE 9.9.2 **có** nhãn `Tag_Tier_Zero` (kiểm `CALL db.labels()`), nên dùng đúng nhãn này, không cần điều kiện thay thế. `n.system_tags CONTAINS 'admin_tier_0'` cho cùng số node (280 với D0 lúc kiểm).
- Tập 22 cạnh = đúng như đề bài. Tập transit đầy đủ (`reach_all`, `p5`) = `adTransitEdgeTypes` trong `commonSearchesAGT.ts` @ v9.9.2, 65 loại, xem `queries/ad_transit_edge_types.txt`.
- `prebuilt_tier0.json`: câu "Shortest paths to Tier Zero / High Value targets" (`commonSearchesAGT.ts` dòng 189-191) với `${adTransitEdgeTypes}` và `${TAG_TIER_ZERO_AGT}`=`Tag_Tier_Zero` đã thay giá trị, `\n` thành xuống dòng. Gửi qua **API của CE** `POST /api/v2/graphs/cypher` `{query, include_properties:true}` (endpoint mà ô Cypher của UI gọi), không bấm trên UI; file là JSON response nguyên vẹn. Câu gửi đi không có dấu `;` cuối.
- `p2`: Neo4j 4.4 hỗ trợ `EXISTS { MATCH ... }` nên giữ nguyên cú pháp.
- `p3`: bỏ qua, CE không bật APOC.
- `p4`: `$id` truyền bằng `:param id => "<objectid>";` trong cùng phiên cypher-shell.

## `q_node_counts.cypher`

```cypher
MATCH (n) UNWIND labels(n) AS l RETURN l AS label, count(*) AS n ORDER BY n DESC;
```

## `q_edge_counts.cypher`

```cypher
MATCH ()-[r]->() RETURN type(r) AS kind, count(r) AS n ORDER BY n DESC;
```

## `q_nodes.cypher`

```cypher
MATCH (n) RETURN n.objectid AS objectid, n.name AS name, labels(n) AS labels ORDER BY objectid;
```

## `q_edges_22.cypher`

```cypher
MATCH (s)-[r]->(t) WHERE type(r) IN ["MemberOf", "Contains", "AdminTo", "HasSession", "GenericAll", "GenericWrite", "WriteDacl", "WriteOwner", "Owns", "ForceChangePassword", "AddMember", "AllowedToDelegate", "DCSync", "GPLink", "AllExtendedRights", "ReadLAPSPassword", "AddSelf", "AllowedToAct", "CanRDP", "CanPSRemote", "ExecuteDCOM", "SQLAdmin"] RETURN s.objectid AS src, type(r) AS kind, t.objectid AS dst ORDER BY src, kind, dst;
```

## `q_tier0.cypher`

```cypher
MATCH (n:Tag_Tier_Zero) RETURN n.objectid AS objectid, n.name AS name, labels(n) AS labels ORDER BY objectid;
```

## `q_reach_22.cypher`

```cypher
MATCH (s) WHERE (s:User OR s:Group OR s:Computer) AND NOT s:Tag_Tier_Zero
OPTIONAL MATCH p = shortestPath((s)-[:MemberOf|Contains|AdminTo|HasSession|GenericAll|GenericWrite|WriteDacl|WriteOwner|Owns|ForceChangePassword|AddMember|AllowedToDelegate|DCSync|GPLink|AllExtendedRights|ReadLAPSPassword|AddSelf|AllowedToAct|CanRDP|CanPSRemote|ExecuteDCOM|SQLAdmin*1..]->(t:Tag_Tier_Zero))
WHERE s <> t
RETURN s.objectid AS objectid, s.name AS name, min(length(p)) AS dist
ORDER BY objectid;
```

## `q_reach_all.cypher`

```cypher
MATCH (s) WHERE (s:User OR s:Group OR s:Computer) AND NOT s:Tag_Tier_Zero
OPTIONAL MATCH p = shortestPath((s)-[:Owns|GenericAll|GenericWrite|WriteOwner|WriteDacl|MemberOf|ForceChangePassword|AllExtendedRights|AddMember|HasSession|GPLink|AllowedToDelegate|CoerceToTGT|AllowedToAct|AdminTo|CanPSRemote|CanRDP|ExecuteDCOM|HasSIDHistory|AddSelf|DCSync|ReadLAPSPassword|ReadGMSAPassword|DumpSMSAPassword|SQLAdmin|AddAllowedToAct|WriteSPN|AddKeyCredentialLink|SyncLAPSPassword|WriteAccountRestrictions|WriteGPLink|GoldenCert|ADCSESC1|ADCSESC3|ADCSESC4|ADCSESC6a|ADCSESC6b|ADCSESC9a|ADCSESC9b|ADCSESC10a|ADCSESC10b|ADCSESC13|SyncedToADUser|CoerceAndRelayNTLMToSMB|CoerceAndRelayNTLMToADCS|WriteOwnerLimitedRights|OwnsLimitedRights|ClaimSpecialIdentity|CoerceAndRelayNTLMToLDAP|CoerceAndRelayNTLMToLDAPS|ContainsIdentity|PropagatesACEsTo|GPOAppliesTo|CanApplyGPO|HasTrustKeys|WriteAltSecurityIdentities|WritePublicInformation|ManageCA|ManageCertificates|ServerIs|Contains|DCFor|SameForestTrust|SpoofSIDHistory|AbuseTGTDelegation*1..]->(t:Tag_Tier_Zero))
WHERE s <> t
RETURN s.objectid AS objectid, s.name AS name, min(length(p)) AS dist
ORDER BY objectid;
```

## `q_prebuilt_tier0.cypher`

```cypher
MATCH p=shortestPath((s)-[:Owns|GenericAll|GenericWrite|WriteOwner|WriteDacl|MemberOf|ForceChangePassword|AllExtendedRights|AddMember|HasSession|GPLink|AllowedToDelegate|CoerceToTGT|AllowedToAct|AdminTo|CanPSRemote|CanRDP|ExecuteDCOM|HasSIDHistory|AddSelf|DCSync|ReadLAPSPassword|ReadGMSAPassword|DumpSMSAPassword|SQLAdmin|AddAllowedToAct|WriteSPN|AddKeyCredentialLink|SyncLAPSPassword|WriteAccountRestrictions|WriteGPLink|GoldenCert|ADCSESC1|ADCSESC3|ADCSESC4|ADCSESC6a|ADCSESC6b|ADCSESC9a|ADCSESC9b|ADCSESC10a|ADCSESC10b|ADCSESC13|SyncedToADUser|CoerceAndRelayNTLMToSMB|CoerceAndRelayNTLMToADCS|WriteOwnerLimitedRights|OwnsLimitedRights|ClaimSpecialIdentity|CoerceAndRelayNTLMToLDAP|CoerceAndRelayNTLMToLDAPS|ContainsIdentity|PropagatesACEsTo|GPOAppliesTo|CanApplyGPO|HasTrustKeys|WriteAltSecurityIdentities|WritePublicInformation|ManageCA|ManageCertificates|ServerIs|Contains|DCFor|SameForestTrust|SpoofSIDHistory|AbuseTGTDelegation*1..]->(t:Tag_Tier_Zero))
WHERE s<>t
RETURN p
LIMIT 1000;
```

## `p1_reach_per_source.cypher`

```cypher
MATCH (s) WHERE (s:User OR s:Group OR s:Computer) AND NOT s:Tag_Tier_Zero
OPTIONAL MATCH p = shortestPath((s)-[:MemberOf|Contains|AdminTo|HasSession|GenericAll|GenericWrite|WriteDacl|WriteOwner|Owns|ForceChangePassword|AddMember|AllowedToDelegate|DCSync|GPLink|AllExtendedRights|ReadLAPSPassword|AddSelf|AllowedToAct|CanRDP|CanPSRemote|ExecuteDCOM|SQLAdmin*1..]->(t:Tag_Tier_Zero))
WHERE s <> t
RETURN s.objectid AS objectid, s.name AS name, min(length(p)) AS dist
ORDER BY objectid;
```

## `p2_exists_all.cypher`

```cypher
MATCH (s:User) WHERE NOT s:Tag_Tier_Zero AND EXISTS { MATCH (s)-[:MemberOf|Contains|AdminTo|HasSession|GenericAll|GenericWrite|WriteDacl|WriteOwner|Owns|ForceChangePassword|AddMember|AllowedToDelegate|DCSync|GPLink|AllExtendedRights|ReadLAPSPassword|AddSelf|AllowedToAct|CanRDP|CanPSRemote|ExecuteDCOM|SQLAdmin*1..]->(:Tag_Tier_Zero) } RETURN count(s);
```

## `p3_reverse_traversal.cypher`

```cypher
// p3_reverse_traversal: SKIPPED. CE 9.9.2 does not enable APOC (apoc jar only present in /var/lib/neo4j/labs, not loaded). Not run on this machine.
```

## `p4_users_list.cypher`

```cypher
MATCH (u:User) WHERE NOT u:Tag_Tier_Zero RETURN u.objectid ORDER BY u.objectid;
```

## `p4_single_source.cypher`

```cypher
MATCH (s:User {objectid: $id}) OPTIONAL MATCH p = shortestPath((s)-[:MemberOf|Contains|AdminTo|HasSession|GenericAll|GenericWrite|WriteDacl|WriteOwner|Owns|ForceChangePassword|AddMember|AllowedToDelegate|DCSync|GPLink|AllExtendedRights|ReadLAPSPassword|AddSelf|AllowedToAct|CanRDP|CanPSRemote|ExecuteDCOM|SQLAdmin*1..]->(t:Tag_Tier_Zero)) WHERE s <> t RETURN s.objectid, min(length(p));
```

## `p5_prebuilt.cypher`

```cypher
MATCH p=shortestPath((s)-[:Owns|GenericAll|GenericWrite|WriteOwner|WriteDacl|MemberOf|ForceChangePassword|AllExtendedRights|AddMember|HasSession|GPLink|AllowedToDelegate|CoerceToTGT|AllowedToAct|AdminTo|CanPSRemote|CanRDP|ExecuteDCOM|HasSIDHistory|AddSelf|DCSync|ReadLAPSPassword|ReadGMSAPassword|DumpSMSAPassword|SQLAdmin|AddAllowedToAct|WriteSPN|AddKeyCredentialLink|SyncLAPSPassword|WriteAccountRestrictions|WriteGPLink|GoldenCert|ADCSESC1|ADCSESC3|ADCSESC4|ADCSESC6a|ADCSESC6b|ADCSESC9a|ADCSESC9b|ADCSESC10a|ADCSESC10b|ADCSESC13|SyncedToADUser|CoerceAndRelayNTLMToSMB|CoerceAndRelayNTLMToADCS|WriteOwnerLimitedRights|OwnsLimitedRights|ClaimSpecialIdentity|CoerceAndRelayNTLMToLDAP|CoerceAndRelayNTLMToLDAPS|ContainsIdentity|PropagatesACEsTo|GPOAppliesTo|CanApplyGPO|HasTrustKeys|WriteAltSecurityIdentities|WritePublicInformation|ManageCA|ManageCertificates|ServerIs|Contains|DCFor|SameForestTrust|SpoofSIDHistory|AbuseTGTDelegation*1..]->(t:Tag_Tier_Zero))
WHERE s<>t
RETURN p
LIMIT 1000;
```

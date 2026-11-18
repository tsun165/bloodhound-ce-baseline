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

## Câu hỏi bổ sung 19/11 (`queries/extra/`)

Q1 chạy bằng `docker compose exec -T app-db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" --csv -v ON_ERROR_STOP=1' < queries/extra/<file>`. Q2–Q4 chạy như trên (`cypher-shell --format plain`, timeout 600 s) qua `scripts/export_extra.sh d0`; kết quả ở `results/d0/extra/`. Q4 chạy 2 lần (`ce_paths_22.csv`, `ce_paths_22_run2.csv`). Kiểm: `scripts/check_extra.sh d0`.

### `q1_selectors_tier_zero.sql`

```sql
SELECT s.id, s.name, s.is_default, s.disabled_at IS NULL AS enabled, s.allow_disable
FROM asset_group_tag_selectors s JOIN asset_group_tags t ON t.id = s.asset_group_tag_id
WHERE t.name = 'Tier Zero' ORDER BY s.id;
```

### `q1_tier0_by_selector.sql`

```sql
SELECT n.node_object_id AS objectid, s.name AS selector_name
FROM asset_group_tag_selector_nodes n
JOIN asset_group_tag_selectors s ON s.id = n.selector_id
JOIN asset_group_tags t ON t.id = s.asset_group_tag_id
WHERE t.name = 'Tier Zero' ORDER BY objectid, selector_name;
```

### `q2_local_to_computer.cypher`

```cypher
MATCH (g)-[:LocalToComputer]->(c:Computer)
RETURN g.objectid AS group_oid, labels(g) AS labels, c.objectid AS computer_oid, c.name AS computer
ORDER BY group_oid, computer;
```

### `q2_member_of_local_group.cypher`

```cypher
MATCH (m)-[:MemberOfLocalGroup]->(g)
RETURN m.objectid AS member_oid, labels(m) AS member_labels, g.objectid AS group_oid
ORDER BY group_oid, member_oid;
```

### `q3_edges_all.cypher`

```cypher
MATCH (s)-[r]->(t) WHERE type(r) IN ["Owns", "GenericAll", "GenericWrite", "WriteOwner", "WriteDacl", "MemberOf", "ForceChangePassword", "AllExtendedRights", "AddMember", "HasSession", "GPLink", "AllowedToDelegate", "CoerceToTGT", "AllowedToAct", "AdminTo", "CanPSRemote", "CanRDP", "ExecuteDCOM", "HasSIDHistory", "AddSelf", "DCSync", "ReadLAPSPassword", "ReadGMSAPassword", "DumpSMSAPassword", "SQLAdmin", "AddAllowedToAct", "WriteSPN", "AddKeyCredentialLink", "SyncLAPSPassword", "WriteAccountRestrictions", "WriteGPLink", "GoldenCert", "ADCSESC1", "ADCSESC3", "ADCSESC4", "ADCSESC6a", "ADCSESC6b", "ADCSESC9a", "ADCSESC9b", "ADCSESC10a", "ADCSESC10b", "ADCSESC13", "SyncedToADUser", "CoerceAndRelayNTLMToSMB", "CoerceAndRelayNTLMToADCS", "WriteOwnerLimitedRights", "OwnsLimitedRights", "ClaimSpecialIdentity", "CoerceAndRelayNTLMToLDAP", "CoerceAndRelayNTLMToLDAPS", "ContainsIdentity", "PropagatesACEsTo", "GPOAppliesTo", "CanApplyGPO", "HasTrustKeys", "WriteAltSecurityIdentities", "WritePublicInformation", "ManageCA", "ManageCertificates", "ServerIs", "Contains", "DCFor", "SameForestTrust", "SpoofSIDHistory", "AbuseTGTDelegation"]
RETURN s.objectid AS src, type(r) AS kind, t.objectid AS dst ORDER BY src, kind, dst;
```

### `q4_ce_paths_22.cypher`

```cypher
MATCH (s) WHERE (s:User OR s:Group OR s:Computer) AND NOT s:Tag_Tier_Zero
MATCH p = shortestPath((s)-[:MemberOf|Contains|AdminTo|HasSession|GenericAll|GenericWrite|WriteDacl|WriteOwner|Owns|ForceChangePassword|AddMember|AllowedToDelegate|DCSync|GPLink|AllExtendedRights|ReadLAPSPassword|AddSelf|AllowedToAct|CanRDP|CanPSRemote|ExecuteDCOM|SQLAdmin*1..]->(t:Tag_Tier_Zero))
WHERE s <> t
WITH s, collect(p) AS ps, min(length(p)) AS d
UNWIND [x IN ps WHERE length(x) = d] AS p
RETURN s.objectid AS src, d AS dist, last(nodes(p)).objectid AS dst,
       [n IN nodes(p) | n.objectid] AS node_oids, [r IN relationships(p) | type(r)] AS kinds
ORDER BY src, dst;
```

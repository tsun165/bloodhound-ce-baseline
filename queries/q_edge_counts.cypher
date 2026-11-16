MATCH ()-[r]->() RETURN type(r) AS kind, count(r) AS n ORDER BY n DESC;

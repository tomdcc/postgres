-- Tests for REINDEX CONCURRENTLY
CREATE EXTENSION injection_points;

-- Check safety of indexes with predicates and expressions.
SELECT injection_points_set_local();
SELECT injection_points_attach('reindex-conc-index-safe', 'notice');
SELECT injection_points_attach('reindex-conc-index-not-safe', 'notice');

CREATE SCHEMA reindex_inj;
CREATE TABLE reindex_inj.tbl(i int primary key, updated_at timestamp);

CREATE UNIQUE INDEX ind_simple ON reindex_inj.tbl(i);
CREATE UNIQUE INDEX ind_expr ON reindex_inj.tbl(ABS(i));
CREATE UNIQUE INDEX ind_pred ON reindex_inj.tbl(i) WHERE mod(i, 2) = 0;
CREATE UNIQUE INDEX ind_expr_pred ON reindex_inj.tbl(abs(i)) WHERE mod(i, 2) = 0;

REINDEX INDEX CONCURRENTLY reindex_inj.ind_simple;
REINDEX INDEX CONCURRENTLY reindex_inj.ind_expr;
REINDEX INDEX CONCURRENTLY reindex_inj.ind_pred;
REINDEX INDEX CONCURRENTLY reindex_inj.ind_expr_pred;

-- Cleanup
SELECT injection_points_detach('reindex-conc-index-safe');
SELECT injection_points_detach('reindex-conc-index-not-safe');
DROP TABLE reindex_inj.tbl;
DROP SCHEMA reindex_inj;

-- The swap commits two transactions before the old index is dropped, so a
-- command that fails in between leaves the old index behind.  It must not be
-- left marked as having no data: it will never be populated, and pg_dump, psql
-- and a query looking for indexes awaiting a build would each take it for one
-- the user deferred deliberately.
SELECT injection_points_attach('reindex-relation-concurrently-before-set-dead', 'error');
CREATE TABLE reindex_nodata_tbl (i int);
INSERT INTO reindex_nodata_tbl SELECT generate_series(1, 10);
CREATE INDEX reindex_nodata_ind ON reindex_nodata_tbl (i) WITH NO DATA;
REINDEX INDEX CONCURRENTLY reindex_nodata_ind;
SELECT c.relname, i.indisready, i.indisvalid, i.indisnodata
  FROM pg_class c JOIN pg_index i ON i.indexrelid = c.oid
  WHERE c.relname LIKE 'reindex_nodata_ind%'
  ORDER BY c.relname;
SELECT injection_points_detach('reindex-relation-concurrently-before-set-dead');
DROP TABLE reindex_nodata_tbl;

DROP EXTENSION injection_points;

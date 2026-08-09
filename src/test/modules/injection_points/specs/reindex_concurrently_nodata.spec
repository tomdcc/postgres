# REINDEX CONCURRENTLY on an index created WITH NO DATA
#
# For an ordinary REINDEX INDEX CONCURRENTLY, a conflicting insert mid-rebuild
# fails against the *original* index, which is still valid, ready and complete;
# the ccnew copy's contents are a strict subset of it, so ccnew can only miss
# conflicts, never invent them.
#
# A no-data index has no such complete original -- it is indisready = false and
# enforces nothing.  So uniqueness starts being enforced partway through the
# command, by an index the user never created, and keeps being enforced even if
# the reindex later fails.  That is CREATE INDEX CONCURRENTLY's documented
# behaviour rather than ordinary REINDEX CONCURRENTLY's, and it is the one
# genuinely novel behaviour of the feature.
#
# The injection point "reindex-conc-index-built" fires after phase 2, with the
# ccnew copy indisready = true and indisvalid = false -- exactly that window.

setup
{
    CREATE EXTENSION injection_points;
    CREATE TABLE reind_nodata (id int, val int);
    INSERT INTO reind_nodata VALUES (1, 1), (2, 2);
    CREATE UNIQUE INDEX uq_nodata ON reind_nodata (val) WITH NO DATA;

    -- the same, on a partitioned table: REINDEX INDEX CONCURRENTLY on the
    -- partitioned index fans out, reaching the injection point once per
    -- partition.  A unique index on a partitioned table must include the
    -- partition key, so partition by the indexed column.
    CREATE TABLE reind_nodata_p (id int, val int) PARTITION BY RANGE (val);
    CREATE TABLE reind_nodata_p0 PARTITION OF reind_nodata_p
      FOR VALUES FROM (0) TO (100);
    INSERT INTO reind_nodata_p VALUES (1, 1), (2, 2);
    CREATE UNIQUE INDEX uq_nodata_p ON reind_nodata_p (val) WITH NO DATA;
}

teardown
{
    DROP TABLE reind_nodata;
    DROP TABLE reind_nodata_p;
    DROP EXTENSION injection_points;
}

session s1
setup
{
    SELECT injection_points_set_local();
    SELECT injection_points_attach('reindex-conc-index-built', 'wait');
}
step reindex { REINDEX INDEX CONCURRENTLY uq_nodata; }
step reindex_p { REINDEX INDEX CONCURRENTLY uq_nodata_p; }
step noop1 { }

session s2
# Before the reindex starts, the no-data index enforces nothing at all, so a
# duplicate is admitted silently.
step write_dup_before { INSERT INTO reind_nodata VALUES (3, 2); }

# Mid-command, ccnew is ready and is the only enforcing index.  The error names
# uq_nodata_ccnew, an index the user never created, because the no-data
# original is skipped on ii_ReadyForInserts and never gets to report first.
step check_catalog {
    SELECT c.relname, i.indisunique, i.indisready, i.indisvalid, i.indisnodata
    FROM pg_class c
    JOIN pg_index i ON i.indexrelid = c.oid
    WHERE c.relname IN ('uq_nodata', 'uq_nodata_ccnew')
    ORDER BY c.relname;
}
step write_ok  { INSERT INTO reind_nodata VALUES (4, 9); }
step write_dup { INSERT INTO reind_nodata VALUES (5, 9); }
step detach { SELECT injection_points_detach('reindex-conc-index-built'); }
step wakeup { SELECT injection_points_wakeup('reindex-conc-index-built'); }
step check_after {
    SELECT indisready, indisvalid, indisnodata
    FROM pg_index WHERE indexrelid = 'uq_nodata'::regclass;
}

# The partitioned equivalent.  Mid-command the partition's ccnew copy is the
# only enforcing index, exactly as for a plain table.
step check_catalog_p {
    SELECT c.relname, i.indisready, i.indisvalid, i.indisnodata
    FROM pg_class c
    JOIN pg_index i ON i.indexrelid = c.oid
    WHERE c.relname LIKE 'uq_nodata_p%' OR c.relname LIKE 'reind_nodata_p0%'
    ORDER BY c.relname;
}
step write_ok_p  { INSERT INTO reind_nodata_p VALUES (6, 9); }
step write_dup_p { INSERT INTO reind_nodata_p VALUES (7, 9); }
step check_after_p {
    SELECT c.relname, i.indisready, i.indisvalid, i.indisnodata
    FROM pg_class c
    JOIN pg_index i ON i.indexrelid = c.oid
    WHERE c.relname LIKE 'uq_nodata_p%' OR c.relname LIKE 'reind_nodata_p0%'
    ORDER BY c.relname;
}

# A duplicate admitted during the unenforced window makes the reindex itself
# fail, while building the ccnew copy -- so early that the injection point is
# never reached, hence no wakeup here.  The index is left still unpopulated, so
# the failure is retryable and nothing is silently corrupted.
permutation write_dup_before reindex detach check_after

# With no such duplicate, the reindex completes, and ccnew enforces uniqueness
# from the moment it goes ready -- partway through the command.
permutation reindex check_catalog write_ok write_dup detach wakeup noop1 check_after

# Fanning out over the partitions reaches the same window once per partition.
# The partitioned index itself has no storage to rebuild, but naming it is the
# explicit conversion a deferred index waits for, so the flag is cleared here
# too.  Its validity is a separate question, still left to whatever rechecks the
# partitions, so the two no longer move together.
permutation reindex_p check_catalog_p write_ok_p write_dup_p detach wakeup noop1 check_after_p

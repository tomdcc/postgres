# REPACK (CONCURRENTLY) leaves an index created WITH NO DATA alone.
#
# The concurrent path does not reindex the old relation; it builds copies of
# the indexes on the transient heap and swaps their storage.  A no-data index
# is left out of that entirely, so it keeps its own unbuilt storage, exactly
# where the non-concurrent path leaves it.  Building a copy would populate an
# index the user deferred.
#
# This lives here rather than in cluster.sql because REPACK (CONCURRENTLY)
# needs wal_level >= replica, which this module's extra.conf sets; the main
# regression tests are sometimes run with wal_level=minimal.  The injection
# point is only used to hold the rewrite open while another session writes,
# so that the no-data index is present across the decoding path too.

setup
{
    CREATE EXTENSION injection_points;

    CREATE TABLE rpn_tab (i int PRIMARY KEY, j int);
    INSERT INTO rpn_tab SELECT g, g FROM generate_series(1, 20) g;
    CREATE INDEX rpn_plain ON rpn_tab (j);
    CREATE INDEX rpn_nodata ON rpn_tab (j) WITH NO DATA;

    -- A table whose replica identity was designated on a no-data index.  The
    -- designation is recorded but the index is not usable until populated,
    -- so the table has no identity for decoding to work from.
    CREATE TABLE rpn_ri (i int NOT NULL, j int);
    INSERT INTO rpn_ri SELECT g, g FROM generate_series(1, 10) g;
    CREATE UNIQUE INDEX rpn_ri_idx ON rpn_ri (i) WITH NO DATA;
    ALTER TABLE rpn_ri REPLICA IDENTITY USING INDEX rpn_ri_idx;
}

teardown
{
    DROP TABLE rpn_tab;
    DROP TABLE rpn_ri;
    DROP EXTENSION injection_points;
}

session s1
setup
{
    SELECT injection_points_set_local();
    SELECT injection_points_attach('repack-concurrently-before-lock', 'wait');
}
step repack	{ REPACK (CONCURRENTLY) rpn_tab USING INDEX rpn_tab_pkey; }
# The no-data index must still be deferred, and still be the same relation
# file it started as.  The plain index is the control: it is rebuilt.
step check
{
    SELECT c.relname, i.indisnodata, i.indisvalid, i.indisready
      FROM pg_class c JOIN pg_index i ON i.indexrelid = c.oid
      WHERE c.relname IN ('rpn_plain', 'rpn_nodata')
      ORDER BY c.relname;
}
# It still completes afterwards, and then finds the concurrent writes.
step reindex	{ REINDEX INDEX rpn_nodata; }
step check_done
{
    SELECT indisnodata, indisvalid, indisready FROM pg_index
      WHERE indexrelid = 'rpn_nodata'::regclass;
    SELECT count(*) FROM rpn_tab WHERE j > 20;
}
# A table whose replica identity is a deferred index has no usable identity.
step repack_ri	{ REPACK (CONCURRENTLY) rpn_ri; }

session s2
step write	{ INSERT INTO rpn_tab VALUES (21, 21), (22, 22); }
step wakeup	{ SELECT injection_points_wakeup('repack-concurrently-before-lock'); }
step detach	{ SELECT injection_points_detach('repack-concurrently-before-lock'); }

# The rewrite is held open while s2 writes, so the concurrent changes are
# replayed onto the new heap with the no-data index present throughout.
permutation repack write detach wakeup check reindex check_done

# REPACK (CONCURRENTLY) of a table whose replica identity is a no-data index.
permutation detach repack_ri

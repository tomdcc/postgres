# CREATE INDEX ... WITH NO DATA does not block writers.
#
# The command builds nothing, and the index it leaves behind holds no entries
# and is not maintained, so a concurrent writer cannot make it inconsistent.
# It therefore takes ShareUpdateExclusiveLock rather than the ShareLock a
# building CREATE INDEX needs.  A plain CREATE INDEX in the same position waits
# for the open writer, and queues later writers behind itself while it waits,
# which is the cost the clause exists to avoid.

setup
{
    CREATE TABLE cin_tab (i int);
    INSERT INTO cin_tab SELECT generate_series(1, 10);
}

teardown
{
    DROP TABLE cin_tab;
}

session writer
step wbegin	{ BEGIN; }
step wins	{ INSERT INTO cin_tab VALUES (11); }
step wcommit	{ COMMIT; }

session definer
step cindex_nodata	{ CREATE INDEX cin_idx ON cin_tab (i) WITH NO DATA; }
step cindex_plain	{ CREATE INDEX cin_idx2 ON cin_tab (i); }

session other
step oins	{ INSERT INTO cin_tab VALUES (12); }

# The deferred definition completes while a writer's transaction is open, and a
# writer arriving afterwards is not queued behind it.
permutation wbegin wins cindex_nodata oins wcommit

# For contrast, a building CREATE INDEX waits for the open writer, and the later
# writer waits behind it.
permutation wbegin wins cindex_plain oins wcommit

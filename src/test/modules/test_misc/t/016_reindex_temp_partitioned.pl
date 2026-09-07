# Copyright (c) 2026, PostgreSQL Global Development Group

# REINDEX DATABASE must leave another session's temporary relations alone,
# partitioned indexes on them included.  Such an index has nothing to rebuild,
# but it is a candidate for the validity recheck that follows the rebuilds, and
# the recheck locks each index it collected.  Collecting one therefore means
# waiting on a lock held by a live session, for an index whose partitions this
# command has already skipped.
#
# A regression here shows up as REINDEX DATABASE blocking until lock_timeout
# fires, rather than as a wrong result.

use strict;
use warnings FATAL => 'all';
use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

my $node = PostgreSQL::Test::Cluster->new('reindex_temp');
$node->init;
$node->start;

# The session that owns the temporary partitioned tree.  background_psql keeps
# it alive, so the objects still exist -- and still belong to somebody else --
# while the second session reindexes the database.
my $owner = $node->background_psql('postgres');
$owner->query_safe(q(CREATE TEMP TABLE tt (a int) PARTITION BY RANGE (a);));
$owner->query_safe(
	q(CREATE TEMP TABLE tt1 PARTITION OF tt FOR VALUES FROM (1) TO (10);));

# ON ONLY leaves the partitioned index invalid, which is what makes it worth
# collecting for a recheck in the first place.
$owner->query_safe(q(CREATE INDEX tt_idx ON ONLY tt (a);));

# Hold a lock conflicting with the ShareUpdateExclusiveLock the recheck would
# take.  Any maintenance the owning session runs on its own temporary table
# holds one of these; LOCK is merely the shortest way to say so.
$owner->query_safe(q(BEGIN;));
$owner->query_safe(q(LOCK TABLE tt IN ACCESS EXCLUSIVE MODE;));

# A permanent incomplete tree in the same database.  REINDEX DATABASE reports a
# partitioned index it leaves invalid, so this one shows that the recheck ran
# and reported what is in scope, while the temporary tree is neither rechecked
# nor mentioned.
$node->safe_psql(
	'postgres', q(
	CREATE TABLE pt (a int) PARTITION BY RANGE (a);
	CREATE TABLE pt1 PARTITION OF pt FOR VALUES FROM (1) TO (10);
	CREATE INDEX pt_idx ON ONLY pt (a);));

# Bound the damage of a regression: without lock_timeout this would hang for as
# long as the owning session held its transaction open.
local $ENV{PGOPTIONS} = '-c lock_timeout=30s';

my ($result, $stdout, $stderr) =
  $node->psql('postgres', 'REINDEX DATABASE postgres;');

is($result, 0, 'REINDEX DATABASE skips another session\'s temp index');
like(
	$stderr,
	qr/partitioned index "public\.pt_idx" remains invalid/,
	'the permanent incomplete tree in scope is reported');
unlike($stderr, qr/tt_idx/,
	'the other session\'s temporary index is not mentioned');

# The index was skipped, not rechecked, so it is as invalid as it was.
is( $node->safe_psql(
		'postgres',
		q(SELECT indisvalid FROM pg_index WHERE indexrelid = (
		    SELECT c.oid FROM pg_class c JOIN pg_namespace n
		      ON n.oid = c.relnamespace
		     WHERE c.relname = 'tt_idx' AND n.nspname LIKE 'pg_temp%'))),
	'f',
	'the temporary partitioned index is left invalid');

$owner->query_safe(q(COMMIT;));
$owner->quit;
$node->stop;

done_testing();

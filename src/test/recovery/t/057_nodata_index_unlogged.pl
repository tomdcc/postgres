# Copyright (c) 2021-2026, PostgreSQL Global Development Group

# Tests that an index created WITH NO DATA on an unlogged table survives a
# crash correctly, and can still be populated afterwards.
#
# An index created WITH NO DATA is never passed to index_build(), which is
# where an unlogged index would normally get its WAL-logged init fork.  Since
# that fork is the whole of an unlogged relation's durability story --
# RelationCreateStorage() does not WAL-log the main fork for one -- such an
# index writes its init fork on the skip-build path instead, so that it is
# structurally identical to every other unlogged index and needs no special
# case in the recovery path.
#
# This cannot be a pg_regress test because it requires a crash restart.

use strict;
use warnings FATAL => 'all';
use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

my $node = PostgreSQL::Test::Cluster->new('main');
$node->init;
$node->start;
my $pgdata = $node->data_dir;

$node->safe_psql(
	'postgres', q{
	CREATE UNLOGGED TABLE nodata_unlogged (id int);
	INSERT INTO nodata_unlogged SELECT generate_series(1, 1000);
	CREATE INDEX nodata_unlogged_idx ON nodata_unlogged (id) WITH NO DATA;
	CREATE INDEX ordinary_unlogged_idx ON nodata_unlogged (id);
});

my $nodataPath = $node->safe_psql('postgres',
	q{SELECT pg_relation_filepath('nodata_unlogged_idx')});
my $ordinaryPath = $node->safe_psql('postgres',
	q{SELECT pg_relation_filepath('ordinary_unlogged_idx')});

# The no-data index must have both forks, exactly like the ordinary one.  This
# is the point of the whole exercise: without the init fork it would be the
# only unlogged relation in the system lacking one.
ok(-f "$pgdata/${nodataPath}_init", 'no-data index init fork exists');
ok(-f "$pgdata/$nodataPath", 'no-data index main fork exists');
ok(-f "$pgdata/${ordinaryPath}_init", 'ordinary index init fork exists');

is( $node->safe_psql(
		'postgres', q{
		SELECT indisnodata, indisvalid, indisready FROM pg_index
		  WHERE indexrelid = 'nodata_unlogged_idx'::regclass}),
	't|f|f',
	'index is no data before the crash');

# Crash and restart.  The unlogged heap is reset to empty from its init fork;
# the no-data index is reset the same way, leaving it empty, which is the
# consistent outcome -- empty table, empty index.
$node->stop('immediate');
$node->start;

is($node->safe_psql('postgres', 'SELECT count(*) FROM nodata_unlogged'),
	0, 'unlogged table was reset by the crash');

is( $node->safe_psql(
		'postgres', q{
		SELECT indisnodata, indisvalid, indisready FROM pg_index
		  WHERE indexrelid = 'nodata_unlogged_idx'::regclass}),
	't|f|f',
	'index is still no data after the crash');

ok(-f "$pgdata/${nodataPath}_init", 'init fork survived the crash');

# And the index can still be completed afterwards.
$node->safe_psql(
	'postgres', q{
	INSERT INTO nodata_unlogged SELECT generate_series(1, 500);
	REINDEX INDEX nodata_unlogged_idx;
});

# Note this checks only that the index became usable; clearing indisnodata
# is the business of the commit that makes REINDEX complete such an index.
is( $node->safe_psql(
		'postgres', q{
		SELECT indisvalid, indisready FROM pg_index
		  WHERE indexrelid = 'nodata_unlogged_idx'::regclass}),
	't|t',
	'REINDEX populates the index after a crash');

is( $node->safe_psql(
		'postgres', q{
		SET enable_seqscan = off;
		SELECT count(*) FROM nodata_unlogged WHERE id BETWEEN 10 AND 20}),
	11,
	'populated index returns correct results');

# REINDEX gave the index a new relfilenumber, which must have its own init
# fork, or the next crash would lose it.
my $newPath = $node->safe_psql('postgres',
	q{SELECT pg_relation_filepath('nodata_unlogged_idx')});
ok(-f "$pgdata/${newPath}_init", 'init fork exists after REINDEX');

$node->stop('immediate');
$node->start;

is($node->safe_psql('postgres', 'SELECT count(*) FROM nodata_unlogged'),
	0, 'unlogged table reset again');

is( $node->safe_psql(
		'postgres', q{
		SELECT indisvalid, indisready FROM pg_index
		  WHERE indexrelid = 'nodata_unlogged_idx'::regclass}),
	't|t',
	'populated index stays valid across a later crash');

done_testing();

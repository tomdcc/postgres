--
-- Test foreign keys with WHERE clauses
--

--
-- Basic setup
--
create type commentable_entity as enum ('blog', 'event');
create table blog (
	id int4 primary key
);
create table event (
	id int4 primary key
);
create table comment (
	id int4,
	parent_entity commentable_entity not null,
	parent_id int4 default 66
);

--
-- basic fk insertion / pk deletion / pk update with restrict
--

-- add constraints
alter table comment add constraint comment_blog_fk foreign key (parent_id)
	where (parent_entity = 'blog')
	references blog(id)
	on delete restrict;
alter table comment add constraint comment_event_fk foreign key (parent_id)
	where (parent_entity = 'event')
	references event(id)
	on update restrict;

-- data setup
insert into blog values (10);
insert into event values (20);
insert into comment values(1, 'blog', 10);
insert into comment values(2, 'event', 20);

-- failing insert
insert into comment values(3, 'blog', 20); -- fails
select * from comment order by id;

-- delete of foreign key
delete from blog; -- fails
select * from comment order by id;

-- update of foreign key
update event set id = 77; -- fails
select * from comment order by id;

-- cleanup
delete from comment;
delete from blog;
delete from event;
alter table comment drop constraint comment_blog_fk;
alter table comment drop constraint comment_event_fk;

--
-- cascade deletions / updates
--

-- add constraints
alter table comment add constraint comment_blog_fk foreign key (parent_id)
	where (parent_entity = 'blog')
	references blog(id)
	on delete cascade;
alter table comment add constraint comment_event_fk foreign key (parent_id)
	where (parent_entity = 'event')
	references event(id)
	on update cascade;

-- data setup
insert into blog values (10);
insert into blog values (20);
insert into comment values(1, 'blog', 10);
insert into comment values(2, 'blog', 20);
insert into event values (10);
insert into event values (20);
insert into comment values(3, 'event', 10);
insert into comment values(4, 'event', 20);

-- cascading update
update event set id = 22 where id = 20;
select * from comment order by id;

-- cascading delete
delete from blog where id = 10;
select * from comment order by id;

-- cleanup
delete from comment;
delete from event;
delete from blog;
alter table comment drop constraint comment_blog_fk;
alter table comment drop constraint comment_event_fk;

--
-- set null
--

-- add constraints
alter table comment add constraint comment_blog_fk foreign key (parent_id)
	where (parent_entity = 'blog')
	references blog(id)
	on delete set null;
alter table comment add constraint comment_event_fk foreign key (parent_id)
	where (parent_entity = 'event')
	references event(id)
	on update set null;

-- data setup
insert into blog values (10);
insert into blog values (20);
insert into comment values(1, 'blog', 10);
insert into comment values(2, 'blog', 20);
insert into event values (10);
insert into event values (20);
insert into comment values(3, 'event', 10);
insert into comment values(4, 'event', 20);

-- update
update event set id = 22 where id = 20;
select * from comment order by id;

-- delete
delete from blog where id = 10;
select * from comment order by id;

-- cleanup
delete from comment;
delete from event;
delete from blog;
alter table comment drop constraint comment_blog_fk;
alter table comment drop constraint comment_event_fk;

--
-- set default
--

-- add constraints
alter table comment add constraint comment_blog_fk foreign key (parent_id)
	where (parent_entity = 'blog')
	references blog(id)
	on delete set default;
alter table comment add constraint comment_event_fk foreign key (parent_id)
	where (parent_entity = 'event')
	references event(id)
	on update set default;

-- data setup
insert into blog values (10);
insert into blog values (20);
insert into comment values(1, 'blog', 10);
insert into comment values(2, 'blog', 20);
insert into event values (10);
insert into event values (20);
insert into comment values(3, 'event', 10);
insert into comment values(4, 'event', 20);

-- update
update event set id = 22 where id = 20; -- fails
insert into event values (66);
update event set id = 22 where id = 20;
select * from comment order by id;

-- delete
delete from blog where id = 10; -- fails
insert into blog values (66);
delete from blog where id = 10;
select * from comment order by id;

-- cleanup
delete from comment;
delete from event;
delete from blog;
alter table comment drop constraint comment_blog_fk;
alter table comment drop constraint comment_event_fk;

--
-- no action with deferred constraints
--

-- add constraints
alter table comment add constraint comment_blog_fk foreign key (parent_id)
	where (parent_entity = 'blog')
	references blog(id)
	on delete no action
	deferrable initially deferred;
alter table comment add constraint comment_event_fk foreign key (parent_id)
	where (parent_entity = 'event')
	references event(id)
	on update no action
	deferrable initially deferred;

-- data setup
insert into blog values (10);
insert into blog values (20);
insert into comment values(1, 'blog', 10);
insert into comment values(2, 'blog', 20);
insert into event values (10);
insert into event values (20);
insert into comment values(3, 'event', 10);
insert into comment values(4, 'event', 20);

-- update
begin;
update event set id = 22 where id = 20;
insert into event values (20);
commit;
select * from comment order by id;

-- delete
begin;
delete from blog where id = 10;
insert into blog values (10);
commit;
select * from comment order by id;

-- cleanup
delete from comment;
delete from event;
delete from blog;
alter table comment drop constraint comment_blog_fk;
alter table comment drop constraint comment_event_fk;

--
-- error handling
--

-- non-existent column
alter table comment add constraint comment_blog_fk foreign key (parent_id)
	where (foo = 'blog')
	references blog(id);

-- wrong type
alter table comment add constraint comment_blog_fk foreign key (parent_id)
	where (parent_entity = 1234)
	references blog(id);

-- expression not boolean
alter table comment add constraint comment_blog_fk foreign key (parent_id)
	where (parent_entity::text)
	references blog(id);

--
-- validation when table is pre-populated
--
insert into comment values(1, 'blog', 10);
alter table comment add constraint comment_blog_fk foreign key (parent_id)
	where (parent_entity = 'blog')
	references blog(id); -- fails
insert into blog values(10);
alter table comment add constraint comment_blog_fk foreign key (parent_id)
	where (parent_entity = 'blog')
	references blog(id);

--
-- the predicate round-trips through pg_get_constraintdef
--
select pg_get_constraintdef(oid) from pg_constraint
	where conrelid = 'comment'::regclass order by conname;
\d comment

-- feeding a deparsed definition back in reproduces it exactly
alter table comment add constraint comment_blog_fk2
	FOREIGN KEY (parent_id) WHERE ((parent_entity = 'blog'::commentable_entity))
	REFERENCES blog(id);
select pg_get_constraintdef(oid) from pg_constraint
	where conrelid = 'comment'::regclass and conname = 'comment_blog_fk2';
alter table comment drop constraint comment_blog_fk2;

-- the predicate's columns are depended on, not just the key columns
alter table comment drop column parent_entity;
alter table comment drop constraint comment_blog_fk;

--
-- combinations that are not supported yet
--
create table part_comment (
	id int4,
	parent_entity commentable_entity not null,
	parent_id int4
) partition by range (id);
alter table part_comment add constraint part_comment_blog_fk foreign key (parent_id)
	where (parent_entity = 'blog')
	references blog(id); -- fails
create table part_blog (
	id int4 primary key
) partition by range (id);
alter table comment add constraint comment_partblog_fk foreign key (parent_id)
	where (parent_entity = 'blog')
	references part_blog(id); -- fails
drop table part_comment;
drop table part_blog;

-- cleanup
drop table comment;
drop table blog;
drop table event;
drop type commentable_entity;

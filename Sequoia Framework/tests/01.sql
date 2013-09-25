	--DROP SCHEMA testschema CASCADE;
	CREATE SCHEMA testschema;

	ALTER SEQUENCE sequoia.entity_entityid_seq RESTART WITH 1;
	DELETE FROM sequoia.entity;

	CREATE TABLE testschema.TestEntity (num INT) INHERITS(sequoia.entity);
	INSERT INTO testschema.TestEntity(num) VALUES (444);
	INSERT INTO testschema.TestEntity(num) VALUES (444);
	INSERT INTO testschema.TestEntity(num) VALUES (444);
	INSERT INTO testschema.TestEntity(num) VALUES (444);
	INSERT INTO testschema.TestEntity(num) VALUES (444);

	SET search_path TO "sequoia,sequoia_alist,$user,public";

	DROP TABLE logg;
	CREATE TEMP TABLE logg(id serial, res boolean) ON COMMIT DELETE ROWS;

	
	INSERT INTO logg(res) VALUES ((SELECT sequoia_alist.isEmpty()));
	
	SELECT sequoia_alist.addnode(1,-1); -- set 1 as root
	SELECT sequoia_alist.addNode(2,1);
	SELECT sequoia_alist.addNode(3,2);
	SELECT sequoia_alist.addNode(4,1);
	SELECT sequoia_alist.contains(1);

	
	INSERT INTO logg(res) VALUES (NOT (SELECT sequoia_alist.isEmpty()));
	INSERT INTO logg(res) VALUES ((SELECT sequoia_alist.contains(1)));
	INSERT INTO logg(res) VALUES ((SELECT sequoia_alist.contains(4)));
	INSERT INTO logg(res) VALUES ((SELECT NOT sequoia_alist.contains(5)));
	INSERT INTO logg(res) VALUES ((SELECT NOT sequoia_alist.contains(7)));
	
	INSERT INTO logg(res) VALUES ((SELECT sequoia_alist.isroot(1)));
	INSERT INTO logg(res) VALUES ((SELECT NOT sequoia_alist.isroot(4)));
	
	DROP SCHEMA testschema CASCADE;


SELECT * FROM logg;

CREATE OR REPLACE FUNCTION sequoia_init() RETURNS void AS 
$BODY$
DECLARE nodes INT; 
	schemaExists INT;
BEGIN  
	
-- Safely create the sequoia_alist schema
SELECT COUNT(schema_name) INTO schemaExists FROM information_schema.schemata WHERE schema_name = 'sequoia_alist';
IF schemaExists > 0 THEN
	DROP SCHEMA sequoia_alist CASCADE;
END IF;	
CREATE SCHEMA sequoia_alist;
	
CREATE TABLE sequoia_alist.Node (
	childId INT NOT NULL,--references sequoia.Entity(entityId),
	parentId INT NOT NULL-- references sequoia.Entity(entityId)	
) INHERITS (sequoia.Entity);

END;
$BODY$ LANGUAGE plpgsql;


-- initialize sequoia adjacency list 
SELECT sequoia_init();
DROP FUNCTION sequoia_init();
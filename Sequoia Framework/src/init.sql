CREATE OR REPLACE FUNCTION sequoia.throwIntegrityError(msg varchar(40)) RETURNS void AS 
$BODY$
DECLARE nodes INT; 
	schemaExists INT;
BEGIN
    -- todo check if the node is in any hierarchy
    raise exception 'Referential integrity error.%',msg;
END;
$BODY$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION sequoia_init() RETURNS void AS 
$BODY$
DECLARE nodes INT; 
	schemaExists INT;
BEGIN  
	
	-- Safely create the sequoia schema
	SELECT COUNT(schema_name) INTO schemaExists FROM information_schema.schemata WHERE schema_name = 'sequoia';
	IF schemaExists > 0 THEN
		DROP SCHEMA sequoia CASCADE;
	END IF;	
	CREATE SCHEMA sequoia;
	
	-- invariant: at this moment sequoia contains no objects at all.	
	-- generic entity definition
	CREATE TABLE sequoia.Entity (
	    entityId serial primary key
	);
		
	-- hierarchy definition (it is also an entity)
	CREATE TABLE sequoia.Hierarchy (
		name varchar(40) UNIQUE	
	) INHERITS (sequoia.Entity);	
	RETURN;
        
        -- TODO referential integrity via triggers (FKs dont yet work for inherited tables)
        -- trigger an error on entity id changed    
        /* CREATE TRIGGER check_entity_updated
        BEFORE UPDATE ON sequoia.Entity;
        FOR EACH ROW
        WHEN (OLD.entityId IS DISTINCT FROM NEW.entityId)
        EXECUTE PROCEDURE sequoia.throwIntegrityError('Can not update an id of an entity that still is in a hierarchy. Remove the entity from hierarchy first.');
        
        -- trigger an error on entity removed
        CREATE TRIGGER check_entity_deleted
        BEFORE DELETE ON sequoia.Entity;
        FOR EACH ROW
        EXECUTE PROCEDURE sequoia.throwIntegrityError('Can not delete an entity that still is in a hierarchy. Remove the entity from hierarchy first.');
        */ 
END;
$BODY$ LANGUAGE plpgsql VOLATILE;

-- initialize sequoia core
SELECT sequoia_init();
DROP FUNCTION sequoia_init();

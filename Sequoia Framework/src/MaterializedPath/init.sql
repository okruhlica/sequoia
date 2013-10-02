
CREATE OR REPLACE FUNCTION sequoia_mpath_init() RETURNS void AS 
$BODY$
DECLARE nodes INT; 
	schemaExists INT;
BEGIN  
	
    -- Safely create the sequoia_mpath schema
    SELECT COUNT(schema_name) INTO schemaExists FROM information_schema.schemata WHERE schema_name = 'sequoia_mpath';
    IF schemaExists > 0 THEN
            DROP SCHEMA sequoia_mpath CASCADE;
    END IF;	
    CREATE SCHEMA sequoia_mpath;
            
    CREATE TABLE sequoia_mpath.Node (
        elId INT NOT NULL, 
        lineage TEXT NOT NULL 
    ) INHERITS (sequoia.Entity);

    CREATE INDEX mpath_node_elementIdx ON sequoia_mpath.Node (elId);
    CREATE INDEX mpath_node_lineageIdx ON sequoia_mpath.Node (lower(lineage));
END;
$BODY$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sequoia_mpath_teardown() RETURNS void AS 
$BODY$
DECLARE schemaExists INT;
BEGIN  
	
-- Safely delete the sequoia materialized path schema
SELECT COUNT(schema_name) INTO schemaExists FROM information_schema.schemata WHERE schema_name = 'sequoia_mpath';
IF schemaExists > 0 THEN
	DROP SCHEMA sequoia_mpath CASCADE;
END IF;	
END;
$BODY$ LANGUAGE plpgsql;

-- initialize sequoia materialized path implementation
SELECT sequoia_mpath_init();
DROP FUNCTION sequoia_mpath_init();



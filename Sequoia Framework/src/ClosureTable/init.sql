
CREATE OR REPLACE FUNCTION sequoia_ctable_init() RETURNS void AS 
$BODY$
DECLARE nodes INT; 
	schemaExists INT;
BEGIN  
	
    -- Safely create the sequoia_ctable schema
    SELECT COUNT(schema_name) INTO schemaExists FROM information_schema.schemata WHERE schema_name = 'sequoia_ctable';
    IF schemaExists > 0 THEN
            DROP SCHEMA sequoia_ctable CASCADE;
    END IF;	
    CREATE SCHEMA sequoia_ctable;
            
    CREATE TABLE sequoia_ctable.ClosureTable (
        upper INT NOT NULL, 
        lower INT NOT NULL,
        depth INT NOT NULL
    ) INHERITS (sequoia.Entity);

    CREATE INDEX ctable_node_lowerIdx ON sequoia_ctable.ClosureTable (upper);
    CREATE INDEX ctable_node_upperIdx ON sequoia_ctable.ClosureTable (lower);
END;
$BODY$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sequoia_ctable_teardown() RETURNS void AS 
$BODY$
DECLARE schemaExists INT;
BEGIN  
	
-- Safely delete the sequoia ctable schema
SELECT COUNT(schema_name) INTO schemaExists FROM information_schema.schemata WHERE schema_name = 'sequoia_ctable';
IF schemaExists > 0 THEN
	DROP SCHEMA sequoia_ctable CASCADE;
END IF;	
END;
$BODY$ LANGUAGE plpgsql;

-- initialize sequoia closure table implementation
SELECT sequoia_ctable_init();
DROP FUNCTION sequoia_ctable_init();
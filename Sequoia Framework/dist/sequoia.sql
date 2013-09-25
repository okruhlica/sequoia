

BEGIN TRANSACTION;


--- File: /init.sql ----

-- drop the schema with everything in it


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
END;
$BODY$ LANGUAGE plpgsql VOLATILE;

-- initialize sequoia core
SELECT sequoia_init();
DROP FUNCTION sequoia_init();


--- File: ./AdjacencyList//init.sql ----


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


--- File: /functions.sql ----

-- returns id of the newly created hierarchy
CREATE FUNCTION sequoia.createHierarchy(hierarchyName varchar(40))   
RETURNS INT AS  
$$  
DECLARE retVal INT;
BEGIN  
	INSERT INTO sequoia.hierarchy(name) VALUES (hierarchyName);
	select currval('entity_entityid_seq') into retVal;
	return retVal;
END;  
$$ LANGUAGE plpgsql;

CREATE FUNCTION sequoia.removeHierarchy(hierarchyName varchar(40))   
RETURNS void AS  
$$  
BEGIN  
 	-- TODO 
END;  
$$ LANGUAGE plpgsql;


--- Function file: ./AdjacencyList//functions.sql ----
-- isEmpty function
-- Returns true iff there is no node is in the hierarchy.
-- 
CREATE OR REPLACE FUNCTION sequoia_alist.isEmpty() RETURNS boolean AS 
$BODY$
DECLARE nodes INT;
BEGIN  
	SELECT COUNT(DISTINCT entityId)
	INTO nodes
	FROM sequoia_alist.Node;
	
	RETURN (nodes = 0);
END;
$BODY$ LANGUAGE plpgsql VOLATILE;

-- contains function
-- Returns true iff the specified node is in a hierarchy.
-- @nodeId id of the entity to add
--
-- RULES:
-- a. nodeId must not be null.
CREATE OR REPLACE FUNCTION sequoia_alist.contains(nodeId INT) RETURNS boolean AS 
$BODY$
DECLARE node INT;
BEGIN
	
	IF (nodeId IS NULL) THEN
		RAISE EXCEPTION 'nodeId must not be null.';
	END IF;
	
	SELECT * INTO node
	FROM sequoia_alist.Node
	WHERE (parentId = nodeId) OR
		  (childId = nodeId)
	LIMIT 1;
	
	RETURN FOUND;
END;
$BODY$ LANGUAGE plpgsql VOLATILE;


-- addNode function
-- Adds a node to the hierarchy.
-- @nodeId id of the entity to add
-- @underNodeId id of the entity to add the node below. If null, nodeId is attempted to be made a root.
--
-- RULES:
-- a. nodeId can not be null
-- b. If nodeId is the same as underNodeId an exception is raised.
-- c. If underNodeId does not exist in the hierarchy, an exception is raised.
-- d. Node that already is in the hierarchy must be removed before it can be added again.
-- e. Adding a node as a root succeeds iff there are no other nodes in the hierarchy.
CREATE OR REPLACE FUNCTION sequoia_alist.addNode(nodeId INT, underNodeId INT) 
RETURNS void AS 
$BODY$
BEGIN  
	
	-- Check for rule a.
	IF (nodeId = -1) THEN
		RAISE EXCEPTION 'NodeId must not be null.';
	END IF;
	
	-- Check for rule b.
	IF (nodeId = underNodeId) THEN
		RAISE EXCEPTION 'You can not hang a node under itself.';
	END IF;

	-- Check for rule c.
	IF ((underNodeId > 0) AND (NOT sequoia_alist.contains(underNodeId))) THEN	
		RAISE EXCEPTION 'The underNode node (id: %) is not in the hierarchy.', underNodeId;
	END IF;
	
	-- Check for rule d.
	IF (sequoia_alist.contains(nodeId)) THEN
		RAISE EXCEPTION 'This node (id: %) already is in the hierarchy.', nodeId;
	END IF;
			
	-- insert the node into the hierarchy
	INSERT INTO sequoia_alist.Node(childId, parentId) 
	VALUES (nodeId, underNodeId);
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

-- isRoot function
-- Returns true iff the specified node is a root.
-- @nodeId id of the entity to check
--
-- RULES:
-- a. nodeId must not be null.
CREATE OR REPLACE FUNCTION sequoia_alist.isRoot(nodeId INT) RETURNS boolean AS 
$BODY$
DECLARE node INT;
BEGIN
	
	IF (nodeId IS NULL) THEN
		RAISE EXCEPTION 'nodeId must not be null.';
	END IF;
	
	SELECT * 
	INTO node
	FROM sequoia_alist.Node
	WHERE (parentId = -1) AND
		  (childId = nodeId)
	LIMIT 1;
	
	RETURN FOUND;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

-- isLeaf function
-- Returns true iff the specified node is a leaf.
-- @nodeId id of the entity to check
--
-- RULES:
-- a. nodeId must not be null.
CREATE OR REPLACE FUNCTION sequoia_alist.isLeaf(nodeId INT) RETURNS boolean AS 
$BODY$
DECLARE node INT;
BEGIN
	
	IF (nodeId IS NULL) THEN
		RAISE EXCEPTION 'nodeId must not be null.';
	END IF;
	
	SELECT * 
	INTO node
	FROM sequoia_alist.Node
	WHERE parentId = nodeId
	LIMIT 1;
	
	RETURN NOT FOUND;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

END TRANSACTION;


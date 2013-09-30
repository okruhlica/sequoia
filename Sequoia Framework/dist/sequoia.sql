

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


CREATE OR REPLACE FUNCTION sequoia_alist_init() RETURNS void AS 
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

CREATE OR REPLACE FUNCTION sequoia_alist_teardown() RETURNS void AS 
$BODY$
DECLARE schemaExists INT;
BEGIN  
	
-- Safely delete the sequoia_alist schema
SELECT COUNT(schema_name) INTO schemaExists FROM information_schema.schemata WHERE schema_name = 'sequoia_alist';
IF schemaExists > 0 THEN
	DROP SCHEMA sequoia_alist CASCADE;
END IF;	
END;
$BODY$ LANGUAGE plpgsql;

-- initialize sequoia adjacency list 
SELECT sequoia_alist_init();
DROP FUNCTION sequoia_alist_init();




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
/*
    Function: isEmpty
    
    Returns true iff there is no node is in the hierarchy.
    
    Parameters:
    
    See also:
        <nodeCount>
*/ 
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

/*
    Function: contains
    
    Returns true iff the specified node is in a hierarchy.

    Parameters:
    
        nodeId - id of the sequoia.entity to search for in the hierarchy
    
    Contract:
        - nodeId must not be null.
        
    See also:
        <isEmpty>
*/
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

/*
    Function: addNode
    
    Adds a an entity to the hierarchy as a new node.

    Parameters:
    
        - @nodeId id of the entity to add
        - @underNodeId id of the entity to add the node below. If -1, nodeId is attempted to be made a root.
    
    Contract:
    
        - a. nodeId must not be null
        - b. If nodeId is the same as underNodeId an exception is raised.
        - c. If underNodeId does not exist in the hierarchy, an exception is raised.
        - d. Node that already is in the hierarchy must be removed before it can be added again.
        - e. Adding a node as a root succeeds iff there are no other nodes in the hierarchy.
        
*/
CREATE OR REPLACE FUNCTION sequoia_alist.addNode(nodeId INT, underNodeId INT) 
RETURNS void AS 
$BODY$
BEGIN  
	
	-- Check for rule a.
	IF (nodeId = -1 OR nodeId IS NULL) THEN
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
			
	-- root node will point to itself via the parent link
        IF underNodeId = -1 THEN
            underNodeId := nodeId;
        END IF;
        
        -- insert the node into the hierarchy
	INSERT INTO sequoia_alist.Node(childId, parentId) 
	VALUES (nodeId, underNodeId);
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;


/*
    Function: isRoot
    
    Returns true iff the specified node is a root.

    Parameters:
    
        - @nodeId id of the sequoia.entity to check
    
    Contract:
    
        - a. nodeId must not be null.
    
    See also:
        <isLeaf>
*/
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
	WHERE (parentId = childId) AND
		  (childId = nodeId)
	LIMIT 1;
	
	RETURN FOUND;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: isLeaf
    
    Returns true iff the specified node is a leaf.

    Parameters:
    
        - @nodeId id of the sequoia.entity to check
    
    Contract:
    
        - a. nodeId must not be null.
    
    See also:
        <isRoot>
*/
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
	WHERE (parentId = nodeId) AND
              (parentId <> childId)
	LIMIT 1;
	
	RETURN NOT FOUND;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: depth
    
    Returns the depth of the node in the tree.

    Parameters:
    
        - @nodeId id of the sequoia.entity to calculate depth for
    
    Contract:
    
        - a. nodeId must not be null.
        - b. nodeId must be in the hierarchy.
    
    See also:
        <pathToRoot>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.depth(nodeId INT) RETURNS int AS 
$BODY$
DECLARE currentNodeId INT;
        nodeDepth INT;
BEGIN
	
	RETURN (SELECT COUNT(*) FROM sequoia_alist.pathToRoot(nodeId)) - 1 ;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: pathToRoot
    
    Returns a setof nodes on the path to the root (both ends of the path are included).

    Parameters:
    
        - nodeId id of the sequoia.entity to calculate path for
    
    Contract:
    
        - a. nodeId must not be null.
        - b. nodeId must be in the hierarchy.
    
    See also:
        <depth>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.pathToRoot(nodeId INT)
 RETURNS SETOF INT AS
 $BODY$
DECLARE currentNodeId INT;
        nodeDepth INT;
BEGIN
	IF (nodeId IS NULL) THEN
		RAISE EXCEPTION 'nodeId must not be null.';
	END IF;
	
        IF (NOT sequoia_alist.contains(nodeId)) THEN
		RAISE EXCEPTION 'nodeId(id: %) is not in the hierarchy.', nodeId;
	END IF;
	
        -- move up by parent links until we get into the root
        
        RETURN NEXT nodeId;        
        currentNodeId := nodeId;
        nodeDepth := 0;
        LOOP
        
            -- move up the link
            SELECT NULLIF(parentId, currentNodeId)
            INTO currentNodeId
            FROM sequoia_alist.Node
            WHERE childId = currentNodeId
            LIMIT 1;
            
            -- welcome in the root node
            IF (currentNodeId IS NULL) THEN
                RETURN;
            ELSE 
                RETURN NEXT currentNodeId;
            END IF;
        END LOOP;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: getRoot
    
    Returns the root of the hierarchy. If the hierarchy is empty null is returned.

    Parameters:
    
    Contract:
    
    See also:
*/
CREATE OR REPLACE FUNCTION sequoia_alist.getRoot()
RETURNS INT AS
$BODY$
BEGIN
    RETURN (SELECT parentId
            FROM sequoia_alist.Node
            WHERE parentId = childId
            LIMIT 1);
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: getParent
    
    Returns the parent node element's id. If the nodeId refers to the root of the hierarchy, NULL is returned.
    
    Parameters:
    
        - nodeId id of a sequoia.entity
        
    Contract:
    
        - a. nodeId must not be null.
        - b. nodeId must be in the hierarchy.
    See also:
*/
CREATE OR REPLACE FUNCTION sequoia_alist.getParent(nodeId INT)
RETURNS INT AS
$BODY$
BEGIN

    IF (nodeId IS NULL) THEN
            RAISE EXCEPTION 'nodeId must not be null.';
    END IF;
    
    IF (NOT sequoia_alist.contains(nodeId)) THEN
            RAISE EXCEPTION 'nodeId(id: %) is not in the hierarchy.', nodeId;
    END IF;

    RETURN (SELECT NULLIF(parentId,childId)
            FROM sequoia_alist.Node
            WHERE childId = nodeId
            LIMIT 1);
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: getParent
    
    Returns a setof element ids that are the direct children of the given node.
    
    Parameters:
    
        - nodeId id of a sequoia.entity
        
    Contract:
    
        - a. nodeId must not be null.
        - b. nodeId must be in the hierarchy.
    See also:
*/
CREATE OR REPLACE FUNCTION sequoia_alist.getChildren(nodeId INT)
RETURNS SETOF INT AS
$BODY$
BEGIN

    IF (nodeId IS NULL) THEN
            RAISE EXCEPTION 'nodeId must not be null.';
    END IF;
    
    IF (NOT sequoia_alist.contains(nodeId)) THEN
            RAISE EXCEPTION 'nodeId(id: %) is not in the hierarchy.', nodeId;
    END IF;

    RETURN QUERY (SELECT childId
            FROM sequoia_alist.Node
            WHERE parentId = nodeId AND
                  parentId <> childId);
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: swapNodes
    
    Swaps two nodes in the hierarchy. This operation does not move subtrees and is commutative.
    
    Parameters:
    
        - nodeId1 id of the second sequoia.entity
        - nodeId2 id of the second sequoia.entity
    Contract:
    
        - a. nodeId1/nodeId2 must not be null.
        - b. nodeId1/nodeId2 must be in the hierarchy.
        
    See also:
    
        <swapSubtrees>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.swapNodes(nodeId1 INT, nodeId2 INT)
RETURNS VOID AS
$BODY$
BEGIN

    IF (nodeId1 IS NULL) THEN
            RAISE EXCEPTION 'nodeId1 must not be null.';
    END IF;

    IF (nodeId2 IS NULL) THEN
            RAISE EXCEPTION 'nodeId2 must not be null.';
    END IF;
    
    IF (NOT sequoia_alist.contains(nodeId1)) THEN
            RAISE EXCEPTION 'nodeId1(id: %) is not in the hierarchy.', nodeId1;
    END IF;

    IF (NOT sequoia_alist.contains(nodeId2)) THEN
            RAISE EXCEPTION 'nodeId2(id: %) is not in the hierarchy.', nodeId2;
    END IF;

    -- update all ids that are nodeId1 to -2 temporarily
    UPDATE sequoia_alist.Node
    SET childId = -2
    WHERE childId = nodeId1;
    
    UPDATE sequoia_alist.Node
    SET parentId = -2
    WHERE parentId = nodeId1;
    
    -- update all ids that are nodeId2 to nodeId1
    UPDATE sequoia_alist.Node
    SET childId = nodeId1
    WHERE childId = nodeId2;
    
    UPDATE sequoia_alist.Node
    SET parentId = nodeId1
    WHERE parentId = nodeId2;
    
    -- update all ids that are -2 to nodeId2
    UPDATE sequoia_alist.Node
    SET childId = nodeId2
    WHERE childId = -2;
    
    UPDATE sequoia_alist.Node
    SET parentId = nodeId2
    WHERE parentId = -2;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;


/*
    Function: moveSubtree
    
    Takes a subtree below sourceNodeId (including the node sourceNodeId refers to) and moves it under targetNodeId. sourceNodeId becomes a new child of targetNodeId.
    
    Parameters:
    
        - sourceNodeId id of the second sequoia.entity
        - targetNodeId id of the second sequoia.entity
    Contract:
    
        - a. sourceNodeId/targetNodeId must not be null.
        - b. sourceNodeId/targetNodeId must be in the hierarchy.
        - c. sourceNodeId must not be on the path to root from targetNodeId (to avoid cycles).
        - d. if sourceNodeId = targetNodeId then no action is taken
        
    See also:
    
        <swapNodes>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.moveSubtree(sourceNodeId INT, targetNodeId INT)
RETURNS VOID AS
$BODY$
BEGIN

    IF (sourceNodeId IS NULL) THEN
        RAISE EXCEPTION 'nodeId1 must not be null.';
    END IF;

    IF (targetNodeId IS NULL) THEN
        RAISE EXCEPTION 'nodeId2 must not be null.';
    END IF;
    
    IF (NOT sequoia_alist.contains(sourceNodeId)) THEN
        RAISE EXCEPTION 'nodeId1(id: %) is not in the hierarchy.', sourceNodeId;
    END IF;

    IF (NOT sequoia_alist.contains(targetNodeId)) THEN
        RAISE EXCEPTION 'nodeId2(id: %) is not in the hierarchy.', targetNodeId;
    END IF;

    IF $1 = $2 THEN
        RETURN;
    END IF;
    
    -- check whether the operation would create a cycle
    IF (EXISTS(SELECT pathtoroot
               FROM sequoia_alist.pathtoroot(targetNodeId)
               WHERE sourceNodeId = pathtoroot
               LIMIT 1)) THEN
        RAISE EXCEPTION 'Cannot move subtree under a node to its own subtree.';
    END IF;
    
    -- update all parent links to a new parent
    UPDATE sequoia_alist.Node
    SET parentId = targetNodeId
    WHERE childId = sourceNodeId;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: removeLeafNode
    
    Removes a leaf node from the hierarchy.
    
    Parameters:
    
        - nodeId id of the sequoia.entity node to remove
        
    Contract:
    
        - a. nodeId must not be null.
        - b. nodeId must be in the hierarchy.
        - c. nodeId must be a leaf node.
        
    See also:
    
        <isLeaf>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.removeLeafNode(nodeId INT)
RETURNS VOID AS
$BODY$
BEGIN

    IF (nodeId IS NULL) THEN
        RAISE EXCEPTION 'nodeId must not be null.';
    END IF;

    IF (NOT sequoia_alist.contains(nodeId)) THEN
        RAISE EXCEPTION 'nodeId(id: %) is not in the hierarchy.', nodeId;
    END IF;

    IF (NOT sequoia_alist.isLeaf(nodeId)) THEN
        RAISE EXCEPTION 'nodeId(id: %) is not a leaf node.', nodeId;
    END IF;
    
    -- remove all links to the leaf node
    DELETE
    FROM sequoia_alist.Node
    WHERE parentId = nodeId OR
            childId = nodeId;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: subtreeNodes
    
    Gets a setof nodes from the subtree of the node refered to by nodeId (nodeId is not included in the result).
    
    Parameters:
    
        - nodeId id of the sequoia.entity node to remove
        
    Contract:
    
        - a. nodeId must not be null.
        - b. nodeId must be in the hierarchy.
        - c. This implementation guarantees that the nodes will appear in increasing order of depths.
    See also:
    
*/
CREATE OR REPLACE FUNCTION sequoia_alist.subtreeNodes(nodeId INT)
RETURNS SETOF INT AS
$BODY$
DECLARE
    updated BOOLEAN;
    rec RECORD;
    arr INT[];
    i INT;
    newItems INT := 0;
BEGIN
    CREATE TEMP TABLE queue(id INT);    
    INSERT INTO queue(id) VALUES (nodeId);
    
    LOOP
    
        newItems:=0;            
    
        -- add children of newly added parents to the queue (sadly cant be done with INSERT INTO... yet)    
        FOR rec IN (SELECT DISTINCT N.childId AS childId
                    FROM sequoia_alist.Node N
                    INNER JOIN queue Q on Q.id = N.parentId 
                    WHERE N.childId NOT IN (SELECT id FROM queue))
        LOOP
            newItems:=newItems+1;
            arr:=rec.childId||arr;
            RETURN NEXT rec.childId;    
        END LOOP;
        
        -- delete everything from queue 
        DELETE FROM queue;
        
        -- return new results        
        IF (newItems > 0) THEN
            FOR i IN 1 .. newItems
            LOOP
                INSERT INTO queue(id) VALUES (arr[i]);                
            END LOOP;
        ELSE 
            DROP TABLE queue;
            RETURN;        
        END IF;
        
    END LOOP;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: removeSubtree
    
    Removes a subtree of a node from the hierarchy. Root node is not removed.
    
    Parameters:
    
        - nodeId id of the sequoia.entity node to remove
        
    Contract:
    
        - a. nodeId must not be null.
        - b. nodeId must be in the hierarchy.
        
    See also:
    
        <removeLeafNode>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.removeSubtree(nodeId INT)
RETURNS VOID AS
$BODY$
BEGIN

    IF (nodeId IS NULL) THEN
        RAISE EXCEPTION 'nodeId must not be null.';
    END IF;

    IF (NOT sequoia_alist.contains(nodeId)) THEN
        RAISE EXCEPTION 'nodeId(id: %) is not in the hierarchy.', nodeId;
    END IF;

    -- remove the nodes from the subtree
    DELETE
    FROM sequoia_alist.Node N
    WHERE N.childId IN (SELECT sequoia_alist.subtreeNodes(nodeId)) OR
          N.parentId IN (SELECT sequoia_alist.subtreeNodes(nodeId));
    
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;



END TRANSACTION;


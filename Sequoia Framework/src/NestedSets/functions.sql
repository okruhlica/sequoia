/*
    Function: addNode
    
    Adds a an entity to the hierarchy as a new node.

    Parameters:
    
        - nodeId id of the entity to add
        - underNodeId id of the entity to add the node below. If -1, nodeId is attempted to be made a root.
    
    Contract:
    
        - a. nodeId must not be null
        - b. If nodeId is the same as underNodeId an exception is raised.
        - c. If underNodeId does not exist in the hierarchy, an exception is raised.
        - d. Node that already is in the hierarchy must be removed before it can be added again.
        - e. Adding a node as a root succeeds iff there are no other nodes in the hierarchy.
        
*/
CREATE OR REPLACE FUNCTION sequoia_ctable.addNode(nodeId INT, underNodeId INT) 
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
	IF ((underNodeId > 0) AND (NOT sequoia_ctable.contains(underNodeId))) THEN	
		RAISE EXCEPTION 'The underNode node (id: %) is not in the hierarchy.', underNodeId;
	END IF;
	
	-- Check for rule d.
	IF (sequoia_ctable.contains(nodeId)) THEN
		RAISE EXCEPTION 'This node (id: %) already is in the hierarchy.', nodeId;
	END IF;
			
                        
	-- root node
        IF (underNodeId = -1) THEN
            
            -- empty hierarchy = just add the node as a root
            IF ((SELECT sequoia_ctable.isEmpty())) THEN
                INSERT INTO ClosureTable(upper, lower, depth)
                VALUES (nodeId, nodeId, 0);
            ELSE
                RAISE EXCEPTION 'There already is a root. Consider using swapNodes function.';    
            END IF;
            
        ELSE
            -- copy the links from the parent and adjust them for the current node
            INSERT INTO ClosureTable(upper, lower,depth)
                SELECT upper, nodeId, depth+1
                FROM ClosureTable
                WHERE lower = underNodeId
                UNION
                SELECT nodeId, nodeId, 0;
        END IF;
        
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

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
CREATE OR REPLACE FUNCTION sequoia_ctable.contains(nodeId INT) RETURNS boolean AS 
$BODY$
DECLARE node INT;
BEGIN
	
	IF (nodeId IS NULL) THEN
		RAISE EXCEPTION 'nodeId must not be null.';
	END IF;
	
	SELECT *
        INTO node
	FROM sequoia_ctable.ClosureTable
	WHERE (upper = nodeId) OR
              (lower = nodeId)
	LIMIT 1;
	
	RETURN FOUND;
END;
$BODY$ LANGUAGE plpgsql VOLATILE;


/*
    Function: isEmpty
    
    Returns true iff there is no node is in the hierarchy.
    
    Parameters:
    
    See also:
        nodeCount
*/ 
CREATE OR REPLACE FUNCTION sequoia_ctable.isEmpty() RETURNS boolean AS 
$BODY$
DECLARE nodes INT;
BEGIN  
	SELECT COUNT(DISTINCT upper)
	INTO nodes
	FROM sequoia_ctable.ClosureTable;
	
	RETURN (nodes = 0);
END;
$BODY$ LANGUAGE plpgsql VOLATILE;


/*
    Function: isRoot
    
    Returns true iff the specified node is a root.

    Parameters:
    
        - nodeId id of the sequoia.entity to check
    
    Contract:
    
        - a. nodeId must not be null.
    
    See also:
        <isLeaf>
*/
CREATE OR REPLACE FUNCTION sequoia_ctable.isRoot(nodeId INT) RETURNS boolean AS 
$BODY$
DECLARE node INT;
BEGIN
	
	IF (nodeId IS NULL) THEN
		RAISE EXCEPTION 'nodeId must not be null.';
	END IF;
	
	SELECT * 
	INTO node
	FROM sequoia_ctable.ClosureTable
	WHERE (lower = nodeId) AND
              (lower <> upper)
	LIMIT 1;
	
	RETURN NOT FOUND;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: isLeaf
    
    Returns true iff the specified node is a leaf.

    Parameters:
    
        - nodeId id of the sequoia.entity to check
    
    Contract:
    
        - a. nodeId must not be null.
    
    See also:
        <isRoot>
*/
CREATE OR REPLACE FUNCTION sequoia_ctable.isLeaf(nodeId INT) RETURNS boolean AS 
$BODY$
DECLARE node INT;
        maskStr TEXT:='';
BEGIN
	
	IF (nodeId IS NULL) THEN
	    RAISE EXCEPTION 'nodeId must not be null.';
	END IF;
	
        SELECT upper
	INTO node
	FROM sequoia_ctable.ClosureTable
	WHERE upper = nodeId AND depth > 0
	LIMIT 1;
	
	RETURN NOT FOUND;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: depth
    
    Returns the depth of the node in the tree.

    Parameters:
    
        - nodeId id of the sequoia.entity to calculate depth for
    
    Contract:
    
        - a. nodeId must not be null.
        - b. nodeId must be in the hierarchy.
    
    See also:
        <pathToRoot>
*/
CREATE OR REPLACE FUNCTION sequoia_ctable.depth(nodeId INT) RETURNS int AS 
$BODY$
BEGIN
    IF (nodeId IS NULL) THEN
            RAISE EXCEPTION 'nodeId must not be null.';
    END IF;
    
    IF (NOT sequoia_ctable.contains(nodeId)) THEN
            RAISE EXCEPTION 'nodeId(id: %) is not in the hierarchy.', nodeId;
    END IF;
    
    RETURN (
        SELECT depth
        FROM sequoia_ctable.ClosureTable
        WHERE lower = nodeId
        ORDER BY depth DESC
        LIMIT 1
    );
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
CREATE OR REPLACE FUNCTION sequoia_ctable.getRoot()
RETURNS INT AS
$BODY$
BEGIN
    -- Root is the upper node from the deepest link.
    RETURN (SELECT upper
            FROM ClosureTable            
            ORDER BY depth DESC
            LIMIT 1);
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
CREATE OR REPLACE FUNCTION sequoia_ctable.pathToRoot(nodeId INT)
 RETURNS SETOF INT AS
 $BODY$
DECLARE currentNodeId INT;
        nodeDepth INT;
        rec RECORD;
BEGIN

    IF (nodeId IS NULL) THEN
            RAISE EXCEPTION 'nodeId must not be null.';
    END IF;
    
    IF (NOT sequoia_ctable.contains(nodeId)) THEN
            RAISE EXCEPTION 'nodeId(id: %) is not in the hierarchy.', nodeId;
    END IF;
    
    RETURN QUERY(
        SELECT upper
        FROM ClosureTable
        WHERE lower = nodeId
        ORDER BY depth ASC
    );
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
CREATE OR REPLACE FUNCTION sequoia_ctable.getParent(nodeId INT)
RETURNS INT AS
$BODY$
DECLARE arr text[];
        lineageSize INT;
BEGIN

    IF (nodeId IS NULL) THEN
            RAISE EXCEPTION 'nodeId must not be null.';
    END IF;
    
    IF (NOT sequoia_ctable.contains(nodeId)) THEN
            RAISE EXCEPTION 'nodeId(id: %) is not in the hierarchy.', nodeId;
    END IF;

    IF (sequoia_ctable.isRoot(nodeId)) THEN
        RETURN NULL;
    ELSE 
        RETURN (
            SELECT upper
            FROM ClosureTable
            WHERE (lower = nodeId) AND
                  (depth = 1)            
        );
    END IF;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: getChildren
    
    Returns a setof element ids that are the direct children of the given node.
    
    Parameters:
    
        - nodeId id of a sequoia.entity
        
    Contract:
    
        - a. nodeId must not be null.
        - b. nodeId must be in the hierarchy.
    See also:
*/
CREATE OR REPLACE FUNCTION sequoia_ctable.getChildren(nodeId INT)
RETURNS SETOF INT AS
$BODY$
DECLARE currentLineage TEXT;
        rec RECORD;
BEGIN

    IF (nodeId IS NULL) THEN
            RAISE EXCEPTION 'nodeId must not be null.';
    END IF;
    
    IF (NOT sequoia_ctable.contains(nodeId)) THEN
            RAISE EXCEPTION 'nodeId(id: %) is not in the hierarchy.', nodeId;
    END IF;

    RETURN QUERY(
        SELECT DISTINCT lower
        FROM ClosureTable
        WHERE (upper = nodeId) AND
              (depth = 1)
    );

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
CREATE OR REPLACE FUNCTION sequoia_ctable.swapNodes(nodeId1 INT, nodeId2 INT)
RETURNS VOID AS
$BODY$
DECLARE depth1 INT;
        depth2 INT;
        rootId INT;
BEGIN
    IF (nodeId1 IS NULL) THEN
            RAISE EXCEPTION 'nodeId1 must not be null.';
    END IF;

    IF (nodeId2 IS NULL) THEN
            RAISE EXCEPTION 'nodeId2 must not be null.';
    END IF;
    
    IF (NOT sequoia_ctable.contains(nodeId1)) THEN
            RAISE EXCEPTION 'nodeId1(id: %) is not in the hierarchy.', nodeId1;
    END IF;

    IF (NOT sequoia_ctable.contains(nodeId2)) THEN
            RAISE EXCEPTION 'nodeId2(id: %) is not in the hierarchy.', nodeId2;
    END IF;

    IF (nodeId1 = nodeId2) THEN
        RETURN;
    END IF;
    
    -- perform information swap
    UPDATE sequoia_ctable.ClosureTable
    SET upper = -2
    WHERE upper = nodeId1;
    
    UPDATE sequoia_ctable.ClosureTable
    SET lower = -2
    WHERE lower = nodeId1;
    
    UPDATE sequoia_ctable.ClosureTable
    SET upper = nodeId1
    WHERE upper = nodeId2;
    
    UPDATE sequoia_ctable.ClosureTable
    SET lower = nodeId1
    WHERE lower = nodeId2;
    
    UPDATE sequoia_ctable.ClosureTable
    SET upper = nodeId2
    WHERE upper = -2;
    
    UPDATE sequoia_ctable.ClosureTable
    SET lower = nodeId2
    WHERE lower = -2;
    
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
CREATE OR REPLACE FUNCTION sequoia_ctable.moveSubtree(sourceNodeId INT, targetNodeId INT)
RETURNS VOID AS
$BODY$
DECLARE depth1 INT;
        depth2 INT;
        rootId INT;
BEGIN

    IF (sourceNodeId IS NULL) THEN
        RAISE EXCEPTION 'nodeId1 must not be null.';
    END IF;

    IF (targetNodeId IS NULL) THEN
        RAISE EXCEPTION 'nodeId2 must not be null.';
    END IF;
    
    IF (NOT sequoia_ctable.contains(sourceNodeId)) THEN
        RAISE EXCEPTION 'nodeId1(id: %) is not in the hierarchy.', sourceNodeId;
    END IF;

    IF (NOT sequoia_ctable.contains(targetNodeId)) THEN
        RAISE EXCEPTION 'nodeId2(id: %) is not in the hierarchy.', targetNodeId;
    END IF;

    IF $1 = $2 THEN
        RETURN;
    END IF;
    
    -- calculate the depth deltas
    SELECT sequoia_ctable.getRoot()
    INTO rootId;
    
    SELECT depth
    INTO depth1
    FROM sequoia_ctable.ClosureTable
    WHERE upper = rootId AND
          lower = sourceNodeId;
    
    SELECT depth
    INTO depth2
    FROM sequoia_ctable.ClosureTable
    WHERE upper = rootId AND
          lower = targetNodeId;
    
    -- delete links leading to the subtree from above sourceNodeId
    DELETE
    FROM sequoia_ctable.ClosureTable
    WHERE lower IN (
        SELECT lower
        FROM sequoia_ctable.ClosureTable
        WHERE upper = sourceNodeId
    ) AND upper IN (
        SELECT upper
        FROM sequoia_ctable.ClosureTable
        WHERE lower =  sourceNodeId AND depth > 0
    );
    
    -- add new links by combining links to targetNodeId with those from sourceNodeId.
    INSERT
    INTO sequoia_ctable.ClosureTable(upper,lower,depth)
        SELECT DEST_LINKS.upper,
               SUBTREE_LINKS.lower,
               DEST_LINKS.depth + SUBTREE_LINKS.depth + 1
        FROM  sequoia_ctable.ClosureTable DEST_LINKS,
              sequoia_ctable.ClosureTable SUBTREE_LINKS
        WHERE DEST_LINKS.lower = targetNodeId AND
              SUBTREE_LINKS.upper = sourceNodeId;               
    
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
CREATE OR REPLACE FUNCTION sequoia_ctable.removeLeafNode(nodeId INT)
RETURNS VOID AS
$BODY$
BEGIN

    IF (nodeId IS NULL) THEN
        RAISE EXCEPTION 'nodeId must not be null.';
    END IF;

    IF (NOT sequoia_ctable.contains(nodeId)) THEN
        RAISE EXCEPTION 'nodeId(id: %) is not in the hierarchy.', nodeId;
    END IF;

    IF (NOT sequoia_ctable.isLeaf(nodeId)) THEN
        RAISE EXCEPTION 'nodeId(id: %) is not a leaf node.', nodeId;
    END IF;
    
    -- remove the leaf node
    DELETE
    FROM sequoia_ctable.ClosureTable
    WHERE lower = nodeId;

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
CREATE OR REPLACE FUNCTION sequoia_ctable.removeSubtree(nodeId INT)
RETURNS VOID AS
$BODY$
DECLARE nodeLineage TEXT;
BEGIN

    IF (nodeId IS NULL) THEN
        RAISE EXCEPTION 'nodeId must not be null.';
    END IF;

    IF (NOT sequoia_ctable.contains(nodeId)) THEN
        RAISE EXCEPTION 'nodeId(id: %) is not in the hierarchy.', nodeId;
    END IF;

    -- remove every link that has either end in the subtree below nodeId (except nodeId)    
    DELETE
    FROM sequoia_ctable.ClosureTable
    WHERE upper in 
    (
        SELECT lower
        FROM sequoia_ctable.ClosureTable
        WHERE upper = nodeId and depth > 0
    ) OR lower in (
        SELECT lower
        FROM sequoia_ctable.ClosureTable
        WHERE upper = nodeId and depth > 0
    );
        
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
CREATE OR REPLACE FUNCTION sequoia_ctable.subtreeNodes(nodeId INT)
RETURNS SETOF INT AS
$BODY$
DECLARE
    nodeLineage text;
BEGIN

    RETURN QUERY (
        SELECT lower
        FROM sequoia_ctable.ClosureTable
        WHERE upper = nodeId AND depth > 0
    );

END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: clear
    
    Removes all data about the current hierarchy.
    
    Parameters:
    
    Contract:
    
        - after applying this function, the result of isEmpty() will always be true.
        
    See also:
        removeNode
*/
CREATE OR REPLACE FUNCTION sequoia_ctable.clear()
RETURNS VOID AS
$BODY$
BEGIN

    DELETE
    FROM sequoia_ctable.ClosureTable;
    
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;


-- version 0.1 / october 2013
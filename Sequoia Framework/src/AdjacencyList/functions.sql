
/*
    Function: addNode
    
    Adds an entity to the hierarchy as a new node.

    Parameters:
    
        - nodeId id of the entity to add
        - underNodeId id of the entity to hang the new node below. If NULL (or -1), nodeId will become the root.
        
    Throws:
    
        - NULL_ARG - thrown if nodeId is negative or NULL.
        - BAD_NODE_POSITION - thrown if nodeId is the same node as underNodeId
        - MISSING_PARENT - thrown if underNodeId does not exist in the hierarchy.
        - DUPLICATE_ADD - thrown if nodeId already is in the hierarchy. 
        - MULTIPLE_ROOTS - thrown when trying to add a root node while one already exists in the hierarchy.
*/
CREATE OR REPLACE FUNCTION sequoia_alist.addNode(nodeId INT, underNodeId INT) 
RETURNS void AS 
$BODY$
DECLARE
    funcErrHeader TEXT;
BEGIN
        -- normalize arguments
        nodeId := COALESCE($1,-1);
        underNodeId := COALESCE($2,-1);
        
        funcErrHeader:= 'Error while running addNode(' || nodeId || ',' || underNodeId || ')';
        
        -- <CONTRACT CHECKING>                    
	IF nodeId < 0 THEN
		RAISE EXCEPTION USING                    
                    MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
                    HINT = 'nodeId must be a positive non-null integer.';
	END IF;
	
	IF nodeId = underNodeId THEN
		RAISE EXCEPTION USING                    
                    MESSAGE =  '[BAD_NODE_POSITION] in ' || funcErrHeader,
                    HINT = 'You can not hang a node under itself. That just makes no sense, dude.';
	END IF;

	IF underNodeId >= 0 AND
            (NOT sequoia_alist.contains(underNodeId)) THEN	
		RAISE EXCEPTION USING
                    MESSAGE = '[MISSING_PARENT] in ' || funcErrHeader,
                    HINT = 'The underNodeId node is not in the hierarchy. Add it first baby.';
	END IF;
	
	IF sequoia_alist.contains(nodeId) THEN
		RAISE EXCEPTION USING
                    MESSAGE = '[DUPLICATE_ADD] in ' || funcErrHeader,
                    HINT = 'This nodeId node already is in the hierarchy. Lets not overdo it. Once is enough.';
	END IF;	
        -- </CONTRACT CHECKING>
        	
        IF underNodeId = -1 THEN
                
            IF NOT (SELECT sequoia_alist.isEmpty()) THEN
                RAISE EXCEPTION USING
                    MESSAGE = '[MULTIPLE_ROOTS] in ' || funcErrHeader,
                    HINT = 'There already is a root. Consider adding the node as a leaf and using swapNodes function.';
            END IF;
            
            -- root node will point to itself via the parent link
            underNodeId := nodeId;            
        END IF;
        
        -- insert the node into the hierarchy
	INSERT INTO sequoia_alist.Node(childId, parentId) 
	VALUES (nodeId, underNodeId);
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: nodeCount
    
    Returns the count of nodes in the subtree rooted at nodeId node. The root node is included.

    Parameters:
    
        - nodeId the root node of the (sub)tree to count
        
    Throws:
    
        - NULL_ARG - thrown if nodeId is negative or NULL.
        - MISSING_NODE - thrown if nodeId is not present in the hierarchy.
*/
CREATE OR REPLACE FUNCTION sequoia_alist.nodeCount(nodeId INT) 
RETURNS INT AS 
$BODY$
DECLARE
    funcErrHeader TEXT;
BEGIN
        -- normalize arguments
        nodeId := COALESCE($1,-1);
        
        funcErrHeader:= 'Error while running nodeCount(' || nodeId || ')';
        
        -- <CONTRACT CHECKING>                    
	IF nodeId < 0 THEN
		RAISE EXCEPTION USING                    
                    MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
                    HINT = 'nodeId must be a positive non-null integer.';
	END IF;
	
	IF (NOT sequoia_alist.contains(nodeId)) THEN	
            RAISE EXCEPTION USING
                MESSAGE = '[MISSING_NODE] in ' || funcErrHeader,
                HINT = 'The root node is not in the hierarchy. Add it first and then we will talk.';
	END IF;	
        -- </CONTRACT CHECKING>
        	
        -- this probably cant be done any more efficently
        SELECT CAST(COUNT(*) AS INT)
        FROM sequoia_alist.subtreeNodes(nodeId);
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: contains
    
    Returns true iff the specified node is in a hierarchy.

    Parameters:
    
        - nodeId id of the entity to search for in the hierarchy
    
    Throws:
        
        - NULL_ARG - thrown if nodeId is negative or NULL.
        
    See also:
        <isEmpty>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.contains(nodeId INT) RETURNS boolean AS 
$BODY$
DECLARE
    node INT;
    funcErrHeader TEXT;
BEGIN
	nodeId := COALESCE($1,-1);
        funcErrHeader:= 'Error while running contains(' || nodeId || ')';
        
        -- <CONTRACT CHECKING>        
	IF nodeId < 0 THEN
		RAISE EXCEPTION USING                    
                    MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
                    HINT = 'nodeId must be a positive non-null integer.';
	END IF;        
	-- </CONTRACT CHECKING>
        
	SELECT *
        INTO node
	FROM sequoia_alist.Node
	WHERE (parentId = nodeId) OR
		  (childId = nodeId)
	LIMIT 1;
	
	RETURN FOUND;
END;
$BODY$ LANGUAGE plpgsql VOLATILE;


/*
    Function: isEmpty
    
    Returns true iff there is no node is in the hierarchy.
    
    Parameters:
    
    See also:
        <nodeCount>
*/ 
CREATE OR REPLACE FUNCTION sequoia_alist.isEmpty() RETURNS boolean AS 
$BODY$
BEGIN  
	RETURN (
            SELECT NOT EXISTS(
                SELECT entityId	
                FROM sequoia_alist.Node)
            );	
END;
$BODY$ LANGUAGE plpgsql VOLATILE;


/*
    Function: isRoot
    
    Returns true iff the specified node is the root of the hierarchy.

    Parameters:
    
        - nodeId id of the sequoia.entity to check
    
    Throws:
    
        - NULL_ARG - thrown if nodeId is negative or NULL.
    
    See also:
        <isLeaf>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.isRoot(nodeId INT) RETURNS boolean AS 
$BODY$
DECLARE node INT;
    funcErrHeader TEXT;
BEGIN
	nodeId := COALESCE($1,-1);
        funcErrHeader:= 'Error while running isRoot(' || nodeId || ')';
        
        -- <CONTRACT CHECKING>        
	IF nodeId < 0 THEN
		RAISE EXCEPTION USING                    
                    MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
                    HINT = 'nodeId must be a positive non-null integer.';
	END IF;        
	-- </CONTRACT CHECKING>
	
        RETURN (
            SELECT EXISTS(
                SELECT entityId	
                FROM sequoia_alist.Node
                WHERE childId = nodeId AND parentId = childId
                LIMIT 1
            )
        );
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: isLeaf
    
    Returns true iff the specified node is a leaf.

    Parameters:
    
        - nodeId id of the sequoia.entity to check
    
    Throws:
    
        - NULL_ARG - thrown if nodeId is negative or NULL.
    
    See also:
        <isRoot>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.isLeaf(nodeId INT) RETURNS boolean AS 
$BODY$
DECLARE node INT;
    funcErrHeader TEXT;
BEGIN
	nodeId := COALESCE($1,-1);
        funcErrHeader:= 'Error while running isLeaf(' || nodeId || ')';
        
        -- <CONTRACT CHECKING>        
	IF nodeId < 0 THEN
		RAISE EXCEPTION USING                    
                    MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
                    HINT = 'nodeId must be a positive non-null integer.';
	END IF;        
	-- </CONTRACT CHECKING>

        RETURN (
            SELECT NOT EXISTS(
                SELECT entityId	
                FROM sequoia_alist.Node
                WHERE parentId = nodeId AND parentId <> childId
                LIMIT 1
            )
        );        
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: depth
    
    Returns the depth of the node in the tree.

    Parameters:
    
        - nodeId id of the sequoia.entity to calculate depth for
    
    Thrown:
    
        - NULL_ARG - thrown if nodeId is negative or null.
        - NO_SUCH_NODE - thrown if nodeId is not in the hierarchy.
    
    See also:
        <pathToRoot>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.depth(nodeId INT) RETURNS int AS 
$BODY$
DECLARE currentNodeId INT;
        nodeDepth INT;
        funcErrHeader TEXT;
BEGIN
	nodeId := COALESCE($1,-1);
        funcErrHeader:= 'Error while running depth(' || nodeId || ')';
        
        -- <CONTRACT CHECKING>        
	IF nodeId < 0 THEN
		RAISE EXCEPTION USING                    
                    MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
                    HINT = 'nodeId must be a positive non-null integer.';
	END IF;        

	IF NOT sequoia_alist.contains(nodeId) THEN
		RAISE EXCEPTION USING                    
                    MESSAGE = '[NO_SUCH_NODE] in ' || funcErrHeader,
                    HINT = 'nodeId must already be in the hierarchy.';
	END IF;        
	-- </CONTRACT CHECKING>

	RETURN (
                SELECT COUNT(*)
                FROM sequoia_alist.pathToRoot(nodeId)
                ) - 1 ;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: getRoot
    
    Returns the root of the hierarchy. If the hierarchy is empty null is returned.

    Parameters:
    
    Thrown:
    
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
    Function: pathToRoot
    
    Returns a setof nodes on the path to the root (both ends of the path are included).

    Parameters:
    
        - nodeId id of the sequoia.entity to calculate path for
    
    Thrown:
    
        - NULL_ARG - thrown if nodeId is negative or null.
        - NO_SUCH_NODE - thrown if nodeId is not in the hierarchy.
    
    See also:
        <depth>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.pathToRoot(nodeId INT)
 RETURNS SETOF INT AS
 $BODY$
DECLARE currentNodeId INT;
        nodeDepth INT := 0;
        funcErrHeader TEXT;
BEGIN
	nodeId := COALESCE($1,-1);
        funcErrHeader:= 'Error while running pathToRoot(' || nodeId || ')';
        
        -- <CONTRACT CHECKING>        
	IF nodeId < 0 THEN
		RAISE EXCEPTION USING                    
                    MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
                    HINT = 'nodeId must be a positive non-null integer.';
	END IF;        

	IF NOT sequoia_alist.contains(nodeId) THEN
		RAISE EXCEPTION USING                    
                    MESSAGE = '[NO_SUCH_NODE] in ' || funcErrHeader,
                    HINT = 'nodeId must already be in the hierarchy.';
	END IF;        
	-- </CONTRACT CHECKING>

        -- move up by parent links until we get into the root
                
        currentNodeId := nodeId;
        WHILE currentNodeId IS NOT NULL LOOP
        
            RETURN NEXT currentNodeId;
            
            -- move up via parent link
            SELECT NULLIF(parentId, currentNodeId)
            INTO currentNodeId
            FROM sequoia_alist.Node
            WHERE childId = currentNodeId
            LIMIT 1;
            
            -- welcome to the root node
            IF currentNodeId IS NULL THEN
                RETURN;
            END IF;

        END LOOP;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: getParent
    
    Returns the parent node element's id. If the nodeId refers to the root of the hierarchy, NULL is returned.
    
    Parameters:
    
        - nodeId id of a sequoia.entity
        
    Contract:
    
        - NULL_ARG - thrown if nodeId is negative or null.
        - NO_SUCH_NODE - thrown if nodeId is not in the hierarchy.
        
    See also:
        <getChildren>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.getParent(nodeId INT)
RETURNS INT AS
$BODY$
DECLARE funcErrHeader TEXT;
BEGIN

    nodeId := COALESCE($1,-1);
    funcErrHeader:= 'Error while running getParent(' || nodeId || ')';
    
    -- <CONTRACT CHECKING>        
    IF nodeId < 0 THEN
            RAISE EXCEPTION USING                    
                MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
                HINT = 'nodeId must be a positive non-null integer.';
    END IF;        

    IF NOT sequoia_alist.contains(nodeId) THEN
            RAISE EXCEPTION USING                    
                MESSAGE = '[NO_SUCH_NODE] in ' || funcErrHeader,
                HINT = 'nodeId must already be in the hierarchy.';
    END IF;        
    -- </CONTRACT CHECKING>
        
    RETURN (
            SELECT NULLIF(parentId,childId)
            FROM sequoia_alist.Node
            WHERE childId = nodeId
            LIMIT 1
        );
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: getChildren
    
    Returns a setof element ids that are the direct children of the given node.
    
    Parameters:
    
        - nodeId id of a sequoia.entity
        
    Contract:
    
        - NULL_ARG - thrown if nodeId is negative or null.
        - NO_SUCH_NODE - thrown if nodeId is not in the hierarchy.
        
    See also:
        <getParent>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.getChildren(nodeId INT)
RETURNS SETOF INT AS
$BODY$
DECLARE funcErrHeader TEXT;
BEGIN

    nodeId := COALESCE($1,-1);
    funcErrHeader:= 'Error while running getChildren(' || nodeId || ')';
    
    -- <CONTRACT CHECKING>        
    IF nodeId < 0 THEN
            RAISE EXCEPTION USING                    
                MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
                HINT = 'nodeId must be a positive non-null integer.';
    END IF;        

    IF NOT sequoia_alist.contains(nodeId) THEN
            RAISE EXCEPTION USING                    
                MESSAGE = '[NO_SUCH_NODE] in ' || funcErrHeader,
                HINT = 'nodeId must already be in the hierarchy.';
    END IF;        
    -- </CONTRACT CHECKING>
    
    RETURN QUERY (
            SELECT childId
            FROM sequoia_alist.Node
            WHERE parentId = nodeId AND
                  childId <> nodeId
            );
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: swapNodes
    
    Swaps two nodes in the hierarchy. This operation does not move subtrees and is commutative.
    
    Parameters:
    
        - nodeId1 id of the first sequoia.entity
        - nodeId2 id of the second sequoia.entity
    Contract:
    
        - NULL_ARG - thrown if nodeId is negative or null.
        - NO_SUCH_NODE - thrown if nodeId is not in the hierarchy.
        
    See also:
    
        <swapSubtrees>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.swapNodes(nodeId1 INT, nodeId2 INT)
RETURNS VOID AS
$BODY$
DECLARE funcErrHeader TEXT;
BEGIN

    nodeId1 := COALESCE($1,-1);
    nodeId2 := COALESCE($2,-1);
    
    funcErrHeader:= 'Error while running swapNodes(' || nodeId1 || ',' || nodeId2 || ')';
    
     -- <CONTRACT CHECKING>        
    IF nodeId1 < 0  OR nodeId2 < 0 THEN
            RAISE EXCEPTION USING                    
                MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
                HINT = 'nodeIdX must be a positive non-null integers.';
    END IF;        

    IF NOT (sequoia_alist.contains(nodeId1) AND
            sequoia_alist.contains(nodeId2)) THEN
            RAISE EXCEPTION USING                    
                MESSAGE = '[NO_SUCH_NODE] in ' || funcErrHeader,
                HINT = 'nodeIdX must already be in the hierarchy.';
    END IF;        
    -- </CONTRACT CHECKING>
       
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

    Throws:
    
        - NULL_ARG - thrown if sourceNodeId or targetNodeId are negative or null.
        - NO_SUCH_NODE - thrown if either argument node is not in the hierarchy.
        - BAD_NODE_POSITION - thrown if sourceNodeId is on the path to root from targetNodeId. This is to prevent creating cycles.
    See also:
    
        <swapNodes>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.moveSubtree(sourceNodeId INT, targetNodeId INT)
RETURNS VOID AS
$BODY$
DECLARE funcErrHeader TEXT;
BEGIN

    sourceNodeId := COALESCE($1,-1);
    targetNodeId := COALESCE($2,-1);
    
    funcErrHeader:= 'Error while running swapNodes(' || sourceNodeId || ',' || targetNodeId || ')';

    -- trivial case
    IF sourceNodeId = targetNodeId THEN
        RETURN;
    END IF;   
        
     -- <CONTRACT CHECKING>        
    IF sourceNodeId < 0  OR sourceNodeId < 0 THEN
            RAISE EXCEPTION USING                    
                MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
                HINT = 'Both arguments must be positive non-null integers.';
    END IF;        

    IF NOT (sequoia_alist.contains(sourceNodeId) AND
            sequoia_alist.contains(targetNodeId)) THEN
            RAISE EXCEPTION USING                    
                MESSAGE = '[NO_SUCH_NODE] in ' || funcErrHeader,
                HINT = 'Both arguments must already be in the hierarchy.';
    END IF;        

    -- check whether the operation could create a cycle
    IF (EXISTS(
               SELECT pathtoroot
               FROM sequoia_alist.pathtoroot(targetNodeId)
               WHERE sourceNodeId = pathtoroot
               LIMIT 1)
               ) THEN
            RAISE EXCEPTION USING                    
                MESSAGE = '[BAD_NODE_POSITION] in ' || funcErrHeader,
                HINT = 'Can not move a tree under its own subtree. This would violate the tree condition.';
    END IF;
    -- </CONTRACT CHECKING>
    
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
    
        - NULL_ARG - thrown if nodeId is negative or null.
        - NO_SUCH_NODE - thrown if nodeId is not in the hierarchy.
        - BAD_NODE_POSITION - thrown if nodeId is not a leaf node.
        
    See also:
    
        <isLeaf>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.removeLeafNode(nodeId INT)
RETURNS VOID AS
$BODY$
DECLARE funcErrHeader TEXT;
BEGIN

    nodeId := COALESCE($1,-1);
    funcErrHeader:= 'Error while running removeLeafNode(' || nodeId || ')';
    
    -- <CONTRACT CHECKING>        
    IF nodeId < 0 THEN
        RAISE EXCEPTION USING                    
            MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
            HINT = 'nodeId must be a positive non-null integer.';
    END IF;        

    IF NOT sequoia_alist.contains(nodeId) THEN
        RAISE EXCEPTION USING                    
            MESSAGE = '[NO_SUCH_NODE] in ' || funcErrHeader,
            HINT = 'nodeId must already be in the hierarchy.';
    END IF;        
    
    IF (NOT sequoia_alist.isLeaf(nodeId)) THEN
        RAISE EXCEPTION USING                    
            MESSAGE = '[BAD_NODE_POSITION] in ' || funcErrHeader,
            HINT = 'The argument must be a leaf node.';
    END IF;
    -- </CONTRACT CHECKING>
    
    -- remove all links to the leaf node
    DELETE
    FROM sequoia_alist.Node
    WHERE parentId = nodeId OR
            childId = nodeId;
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;


/*
    Function: removeSubtree
    
    Removes a subtree of a node from the hierarchy. Root node is not removed.
    
    Parameters:
    
        - nodeId id of the sequoia.entity node to remove
        
    Throws:
    
        - NULL_ARG - thrown if nodeId is negative or null.
        - NO_SUCH_NODE - thrown if nodeId is not in the hierarchy.
        
    See also:
    
        <removeLeafNode>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.removeSubtree(nodeId INT)
RETURNS VOID AS
$BODY$
DECLARE funcErrHeader TEXT;
BEGIN

    nodeId := COALESCE($1,-1);
    funcErrHeader:= 'Error while running removeSubtree(' || nodeId || ')';
    
    -- <CONTRACT CHECKING>        
    IF nodeId < 0 THEN
        RAISE EXCEPTION USING                    
            MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
            HINT = 'nodeId must be a positive non-null integer.';
    END IF;        

    IF NOT sequoia_alist.contains(nodeId) THEN
        RAISE EXCEPTION USING                    
            MESSAGE = '[NO_SUCH_NODE] in ' || funcErrHeader,
            HINT = 'nodeId must already be in the hierarchy.';
    END IF;        
    -- </CONTRACT CHECKING>
    
    -- remove the nodes from the subtree
    DELETE
    FROM sequoia_alist.Node N
    WHERE N.childId IN (SELECT sequoia_alist.subtreeNodes(nodeId)) OR
          N.parentId IN (SELECT sequoia_alist.subtreeNodes(nodeId));
    
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;

/*
    Function: subtreeNodes
    
    Gets a setof nodes from the subtree of the node refered to by nodeId (nodeId is not included in the result).
    Nodes are guaranteed to appear in increasing order of depths measured from nodeId.
    
    Parameters:
    
        - nodeId - id of the sequoia.entity node to remove
        
    Throws:
    
        - NULL_ARG - thrown if nodeId is negative or null.
        - NO_SUCH_NODE - thrown if nodeId is not in the hierarchy.
        
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
DECLARE funcErrHeader TEXT;
BEGIN

    nodeId := COALESCE($1,-1);
    funcErrHeader:= 'Error while running subtreeNodes(' || nodeId || ')';
    
    -- <CONTRACT CHECKING>        
    IF nodeId < 0 THEN
        RAISE EXCEPTION USING                    
            MESSAGE = '[NULL_ARG] in ' || funcErrHeader,
            HINT = 'nodeId must be a positive non-null integer.';
    END IF;        

    IF NOT sequoia_alist.contains(nodeId) THEN
        RAISE EXCEPTION USING                    
            MESSAGE = '[NO_SUCH_NODE] in ' || funcErrHeader,
            HINT = 'nodeId must already be in the hierarchy.';
    END IF;        
    -- </CONTRACT CHECKING>
    
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
    Function: clear
    
    Removes all data about the current hierarchy. After applying this function, the result of isEmpty() will always be true.
    
    See also:
        <removeSubtree>
*/
CREATE OR REPLACE FUNCTION sequoia_alist.clear()
RETURNS VOID AS
$BODY$
BEGIN

    DELETE
    FROM sequoia_alist.node;
    
END;
$BODY$ 
LANGUAGE plpgsql VOLATILE;


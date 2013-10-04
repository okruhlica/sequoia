
CREATE OR REPLACE FUNCTION setupTest(entityCount INT) RETURNS SETOF text AS
$BODY$
BEGIN
	DROP SCHEMA testschema CASCADE;
        CREATE SCHEMA testschema;

	ALTER SEQUENCE sequoia.entity_entityid_seq RESTART WITH 1;
	DELETE FROM sequoia.entity;

	CREATE TABLE testschema.TestEntity (num INT) INHERITS(sequoia.entity);
        
	INSERT INTO testschema.TestEntity(num)
            SELECT generate_series(1,entityCount);

	SET search_path TO "sequoia,sequoia_alist,$user,public";
        SET search_path TO sequoia,sequoia_alist,public;
        
        IF sequoia.tableExists(CAST('logg' AS text)) THEN
            DROP TABLE logg;
        END IF;
        
	CREATE TEMP TABLE logg(id serial, name varchar(20), res boolean) ON COMMIT DELETE ROWS;
END;
$BODY$
LANGUAGE plpgsql VOLATILE;


CREATE OR REPLACE FUNCTION testTree1() RETURNS SETOF text AS
$BODY$
BEGIN
        PERFORM setupTest(6);

	-- we will use the adjacency list implementation for this test
	-- set search_path TO impl, testschema, public;
	-- the test start here
	PERFORM testTrue('isEmpty01',(SELECT isEmpty()));
	PERFORM testTrue('getRoot01',(SELECT getRoot() IS NULL));
        
	PERFORM addnode(1,NULL); -- set 1 as root
	PERFORM addNode(2,1);
	PERFORM addNode(3,2);
	PERFORM addNode(4,1);
	PERFORM contains(1);
        
        BEGIN -- exc[NULL_ARG]
            SELECT addNode(NULL, 2);
            PERFORM testTrue('addNode01_exc', false);
            EXCEPTION
                WHEN raise_exception THEN
                    PERFORM testTrue('addNode01_exc', true);
        END;

        BEGIN -- exc[BAD_NODE_POSITION]
            SELECT addNode(2, 2);
            PERFORM testTrue('addNode02_exc', false);
            EXCEPTION
                WHEN raise_exception THEN
                    PERFORM testTrue('addNode02_exc', true);
        END;
                
        BEGIN -- exc[MISSING_PARENT]
            SELECT addNode(6, 5);
            PERFORM testTrue('addNode03_exc', false);
            EXCEPTION
                WHEN raise_exception THEN
                    PERFORM testTrue('addNode03_exc', true);
        END;

        BEGIN -- exc[DUPLICATE_ADD]
            SELECT addNode(2, 4);
            PERFORM testTrue('addNode04_exc', false);
            EXCEPTION
                WHEN raise_exception THEN
                    PERFORM testTrue('addNode04_exc', true);
        END;

        BEGIN -- exc[MULTIPLE_ROOTS]
            SELECT addNode(2, NULL);
            PERFORM testTrue('addNode05_exc', false);
            EXCEPTION
                WHEN raise_exception THEN
                    PERFORM testTrue('addNode05_exc', true);
        END;
        
	-- contains function
	PERFORM testFalse('isEmpty02',(SELECT isEmpty()));
	PERFORM testTrue('contains01',(SELECT contains(1)));
        PERFORM testTrue('contains02',(SELECT contains(4)));
	PERFORM testFalse('contains03',(SELECT contains(5)));
	PERFORM testFalse('contains04',(SELECT contains(7)));
        
        BEGIN -- exc[NULL_ARG]
            SELECT contains(NULL);
            PERFORM testTrue('contains05_exc', false);
            EXCEPTION
                WHEN raise_exception THEN
                    PERFORM testTrue('contains05_exc', true);
        END;

        -- isRoot function
	PERFORM testTrue('isRoot01',(SELECT isroot(1)));
	PERFORM testFalse('isRoot02',(SELECT isroot(4)));

        -- isLeaf function
	PERFORM testFalse('isLeaf01',(SELECT isleaf(1)));
	PERFORM testFalse('isLeaf02',(SELECT isleaf(2)));
	PERFORM testTrue('isLeaf03',(SELECT isleaf(4)));

        -- depth function
        PERFORM testInt('depth01',(SELECT depth(1)), 0);
        PERFORM testInt('depth02',(SELECT depth(2)), 1);
        PERFORM testInt('depth03',(SELECT depth(3)), 2);
        PERFORM testInt('depth04',(SELECT depth(4)), 1);
        
        -- path to root function
        PERFORM testInt('pathToRoot01',(SELECT pathtoroot(4) LIMIT 1), 4);
        PERFORM testInt('pathToRoot02',(SELECT pathtoroot(4) LIMIT 1 OFFSET 1), 1);

        -- getRoot 
        PERFORM testInt('getRoot02',(SELECT getroot()), 1);

        -- getParent function
        PERFORM testTrue('getParent01',(SELECT getparent(1) IS NULL));

        PERFORM testInt('getParent02',(SELECT getparent(2)), 1);
        PERFORM testInt('getParent03',(SELECT getparent(3)), 2);       
        PERFORM testInt('getParent04',(SELECT getparent(4)), 1);

        -- swapNodes function
        PERFORM swapNodes(1,2);
        PERFORM testFalse('swapNodes01',(SELECT isroot(1)));
        PERFORM testTrue('swapNodes02',(SELECT isroot(2)));        
        PERFORM testTrue('swapNodes03',(SELECT getparent(2) IS NULL));
        PERFORM testInt('swapNodes04',(SELECT getparent(1)), 2);
        PERFORM testInt('swapNodes05',(SELECT getparent(3)), 1);
        
        PERFORM swapNodes(1,2);
        PERFORM testFalse('swapNodes06',(SELECT isroot(2)));
        PERFORM testTrue('swapNodes07',(SELECT isroot(1)));
        
        PERFORM swapNodes(3,2);
        PERFORM testInt('swapNodes08',(SELECT depth(2)), 2);
        PERFORM testInt('swapNodes09',(SELECT depth(3)),1);
        
        PERFORM swapNodes(1,1);
        PERFORM testInt('swapNodes10',(SELECT depth(1)),0);
        PERFORM swapNodes(3,2);


        -- getChildren function
        PERFORM testInt('getChildren01',(SELECT getchildren(1) AS X ORDER BY X ASC LIMIT 1), 2);
        PERFORM testInt('getChildren02',(SELECT getchildren(1) AS X  ORDER BY X ASC LIMIT 1 OFFSET 1), 4);
        PERFORM testInt('getChildren03',CAST((SELECT COUNT(*) FROM (SELECT getchildren(4)) AS X) AS INT) , 0);

        -- moveSubtree function
        PERFORM moveSubtree(3,1);
        PERFORM testInt('moveSubtree01', (SELECT depth(3)),1);
        PERFORM testInt('moveSubtree02', (SELECT CAST(COUNT(*) AS INT) FROM (SELECT getChildren(1)) AS X), 3);
        PERFORM testTrue('moveSubtree03',(SELECT isLeaf(3)));        
        PERFORM testTrue('moveSubtree04',(SELECT isLeaf(2)));
        PERFORM testInt('moveSubtree05',(SELECT depth(2)),1);
        
        PERFORM moveSubtree(3,2);
        PERFORM testInt('moveSubtree06',(SELECT depth(3)),2);
        PERFORM testInt('moveSubtree07',(SELECT CAST(COUNT(*) AS INT) FROM (SELECT getChildren(1)) AS X), 2);
        PERFORM testTrue('moveSubtree08',(SELECT isLeaf(3)));        
        PERFORM testFalse('moveSubtree09',(SELECT isLeaf(2)));
        PERFORM testInt('moveSubtree10',(SELECT depth(2)),1);
        
        PERFORM moveSubtree(1,1);
        PERFORM testInt('moveSubtree11',(SELECT depth(1)),0);
        
        PERFORM moveSubtree(2,4);
        PERFORM testInt('moveSubtree12',(SELECT depth(2)),2);
        PERFORM testInt('moveSubtree13',(SELECT CAST(COUNT(*) AS INT) FROM (SELECT getChildren(1)) AS X),1);
        PERFORM testInt('moveSubtree14',(SELECT CAST(COUNT(*) AS INT) FROM (SELECT getChildren(4)) AS X),1);
        PERFORM testInt('moveSubtree15',(SELECT CAST(COUNT(*) AS INT) FROM (SELECT getChildren(2)) AS X),1);
        PERFORM testFalse('moveSubtree16',(SELECT isLeaf(4)));                
        PERFORM testInt('moveSubtree17',(SELECT depth(3)),3);
        
        PERFORM moveSubtree(2,1);
        PERFORM testInt('moveSubtree18',(SELECT CAST(COUNT(*) AS INT) FROM (SELECT getChildren(1)) AS X),2);
        PERFORM testInt('moveSubtree19',(SELECT depth(2)), 1);
        PERFORM testTrue('moveSubtree20',(SELECT isleaf(4)));

      
        -- removeLeafNode function
        PERFORM removeLeafNode(3);
        PERFORM testInt('removeLeafNode01',(SELECT CAST(COUNT(*) AS INT) FROM (SELECT getChildren(2)) AS X),0);
        PERFORM testFalse('removeLeafNode02',(SELECT contains(3)));
        PERFORM testTrue('removeLeafNode03',(SELECT isLeaf(2)));
        
        PERFORM addNode(3,2);
        PERFORM testFalse('removeLeafNode04',(SELECT isLeaf(2)));
        PERFORM testTrue('removeLeafNode05',(SELECT isLeaf(3)));
        
        -- subtreeNodes function
        PERFORM testInt('subtreeNodes01',(SELECT CAST(COUNT(*) AS INT) FROM (SELECT subtreeNodes(1)) AS X), 3);
	PERFORM testInt('subtreeNodes02',(SELECT CAST(COUNT(*) AS INT) FROM (SELECT subtreeNodes(2)) AS X), 1);
	PERFORM testInt('subtreeNodes02',(SELECT CAST(COUNT(*) AS INT) FROM (SELECT subtreeNodes(3)) AS X), 0);

	-- removeSubtree function
	PERFORM removeSubtree(2);
	PERFORM testTrue('removeLeafNode01', (SELECT isleaf(2)));
	
	PERFORM removeSubtree(1);
	PERFORM testTrue('removeLeafNode02', (SELECT isleaf(1)));
        
        RETURN QUERY (
            SELECT CAST(name AS TEXT)
            FROM logg
            WHERE NOT res
        );
END;
$BODY$
LANGUAGE plpgsql VOLATILE;


CREATE OR REPLACE FUNCTION testTree2() RETURNS SETOF text AS
$BODY$
BEGIN
    RETURN;
END;
$BODY$
LANGUAGE plpgsql VOLATILE;

-- display the failed tests
SELECT *
FROM testTree1();

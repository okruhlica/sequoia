
	DROP SCHEMA testschema CASCADE;
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
	CREATE TEMP TABLE logg(id serial, name varchar(20), res boolean) ON COMMIT DELETE ROWS;

	-- we will use the adjacency list implementation for this test
	set search_path TO sequoia_mpath, testschema, public;

	-- the test start here
	INSERT INTO logg(name,res) VALUES ('isEmpty01',(SELECT isEmpty()));
	INSERT INTO logg(name,res) VALUES ('getRoot01',((SELECT getRoot()) IS NULL));
	SELECT addnode(1,-1); -- set 1 as root
	SELECT addNode(2,1);
	SELECT addNode(3,2);
	SELECT addNode(4,1);
	SELECT contains(1);

	-- contains function
	INSERT INTO logg(name,res) VALUES ('isEmpty02',NOT (SELECT isEmpty()));
	INSERT INTO logg(name,res) VALUES ('contains01',(SELECT contains(1)));
	INSERT INTO logg(name,res) VALUES ('contains02',(SELECT contains(4)));
	INSERT INTO logg(name,res) VALUES ('contains03',(SELECT NOT contains(5)));
	INSERT INTO logg(name,res) VALUES ('contains04',(SELECT NOT contains(7)));

        -- isRoot function	
	INSERT INTO logg(name,res) VALUES ('isRoot01',(SELECT isroot(1)));
	INSERT INTO logg(name,res) VALUES ('isRoot02',(SELECT NOT isroot(4)));

        -- isLeaf function
	INSERT INTO logg(name,res) VALUES ('isLeaf01',(SELECT NOT isleaf(1)));
	INSERT INTO logg(name,res) VALUES ('isLeaf02',(SELECT NOT isleaf(2)));
	INSERT INTO logg(name,res) VALUES ('isLeaf03',(SELECT isleaf(4)));

	--SELECT *, sequoia_mpath.depth(elId) FROM node;

        -- depth function
        INSERT INTO logg(name,res) VALUES ('depth01',((SELECT depth(1))=0));
        INSERT INTO logg(name,res) VALUES ('depth02',((SELECT depth(2))=1));
        INSERT INTO logg(name,res) VALUES ('depth03',((SELECT depth(3))=2));
        INSERT INTO logg(name,res) VALUES ('depth04',((SELECT depth(4))=1));
        -- INSERT INTO logg(name,res) VALUES ('depth05',((SELECT depth(6))=1));

        -- path to root function
        INSERT INTO logg(name,res) VALUES ('pathToRoot01',((SELECT pathtoroot(4) LIMIT 1) = 4));
        INSERT INTO logg(name,res) VALUES ('pathToRoot02',((SELECT pathtoroot(4) LIMIT 1 OFFSET 1) = 1));

        -- getRoot 
        INSERT INTO logg(name,res) VALUES ('getRoot02',((SELECT getroot()) = 1));

        -- getParent function
        INSERT INTO logg(name,res) VALUES ('getParent01',((SELECT getparent(1)) IS NULL));


        INSERT INTO logg(name,res) VALUES ('getParent02',((SELECT getparent(2)) = 1));
        INSERT INTO logg(name,res) VALUES ('getParent03',((SELECT getparent(3)) = 2));       
        INSERT INTO logg(name,res) VALUES ('getParent04',((SELECT getparent(4)) = 1));

        -- swapNodes function
        SELECT swapNodes(1,2);
        INSERT INTO logg(name,res) VALUES ('swapNodes01',(NOT (SELECT isroot(1))));
        INSERT INTO logg(name,res) VALUES ('swapNodes02',((SELECT isroot(2))));
        INSERT INTO logg(name,res) VALUES ('swapNodes03',((SELECT getparent(2)) IS NULL));
        INSERT INTO logg(name,res) VALUES ('swapNodes04',((SELECT getparent(1)) = 2));
        INSERT INTO logg(name,res) VALUES ('swapNodes05',((SELECT getparent(3)) = 1));
        SELECT swapNodes(1,2);
        INSERT INTO logg(name,res) VALUES ('swapNodes06',(NOT (SELECT isroot(2))));
        INSERT INTO logg(name,res) VALUES ('swapNodes07',((SELECT isroot(1))));
        SELECT swapNodes(3,2);
        INSERT INTO logg(name,res) VALUES ('swapNodes08',((SELECT depth(2))=2));
        INSERT INTO logg(name,res) VALUES ('swapNodes09',((SELECT depth(3))=1));
        SELECT swapNodes(1,1);
        INSERT INTO logg(name,res) VALUES ('swapNodes10',((SELECT depth(1))=0));
        SELECT swapNodes(3,2);


        -- getChildren function
        INSERT INTO logg(name,res) VALUES ('getChildren01',((SELECT getchildren(1) AS X ORDER BY X ASC LIMIT 1) = 2));
        INSERT INTO logg(name,res) VALUES ('getChildren02',((SELECT getchildren(1) AS X  ORDER BY X ASC LIMIT 1 OFFSET 1) = 4));
        INSERT INTO logg(name,res) VALUES ('getChildren03',(0=(SELECT COUNT(*) FROM (SELECT getchildren(4))AS X )));

        -- moveSubtree function
        SELECT moveSubtree(3,1);
        INSERT INTO logg(name,res) VALUES ('moveSubtree01',((SELECT depth(3))=1));
        INSERT INTO logg(name,res) VALUES ('moveSubtree02',((SELECT COUNT(*) FROM (SELECT getChildren(1)) AS X)=3));
        INSERT INTO logg(name,res) VALUES ('moveSubtree03',((SELECT isLeaf(3))));        
        INSERT INTO logg(name,res) VALUES ('moveSubtree04',((SELECT isLeaf(2))));
        INSERT INTO logg(name,res) VALUES ('moveSubtree05',((SELECT depth(2))=1));
        
        SELECT moveSubtree(3,2);
        INSERT INTO logg(name,res) VALUES ('moveSubtree06',((SELECT depth(3))=2));
        INSERT INTO logg(name,res) VALUES ('moveSubtree07',((SELECT COUNT(*) FROM (SELECT getChildren(1)) AS X)=2));
        INSERT INTO logg(name,res) VALUES ('moveSubtree08',((SELECT isLeaf(3))));        
        INSERT INTO logg(name,res) VALUES ('moveSubtree09',(NOT(SELECT isLeaf(2))));
        INSERT INTO logg(name,res) VALUES ('moveSubtree10',((SELECT depth(2))=1));
        
        SELECT moveSubtree(1,1);
        INSERT INTO logg(name,res) VALUES ('moveSubtree11',((SELECT depth(1))=0));
        
        SELECT moveSubtree(2,4);
        INSERT INTO logg(name,res) VALUES ('moveSubtree12',((SELECT depth(2))=2));
        INSERT INTO logg(name,res) VALUES ('moveSubtree13',((SELECT COUNT(*) FROM (SELECT getChildren(1)) AS X)=1));
        INSERT INTO logg(name,res) VALUES ('moveSubtree14',((SELECT COUNT(*) FROM (SELECT getChildren(4)) AS X)=1));
        INSERT INTO logg(name,res) VALUES ('moveSubtree15',((SELECT COUNT(*) FROM (SELECT getChildren(2)) AS X)=1));
        INSERT INTO logg(name,res) VALUES ('moveSubtree16',(NOT(SELECT isLeaf(4))));                
        INSERT INTO logg(name,res) VALUES ('moveSubtree17',((SELECT depth(3))=3));
        
        SELECT moveSubtree(2,1);
        INSERT INTO logg(name,res) VALUES ('moveSubtree18',((SELECT COUNT(*) FROM (SELECT getChildren(1)) AS X)=2));
        INSERT INTO logg(name,res) VALUES ('moveSubtree19',((SELECT depth(2))=1));
        INSERT INTO logg(name,res) VALUES ('moveSubtree20',((SELECT isleaf(4))));

      
        -- removeLeafNode function
        SELECT removeLeafNode(3);
        INSERT INTO logg(name,res) VALUES ('removeLeafNode01',((SELECT COUNT(*) FROM (SELECT getChildren(2)) AS X)=0));
        INSERT INTO logg(name,res) VALUES ('removeLeafNode02',(NOT (SELECT contains(3))));
        INSERT INTO logg(name,res) VALUES ('removeLeafNode03',((SELECT isLeaf(2))));
        SELECT addNode(3,2);
        INSERT INTO logg(name,res) VALUES ('removeLeafNode04',(NOT(SELECT isLeaf(2))));
        INSERT INTO logg(name,res) VALUES ('removeLeafNode05',((SELECT isLeaf(3))));
        
        -- subtreeNodes function
        INSERT INTO logg(name,res) VALUES ('subtreeNodes01',((SELECT COUNT(*) FROM (SELECT subtreeNodes(1)) AS X) = 3));
	INSERT INTO logg(name,res) VALUES ('subtreeNodes02',((SELECT COUNT(*) FROM (SELECT subtreeNodes(2)) AS X) = 1));
	INSERT INTO logg(name,res) VALUES ('subtreeNodes02',((SELECT COUNT(*) FROM (SELECT subtreeNodes(3)) AS X) = 0));

	-- removeSubtree function
	SELECT removeSubtree(2);
	INSERT INTO logg(name,res) VALUES ('removeLeafNode01', ((SELECT isleaf(2))));
	
	SELECT removeSubtree(1);
	INSERT INTO logg(name,res) VALUES ('removeLeafNode02', ((SELECT isleaf(1))));

-- display the failed tests
SELECT *
FROM(
SELECT * FROM logg) L
WHERE NOT L.res;

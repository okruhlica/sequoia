
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

	
	INSERT INTO logg(name,res) VALUES ('isEmpty01',(SELECT sequoia_alist.isEmpty()));
	INSERT INTO logg(name,res) VALUES ('getRoot01',((SELECT sequoia_alist.getroot()) IS NULL));
	SELECT sequoia_alist.addnode(1,-1); -- set 1 as root
	SELECT sequoia_alist.addNode(2,1);
	SELECT sequoia_alist.addNode(3,2);
	SELECT sequoia_alist.addNode(4,1);
	SELECT sequoia_alist.contains(1);

	-- contains function
	INSERT INTO logg(name,res) VALUES ('isEmpty02',NOT (SELECT sequoia_alist.isEmpty()));
	INSERT INTO logg(name,res) VALUES ('contains01',(SELECT sequoia_alist.contains(1)));
	INSERT INTO logg(name,res) VALUES ('contains02',(SELECT sequoia_alist.contains(4)));
	INSERT INTO logg(name,res) VALUES ('contains03',(SELECT NOT sequoia_alist.contains(5)));
	INSERT INTO logg(name,res) VALUES ('contains04',(SELECT NOT sequoia_alist.contains(7)));
        
        -- isRoot function	
	INSERT INTO logg(name,res) VALUES ('isRoot01',(SELECT sequoia_alist.isroot(1)));
	INSERT INTO logg(name,res) VALUES ('isRoot02',(SELECT NOT sequoia_alist.isroot(4)));

        -- isLeaf function
	INSERT INTO logg(name,res) VALUES ('isLeaf01',(SELECT NOT sequoia_alist.isleaf(1)));
	INSERT INTO logg(name,res) VALUES ('isLeaf02',(SELECT NOT sequoia_alist.isleaf(2)));
	INSERT INTO logg(name,res) VALUES ('isLeaf03',(SELECT sequoia_alist.isleaf(4)));

        -- depth function
        INSERT INTO logg(name,res) VALUES ('depth01',((SELECT sequoia_alist.depth(1))=0));
        INSERT INTO logg(name,res) VALUES ('depth02',((SELECT sequoia_alist.depth(2))=1));
        INSERT INTO logg(name,res) VALUES ('depth03',((SELECT sequoia_alist.depth(3))=2));
        INSERT INTO logg(name,res) VALUES ('depth04',((SELECT sequoia_alist.depth(4))=1));
        -- INSERT INTO logg(name,res) VALUES ('depth05',((SELECT sequoia_alist.depth(6))=1));

        -- path to root function
        INSERT INTO logg(name,res) VALUES ('pathToRoot01',((SELECT sequoia_alist.pathtoroot(4) LIMIT 1) = 4));
        INSERT INTO logg(name,res) VALUES ('pathToRoot02',((SELECT sequoia_alist.pathtoroot(4) LIMIT 1 OFFSET 1) = 1));
        
        -- getRoot 
        INSERT INTO logg(name,res) VALUES ('getRoot02',((SELECT sequoia_alist.getroot()) = 1));

        -- getParent function
        INSERT INTO logg(name,res) VALUES ('getParent01',((SELECT sequoia_alist.getparent(1)) IS NULL));
        INSERT INTO logg(name,res) VALUES ('getParent02',((SELECT sequoia_alist.getparent(2)) = 1));
        INSERT INTO logg(name,res) VALUES ('getParent03',((SELECT sequoia_alist.getparent(3)) = 2));
        INSERT INTO logg(name,res) VALUES ('getParent04',((SELECT sequoia_alist.getparent(4)) = 1));

        -- swapNodes function
        SELECT sequoia_alist.swapNodes(1,2);
        INSERT INTO logg(name,res) VALUES ('swapNodes01',(NOT (SELECT sequoia_alist.isroot(1))));
        INSERT INTO logg(name,res) VALUES ('swapNodes02',((SELECT sequoia_alist.isroot(2))));
        INSERT INTO logg(name,res) VALUES ('swapNodes03',((SELECT sequoia_alist.getparent(2)) IS NULL));
        INSERT INTO logg(name,res) VALUES ('swapNodes04',((SELECT sequoia_alist.getparent(1)) = 2));
        INSERT INTO logg(name,res) VALUES ('swapNodes05',((SELECT sequoia_alist.getparent(3)) = 1));
        SELECT sequoia_alist.swapNodes(1,2);
        INSERT INTO logg(name,res) VALUES ('swapNodes06',(NOT (SELECT sequoia_alist.isroot(2))));
        INSERT INTO logg(name,res) VALUES ('swapNodes07',((SELECT sequoia_alist.isroot(1))));
        SELECT sequoia_alist.swapNodes(3,2);
        INSERT INTO logg(name,res) VALUES ('swapNodes08',((SELECT sequoia_alist.depth(2))=2));
        INSERT INTO logg(name,res) VALUES ('swapNodes09',((SELECT sequoia_alist.depth(3))=1));
        SELECT sequoia_alist.swapNodes(1,1);
        INSERT INTO logg(name,res) VALUES ('swapNodes10',((SELECT sequoia_alist.depth(1))=0));
        SELECT sequoia_alist.swapNodes(3,2);
        
        -- getChildren function
        INSERT INTO logg(name,res) VALUES ('getChildren01',((SELECT sequoia_alist.getchildren(1) AS X ORDER BY X ASC LIMIT 1) = 2));
        INSERT INTO logg(name,res) VALUES ('getChildren02',((SELECT sequoia_alist.getchildren(1) AS X  ORDER BY X ASC LIMIT 1 OFFSET 1) = 4));
        INSERT INTO logg(name,res) VALUES ('getChildren03',((SELECT sequoia_alist.getchildren(4)) IS NULL));
        
        -- moveSubtree function
        SELECT sequoia_alist.moveSubtree(3,1);
        INSERT INTO logg(name,res) VALUES ('moveSubtree01',((SELECT sequoia_alist.depth(3))=1));
        INSERT INTO logg(name,res) VALUES ('moveSubtree02',((SELECT COUNT(*) FROM (SELECT sequoia_alist.getChildren(1)) AS X)=3));
        INSERT INTO logg(name,res) VALUES ('moveSubtree03',((SELECT sequoia_alist.isLeaf(3))));        
        INSERT INTO logg(name,res) VALUES ('moveSubtree04',((SELECT sequoia_alist.isLeaf(2))));
        INSERT INTO logg(name,res) VALUES ('moveSubtree05',((SELECT sequoia_alist.depth(2))=1));
        
        SELECT sequoia_alist.moveSubtree(3,2);
        INSERT INTO logg(name,res) VALUES ('moveSubtree06',((SELECT sequoia_alist.depth(3))=2));
        INSERT INTO logg(name,res) VALUES ('moveSubtree07',((SELECT COUNT(*) FROM (SELECT sequoia_alist.getChildren(1)) AS X)=2));
        INSERT INTO logg(name,res) VALUES ('moveSubtree08',((SELECT sequoia_alist.isLeaf(3))));        
        INSERT INTO logg(name,res) VALUES ('moveSubtree09',(NOT(SELECT sequoia_alist.isLeaf(2))));
        INSERT INTO logg(name,res) VALUES ('moveSubtree10',((SELECT sequoia_alist.depth(2))=1));
        
        SELECT sequoia_alist.moveSubtree(1,1);
        INSERT INTO logg(name,res) VALUES ('moveSubtree11',((SELECT sequoia_alist.depth(1))=0));
        
        SELECT sequoia_alist.moveSubtree(2,4);
        INSERT INTO logg(name,res) VALUES ('moveSubtree12',((SELECT sequoia_alist.depth(2))=2));
        INSERT INTO logg(name,res) VALUES ('moveSubtree13',((SELECT COUNT(*) FROM (SELECT sequoia_alist.getChildren(1)) AS X)=1));
        INSERT INTO logg(name,res) VALUES ('moveSubtree14',((SELECT COUNT(*) FROM (SELECT sequoia_alist.getChildren(4)) AS X)=1));
        INSERT INTO logg(name,res) VALUES ('moveSubtree15',((SELECT COUNT(*) FROM (SELECT sequoia_alist.getChildren(2)) AS X)=1));
        INSERT INTO logg(name,res) VALUES ('moveSubtree16',(NOT(SELECT sequoia_alist.isLeaf(4))));                
        INSERT INTO logg(name,res) VALUES ('moveSubtree17',((SELECT sequoia_alist.depth(3))=3));
        
        SELECT sequoia_alist.moveSubtree(2,1);
        INSERT INTO logg(name,res) VALUES ('moveSubtree18',((SELECT COUNT(*) FROM (SELECT sequoia_alist.getChildren(1)) AS X)=2));
        INSERT INTO logg(name,res) VALUES ('moveSubtree19',((SELECT sequoia_alist.depth(2))=1));
        INSERT INTO logg(name,res) VALUES ('moveSubtree20',((SELECT sequoia_alist.isleaf(4))));
        
        -- removeLeafNode function
        SELECT sequoia_alist.removeLeafNode(3);
        INSERT INTO logg(name,res) VALUES ('removeLeafNode01',((SELECT COUNT(*) FROM (SELECT sequoia_alist.getChildren(2)) AS X)=0));
        INSERT INTO logg(name,res) VALUES ('removeLeafNode02',(NOT (SELECT sequoia_alist.contains(3))));
        INSERT INTO logg(name,res) VALUES ('removeLeafNode03',((SELECT sequoia_alist.isLeaf(2))));
        SELECT sequoia_alist.addNode(3,2);
        INSERT INTO logg(name,res) VALUES ('removeLeafNode04',(NOT(SELECT sequoia_alist.isLeaf(2))));
        INSERT INTO logg(name,res) VALUES ('removeLeafNode05',((SELECT sequoia_alist.isLeaf(3))));
        
        -- subtreeNodes function
        INSERT INTO logg(name,res) VALUES ('subtreeNodes01',((SELECT COUNT(*) FROM (SELECT sequoia_alist.subtreeNodes(1)) AS X) = 4));
SELECT * FROM logg;

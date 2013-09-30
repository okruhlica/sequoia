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



-- Réaliser les différentes contraintes d'intégrité spécifiées dans le sujet du projet. 
-- Vous pouvez définir des contraintes statiques ou des contraintes dynamiques.

-- Un utilisateur aura un maximum de 300 vidéos en favoris.
CREATE OR REPLACE TRIGGER MaximumVideoFavoris
BEFORE INSERT OR UPDATE 
ON utilisateur_fav_video
FOR EACH ROW
DECLARE
	nb_video_favoris INTEGER := 0 ;
BEGIN
	SELECT count(*) INTO nb_video_favoris 
	FROM UTILISATEUR_FAV_VIDEO
	WHERE idUtilisateur = :new.idUtilisateur;

	IF nb_video_favoris = 300
	THEN 
		RAISE_APPLICATION_ERROR(-20104, 'Nombre maximal de videos en favoris est depasse.') ;
	END IF;
END; 



-- La suppression d’une vidéo entraînera son archivage dans une tables des vidéos qui ne sont 
-- plus accessibles par le site de replay.
CREATE OR REPLACE TRIGGER SupprimerDeVideo
BEFORE DELETE 
ON Video
FOR EACH ROW
DECLARE 
	video_non_expiree EXCEPTION;
	pragma exception_init(video_non_expiree, -20105);
BEGIN
	IF :OLD.dateExpiree <= SYSDATE 
	THEN 
		INSERT INTO Archivage (idArchive, nom, description, duree, dateSortie, dateExpiree,paysOrigin, multiLangue)
    	VALUES (:OLD.idVideo, :OLD.nom, :OLD.description, :OLD.duree, :OLD.dateSortie,:OLD.dateExpiree,:OLD.paysOrigin, :OLD.multiLangue);
		
    	UPDATE visionnage 
    	SET idArchive = :OLD.idVideo, idVideo = NULL
    	WHERE idVideo = :OLD.idVideo;
    	
    	UPDATE emission_episode  
    	SET idArchive = :OLD.idVideo, idVideo = NULL
    	WHERE idVideo = :OLD.idVideo;
    
    	UPDATE utilisateur_fav_video 
    	SET idArchive = :OLD.idVideo, idVideo = NULL
    	WHERE idVideo = :OLD.idVideo;
    	
    	UPDATE video_categorie
    	SET idArchive = :OLD.idVideo, idVideo = NULL
    	WHERE idVideo = :OLD.idVideo;

    ELSE
		RAISE_APPLICATION_ERROR(-20105, 'Erreur lors de la purge des vidéos expirées : La suppression de video est interdite, car elle n''est pas expiree.') ;
    END IF;
	
END;


-- Afin de limiter le spam de visionnage, un utilisateur ne pourra pas lancer plus de 3
-- visionnages par minutes.
CREATE OR REPLACE TRIGGER MaxNombreVisionnage
BEFORE INSERT
ON Visionnage
FOR EACH ROW
DECLARE
	nb_visionnage INTEGER := 0 ;
BEGIN
    SELECT COUNT(*)
    INTO nb_visionnage
    FROM Visionnage v
    WHERE v.idUtilisateur = :new.idUtilisateur
      AND v.dateVision BETWEEN (:new.dateVision - INTERVAL '1' MINUTE) AND :new.dateVision;

	IF nb_visionnage = 3
	THEN 
		RAISE_APPLICATION_ERROR(-20105, 'Un utilisateur ne pourra pas lancer plus de 3 visionnages par minutes');
	END IF;
	
END;



-- Declencheurs Supplémentaires -- 

-- Avant de l'ajout ou de la modification d'une vidéo archivée, vérifier que
-- (dateExpiree <= SYSDATE) OU ((dateSortie > SYSDATE) ET (dateExpiree > (dateSortie + 7))
--DROP TRIGGER MiseAJourArchivage;
CREATE OR REPLACE TRIGGER MiseAJourArchivage
BEFORE INSERT OR UPDATE
ON Archivage
FOR EACH ROW
BEGIN
    IF (:NEW.dateExpiree > SYSDATE) AND
       ((:NEW.dateSortie <= SYSDATE) OR (:NEW.dateExpiree <= (:NEW.dateSortie + 7))) THEN
        RAISE_APPLICATION_ERROR(-20106, 'La mise à jour ou l’ajout de vidéo archivée est interdite.');
    END IF;
END;




-- Lors de la suppression d’une vidéo archivée
-- si la (dateSortie = SYSDATE) ET (dateExpiree > (dateSortie + 7))
-- et on l’ajoute dans la table Video.
CREATE OR REPLACE TRIGGER SupprimerDeArchivage
BEFORE DELETE 
ON Archivage
FOR EACH ROW
DECLARE 
	video_non_disponible EXCEPTION; 
	pragma exception_init(video_non_disponible, -20107);
BEGIN
    IF (:OLD.dateSortie = SYSDATE) AND (:OLD.dateExpiree > (:OLD.dateSortie + 7)) THEN
        INSERT INTO Video (idVideo, nom, description, duree, dateSortie, dateExpiree, paysOrigin, multiLangue)
        VALUES (:OLD.idArchive, :OLD.nom, :OLD.description, :OLD.duree, :OLD.dateSortie, :OLD.dateExpiree, :OLD.paysOrigin, :OLD.multiLangue);
       		
    	UPDATE visionnage 
    	SET idVideo = :OLD.idArchive, idArchive = NULL
    	WHERE idArchive = :OLD.idArchive;
    	
    	UPDATE emission_episode  
    	SET idVideo = :OLD.idArchive, idArchive = NULL
    	WHERE idArchive = :OLD.idArchive;
    
    	UPDATE utilisateur_fav_video 
    	SET idVideo = :OLD.idArchive, idArchive = NULL
    	WHERE idArchive = :OLD.idArchive;
    	
    	UPDATE video_categorie
    	SET idVideo = :OLD.idArchive, idArchive = NULL
    	WHERE idArchive = :OLD.idArchive;
    ELSE
        RAISE_APPLICATION_ERROR(-20107, 'Erreur lors de rendre disponible des vidéos archivée: La suppression de vidéo archivée est interdite.');
    END IF;
END;


-- Avant de l’ajout ou de la modification d’un visionnage, dateVision <= SYSDATE
CREATE OR REPLACE TRIGGER MiseAJourVisionnage
BEFORE INSERT OR UPDATE
ON Visionnage
FOR EACH ROW
BEGIN
    IF :NEW.dateVision > SYSDATE THEN   
        RAISE_APPLICATION_ERROR(-20108, 'La date de visionnage ne peut pas être dans le futur.');
    END IF;
END;





-- Avant de l'ajout ou de la modification d'une vidéo
--	- Vérifier qu’après la sortie de la vidéo, elle sera accessible sur le site en replay 
--	  pendant au moins 7 jours
--		- dateExpiree > (dateSortie + 7)
--	- Vérifier que la date de sortie est plus petite ou égale à SYSDATE
--		- dateSortie <= SYSDATE
--		- sinon, on la supprimer (et la declencheur SupprimerDeVideo va en ajouter dans Archivage)
CREATE OR REPLACE TRIGGER MiseAJourVideo
BEFORE INSERT OR UPDATE
ON Video
FOR EACH ROW
BEGIN
    -- Vérifier que la dateExpiree est supérieure à dateSortie + 7 jours
    IF :NEW.dateExpiree <= :NEW.dateSortie + 7 THEN
        RAISE_APPLICATION_ERROR(-20109, 'La date d’expiration doit être au moins 7 jours après la date de sortie.');
    END IF;

    -- Vérifier que la dateSortie est inférieure ou égale à SYSDATE
    IF :NEW.dateSortie > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20110, 'La date de sortie ne peut pas être dans le futur. 
								Veuillez l''ajouter dans la table Archivage.');
    END IF;
END;


-- Mise A Jour de la table Emission

CREATE OR REPLACE TRIGGER MiseAJourEmission
AFTER UPDATE OF statut
ON Emission
FOR EACH ROW
BEGIN
  IF :NEW.statut = 'Archive' THEN 
    UPDATE Emission_Episode
    SET idVideo = NULL, 
        idArchive = (SELECT idArchive FROM Archivage WHERE idVideo = idVideo)
    WHERE idEmission = :NEW.idEmission;

  ELSIF :NEW.statut = 'Active' THEN 
    UPDATE Emission_Episode
    SET idVideo = (SELECT idVideo FROM Video WHERE idVideo = idVideo),
        idArchive = NULL
    WHERE idEmission = :NEW.idEmission;
  END IF;
END;

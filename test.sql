-- Un script permettant de tester les procédures/fonction/déclencheurs
SET SERVEROUTPUT ON;

-- Check --

SELECT object_name, object_type, status 
FROM user_objects
WHERE status = 'INVALID';

select * from USER_ERRORS 
where NAME = upper('MISEAJOURARCHIVAGE') 
and TYPE = 'TRIGGER';


-- Tester le déclencheur MaximumVideoFavoris
BEGIN
    -- Initialiser la variable avec la valeur de la séquence

    -- Ajouter un utilisateur
    INSERT INTO Utilisateur 
    VALUES (12, 'testUser', 'testUser', 'testUser', 'testUser', sysdate, 'testUser@gmail.com', SYSDATE, 'Y', 'France');

    FOR i IN 33..333 LOOP
        INSERT INTO Video VALUES (i, 'A fake movie ...', 'FakeMovie', 123, TO_DATE('2024-01-06', 'YYYY-MM-DD'), TO_DATE('2025-11-30', 'YYYY-MM-DD'), 'USA', 'Y', 'Movie');
        INSERT INTO UTILISATEUR_FAV_VIDEO VALUES (12, i, NULL);
    END LOOP;

    -- Essayer d'ajouter une 301ème vidéo, cela doit échouer
    INSERT INTO UTILISATEUR_FAV_VIDEO VALUES (12, 301, NULL);

END;


-- Tester le déclencheur SupprimerDeVideo
DECLARE 
	video_nom varchar(512) ;
	video_description varchar(512) ;
BEGIN
    -- Ajouter une vidéo expirée
    INSERT INTO Video VALUES (33, 'A fake movie ...', 'FakeMovie', 123, TO_DATE('2024-01-06', 'YYYY-MM-DD'), sysdate-1, 'USA', 'Y', 'Movie');

	-- Supprimer une vidéo expirée (devrait être archivée)
    DELETE FROM Video WHERE idVideo = 33;

    -- Vérifier si la vidéo est dans la table Archivage
	SELECT nom, description 
	INTO video_nom, video_description 
	FROM Archivage 
	WHERE idArchive = 33;
	   
    DBMS_OUTPUT.PUT_LINE('Informations de la vidéo archivée : ' || video_nom || video_description);

    -- Ajouter une vidéo non expirée
    INSERT INTO Video VALUES (34, 'A fake movie ...', 'FakeMovie', 123, TO_DATE('2024-01-06', 'YYYY-MM-DD'), TO_DATE('2026-11-30', 'YYYY-MM-DD'), 'USA', 'Y', 'Movie');

    -- Essayer de supprimer une vidéo non expirée (devrait échouer)
    DELETE FROM Video WHERE idVideo = 34;
END;


-- Tester le déclencheur MaxNombreVisionnage
BEGIN
    -- Ajouter un utilisateur
    INSERT INTO Utilisateur 
    VALUES (12, 'testUser', 'testUser', 'testUser', 'testUser', sysdate, 'testUser@gmail.com', SYSDATE, 'Y', 'France');

    -- Ajouter 3 visionnages dans une minute
    FOR i IN 1..3 LOOP  
     	INSERT INTO Visionnage VALUES (i+20, i, NULL, 12, SYSDATE);
    END LOOP;

    -- Essayer d'ajouter un 4ème visionnage dans la même minute (devrait échouer)
    INSERT INTO Visionnage VALUES (24, 7, NULL, 12, SYSDATE);
END;


-- Tester le déclencheur MiseAJourArchivage
BEGIN 
    -- Essayer d'ajouter une vidéo archivée avec des dates non valides (devrait échouer)
	INSERT INTO Archivage VALUES (27, 'Vidéo non valide', '...',  53, SYSDATE, SYSDATE + 1, 'USA', 'Y', 'Episode');

END;


-- Tester le déclencheur SupprimerDeArchivage 
DECLARE 
	video_nom varchar(512);
	video_description varchar(512);
BEGIN
    -- Ajouter une vidéo archivée conforme
  	INSERT INTO Archivage VALUES (27, 'Vidéo archivée conforme', '...',  53, SYSDATE-7, SYSDATE, 'USA', 'Y', 'Episode'); 
  	-- Supprimer une vidéo archivée avec des conditions valides (doit être ajoutée à Video)
    DELETE FROM Archivage WHERE idArchive = 27;

    -- Vérifier si la vidéo a été ajoutée à la table Video
   	SELECT nom, description 
	INTO video_nom, video_description 
    FROM Video 
   	WHERE idVideo = 27;
   
    DBMS_OUTPUT.PUT_LINE('Informations de la vidéo: ' || video_nom || video_description);

END;


-- Tester le déclencheur MiseAJourVisionnage
BEGIN
    -- Ajouter un visionnage avec une date valide
    INSERT INTO Visionnage VALUES (21, 23, NULL, 11, SYSDATE - 1);

    -- Essayer d'ajouter un visionnage avec une date future (devrait échouer)
    INSERT INTO Visionnage VALUES (22, 23, NULL, 11, SYSDATE + 1);

END;


-- Tester le déclencheur MiseAJourVideo
BEGIN
    -- Ajouter une vidéo avec une date de sortie et une durée valide
    INSERT INTO Video VALUES (33, 'Vidéo valide', 'Vidéo valide', 111, SYSDATE - 10, SYSDATE + 10, 'USA', 'Y', 'Movie');

    -- Essayer d'ajouter une vidéo avec une date future (devrait échouer)
    INSERT INTO Video VALUES (34, 'Vidéo invalide', 'Vidéo valide', 111, SYSDATE + 1, SYSDATE + 10, 'USA', 'Y', 'Movie');
END; 


-- Test de la fonction convert_json
SELECT a.id, convert_json(a.id) AS video_json
FROM AllVideos a
WHERE a.id IN (1, 2, 3);

SELECT convert_json(1) AS video_json FROM DUAL;


-- Test de la procédure generate_newsletter
BEGIN
    generate_newsletter(2);
END;

BEGIN
    generate_newsletter(1);
END;


-- Test de la fonction video_recommande
DECLARE
    l_resultat CLOB;
BEGIN
    l_resultat := video_recommande(1); -- Remplacez 1 par l'ID utilisateur à tester
    DBMS_OUTPUT.PUT_LINE(l_resultat);
END;


-- Test de la procédure checkDateExpiree
BEGIN
    checkDateExpiree;
END;

-- Test de la procédure checkDateSortie
BEGIN
    checkDateSortie;
END;

-- Test de la procédure newsletterAutoGenerator
BEGIN
    newsletterAutoGenerator;
END;

-- Test de la procédure nouveauxEpisodes
BEGIN
    nouveauxEpisodes(1);
END;

-- Test des tâches automatiques
BEGIN
    DBMS_SCHEDULER.RUN_JOB('purge_videos_expirees');
    DBMS_SCHEDULER.RUN_JOB('purge_videos_sorties');
    DBMS_SCHEDULER.RUN_JOB('newsletter_auto_generator');
END;

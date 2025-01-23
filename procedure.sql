-- Procédures et fonctions PL/SQL --


--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- 1. Définir une fonction qui convertit au format json les informations d’une vidéo.
CREATE OR REPLACE FUNCTION convert_json(n IN AllVideos.id%TYPE)
RETURN CLOB
IS
    v_string CLOB;
BEGIN
    -- Vérifier l'existence de la vidéo
    BEGIN
        SELECT json_object(
                   'id'          VALUE id,
                   'nom'         VALUE nom,
                   'description' VALUE description,
                   'duree'       VALUE duree,
                   'dateSortie'  VALUE dateSortie,
                   'paysOrigin'  VALUE paysOrigin,
                   'multiLangue' VALUE multiLangue,
                   'dateExpiree' VALUE dateExpiree,
                   'statut'      VALUE statut
               RETURNING CLOB) 
        INTO v_string
        FROM AllVideos
        WHERE id = n;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'Erreur : Vidéo non trouvée.';
    END;

    RETURN v_string;

EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Erreur inattendue : ' || SQLERRM;
END;
	

SELECT a.id, convert_json(a.id) AS video_json
FROM AllVideos a
WHERE a.id IN (1, 2, 3);

SELECT convert_json(1) AS video_json FROM DUAL;

--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- 2. Définir une procédure qui généra un texte initial de la newsletter en y ajoutant la
--    liste de toutes les sorties de la semaine.
CREATE OR REPLACE PROCEDURE generate_newsletter(id IN Utilisateur.idUtilisateur%TYPE) 
IS
	v_abonnement Char(1);
BEGIN
	SAVEPOINT newsletter_start;
	DBMS_OUTPUT.ENABLE;
	DBMS_OUTPUT.PUT_LINE('======= Newsletter de la semaine =======' || CHR(10) || 
	                       'Toutes les sorties de la semaine en cours: ' || CHR(10));
	
	-- check if the user subscribe the newsletter or not
	SELECT abonnement INTO v_abonnement 
	FROM utilisateur
	WHERE idUtilisateur = id
	FOR UPDATE; -- Si des mises à jour de l'abonnement peuvent se produire pendant la génération de newsletter

	IF v_abonnement = 'N' THEN
		DBMS_OUTPUT.PUT_LINE('Erreur lors de la génération de la newsletter : Utilisateur non abonné.');
		RETURN;
	END IF;
	

	FOR sortie_r IN (
	  SELECT 
	      video.nom AS video_nom, 
	      video.description, 
	      video.duree, 
	      video.paysOrigin, 
	      video.multiLangue,
	      categorie.nom AS categorie_nom
	  FROM 
	      video 
	      JOIN video_categorie vc ON video.idVideo = vc.idVideo
	      JOIN categorie ON vc.idCategorie = categorie.idCategorie
	  WHERE 
	  	  video.dateSortie >= sysdate - 7
	  ) 
	LOOP
	 	DBMS_OUTPUT.PUT_LINE(' - Titre: ' || sortie_r.video_nom || CHR(10) || 
	                       '   Description: ' || sortie_r.description || CHR(10) || 
	                       '   Durée: ' || sortie_r.duree || ' min' || CHR(10) || 
	                       '   Pays d''origine: ' || sortie_r.paysOrigin || CHR(10) || 
	                       '   MultiLangue: ' || sortie_r.multiLangue || CHR(10) ||
	                       '   Catégorie: ' || sortie_r.categorie_nom || CHR(10));
	END LOOP;

	COMMIT;

	EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
        	DBMS_OUTPUT.PUT_LINE('Erreur inattendue : ' || SQLERRM);
END;


--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- 3. Générer la liste des vidéos populaires, conseillé pour un utilisateur, c’est à dire
--    fonction des catégories de vidéos qu’il suit. La popularité sera basée sur le nombre 
--    de visionnages au cours des deux dernières semaines
CREATE OR REPLACE FUNCTION video_recommande(p_id_utilisateur IN utilisateur.IDUTILISATEUR%TYPE)
RETURN CLOB
IS
    v_utilisateur_a_categorie INTEGER;
   	v_nb_videos INTEGER;
    v_result CLOB;
BEGIN
	SAVEPOINT video_recommande_start;

	SELECT COUNT(*) INTO v_utilisateur_a_categorie
    FROM utilisateur_aime_categorie
    WHERE idUtilisateur = p_id_utilisateur;


    IF v_utilisateur_a_categorie = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Aucun catégorie : Utilisateur non abonné à des catégories.');
        RETURN v_result;
    END IF;

    FOR row_cat IN (
    	SELECT uac.idCategorie, c.nom 
        FROM utilisateur_aime_categorie uac
        JOIN categorie c ON c.idCategorie = uac.idCategorie
        WHERE idUtilisateur = p_id_utilisateur
    )
    LOOP
        v_result := v_result || 'Catégorie: ' || row_cat.nom || CHR(10);
       
       	SELECT COUNT(*) INTO v_nb_videos
        FROM video v
        INNER JOIN visionnage vi ON v.idVideo = vi.idVideo
        INNER JOIN video_categorie vc ON v.idVideo = vc.idVideo
        WHERE vc.idCategorie = row_cat.idCategorie 
          AND vi.dateVision >= SYSDATE - 14;

        IF v_nb_videos > 0 THEN 
		        FOR row_video IN (
		            SELECT 
		                v.nom AS video_nom, 
		                v.description, 
		                v.duree, 
		                v.paysOrigin, 
		                v.multiLangue
		            FROM 
		                video v
		            INNER JOIN visionnage vi ON v.idVideo = vi.idVideo
		            INNER JOIN video_categorie vc ON v.idVideo = vc.idVideo
		            WHERE 
		                vc.idCategorie = row_cat.idCategorie 
		                AND vi.dateVision >= SYSDATE - 14
		            GROUP BY 
		                v.nom, v.description, v.duree, v.paysOrigin, v.multiLangue
		            ORDER BY 
		                COUNT(vi.idVisionnage) DESC
		            FETCH FIRST 5 ROWS ONLY
		        )
		        
		        LOOP
		            v_result := v_result || '   - Titre: ' || row_video.video_nom || CHR(10) ||
		                      '     Description: ' || row_video.description || CHR(10) ||
		                      '     Durée: ' || row_video.duree || ' min' || CHR(10) ||
		                      '     Pays d''origine: ' || row_video.paysOrigin || CHR(10) ||
		                      '     MultiLangue: ' || row_video.multiLangue || CHR(10) || CHR(10);
		        END LOOP; 
	       ELSE 
	   	   		v_result := v_result || '    Aucune vidéo disponible pour cette catégorie.' || CHR(10) || CHR(10);
       	   END IF;
   
		END LOOP;
	   
    RETURN v_result;

	EXCEPTION
	    WHEN OTHERS THEN
			ROLLBACK TO video_recommande_start;
        	DBMS_OUTPUT.PUT_LINE('Erreur inattendue : ' || SQLERRM);

END;


DECLARE
    l_resultat CLOB;
BEGIN
    l_resultat := video_recommande(1); -- Remplacez 1 par l'ID utilisateur à tester
    DBMS_OUTPUT.PUT_LINE(l_resultat);
END;




-- Procédures Supplémentaires -- 

--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- Créer une tâche automatique quotidienne de purge et d'archivage des vidéos expirées.
CREATE OR REPLACE PROCEDURE checkDateExpiree 
IS
BEGIN
	-- Cette procédure suit le déclencheur SupprimerDeVideo qui ajoute la vidéo supprimée à la table Archive. 
    SAVEPOINT checkDateExpiree;
   
	DELETE FROM Video WHERE dateExpiree <= SYSDATE;

	COMMIT;

	EXCEPTION
	    WHEN OTHERS THEN
			ROLLBACK;
        	DBMS_OUTPUT.PUT_LINE('Erreur inattendue : ' || SQLERRM);

END;


BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'purge_videos_expirees', 
        job_type        => 'PLSQL_BLOCK',         
        job_action      => 'BEGIN checkDateExpiree; END;',
        start_date      => SYSTIMESTAMP,            
        repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=0; BYSECOND=0', 
        enabled         => TRUE                     
    );
END;


--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- Créer une tâche automatique quotidienne pour rendre disponibles les vidéos dont la date 
-- de sortie est aujourd'hui.
CREATE OR REPLACE PROCEDURE checkDateSortie 
IS
BEGIN
	-- Cette procédure suit le déclencheur SupprimerDeArchivage qui ajoute la vidéo supprimée à la table Vidéo. 
    SAVEPOINT checkDateSortie_start;
   
	DELETE FROM Archivage WHERE dateSortie = SYSDATE;
	
	COMMIT;

	EXCEPTION
	    WHEN OTHERS THEN
			ROLLBACK;
        	DBMS_OUTPUT.PUT_LINE('Erreur inattendue : ' || SQLERRM);

END;


BEGIN

    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'purge_videos_sorties', -- Nom de la tâche
        job_type        => 'PLSQL_BLOCK',           -- Type de tâche
        job_action      => 'BEGIN checkDateSortie; END;', -- Appel de procédure
        start_date      => SYSTIMESTAMP,            -- Date et heure de début
        repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=0; BYSECOND=0', -- Exécution quotidienne à minuit
        enabled         => TRUE                     -- Activation immédiate
    );

END;


--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- Créer une tâche automatique pour générer une newsletter pour l'utilisateur abonné chaque semaine.
CREATE OR REPLACE PROCEDURE newsletterAutoGenerator 
IS
BEGIN

    FOR row_user IN (SELECT idUtilisateur 
		FROM Utilisateur
		WHERE abonnement = 'Y')
    LOOP
    	generate_newsletter(row_user.idUtilisateur);
    END LOOP;
    
END; 


BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'newsletter_auto_generator',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN newsletterAutoGenerator; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=WEEKLY; BYHOUR=0; BYMINUTE=0; BYSECOND=0', 
        enabled         => TRUE                     
    );
END;




--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- Recommander les nouveaux épisodes de l'émission auxquels un utilisateur est abonné,
-- non visionné par utilisateur et sortie dans deux dernières semaines.
CREATE OR REPLACE PROCEDURE nouveauxEpisodes(id IN Utilisateur.idUtilisateur%TYPE)
IS  
BEGIN
    SAVEPOINT recommandation_start; 
    DBMS_OUTPUT.PUT_LINE('======= Nouveaux épisodes recommandés =======' || CHR(10));

    DECLARE
        v_count INTEGER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM utilisateur_abonne_emission uae
        JOIN emission_episode ee ON uae.idEmission = ee.idEmission
        JOIN video v ON ee.idVideo = v.idVideo
        LEFT JOIN visionnage vi ON v.idVideo = vi.idVideo AND vi.idUtilisateur = id
        WHERE uae.idUtilisateur = id 
        AND v.dateSortie >= SYSDATE - 14 
        AND vi.idVisionnage IS NULL;

        IF v_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Erreur : Aucun nouveau épisode dans les deux dernières semaines.');
            RETURN;
        END IF;
    END;

    FOR cur_row_emission IN (
        SELECT e.idEmission, e.nom AS emission_nom
        FROM utilisateur_abonne_emission uae
        JOIN emission e
        ON uae.idEmission = e.idEmission
        WHERE uae.idUtilisateur = id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('Émission : ' || cur_row_emission.emission_nom || CHR(10));

        FOR cur_row_episode IN (
            SELECT 
                v.nom AS episode_nom,
                v.description, 
                v.duree, 
                v.paysOrigin, 
                v.multiLangue 
            FROM 
                emission_episode ee
            JOIN video v
            ON ee.idVideo = v.idVideo
            LEFT JOIN visionnage vi
            ON v.idVideo = vi.idVideo AND vi.idUtilisateur = id
            WHERE 
                ee.idEmission = cur_row_emission.idEmission
                AND v.dateSortie >= SYSDATE - 14
                AND vi.idVisionnage IS NULL
            ORDER BY v.dateSortie DESC
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('   - Titre : ' || cur_row_episode.episode_nom || CHR(10) ||
                                 '     Description : ' || cur_row_episode.description || CHR(10) ||
                                 '     Durée : ' || cur_row_episode.duree || ' min' || CHR(10) ||
                                 '     Pays d''origine : ' || cur_row_episode.paysOrigin || CHR(10) ||
                                 '     MultiLangue : ' || cur_row_episode.multiLangue || CHR(10) || CHR(10));
        END LOOP;

    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Erreur inattendue : ' || SQLERRM);
END;



-- Check --

SELECT object_name, object_type, status
FROM user_objects
WHERE status = 'INVALID';

select * from USER_ERRORS 
where NAME = upper('nouveauxEpisodes') 
and TYPE = 'PROCEDURE';
-- Requêtes SQL --

--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- 1. Nombre de visionnages de vidéos par catégories de vidéos, pour les visionnages de moins 
--    de deux semaines.
SELECT 
	c.nom AS categorie, 
	COUNT(v.idVisionnage) AS nombre_visionnages
FROM Categorie c
LEFT JOIN video_categorie vc ON c.idCategorie = vc.idCategorie
LEFT JOIN AllVideos av ON av.id = vc.idVideo
LEFT JOIN Visionnage v ON (v.idVideo = av.id OR v.idArchive = av.id) AND v.dateVision >= SYSDATE - 14
GROUP BY c.nom
ORDER BY nombre_visionnages DESC ;


--------------------------------------------------------------------------------------
---------------=-----------------------------------------------------------------------
-- 2. Par utilisateur, le nombre d’abonnement, de favoris et de vidéos visionnées.
SELECT 
    u.idUtilisateur,
    u.login,
    COUNT(DISTINCT uae.idEmission) AS nombre_emissions_abonnes,
    COUNT(DISTINCT ufv.idVideo) + COUNT(DISTINCT ufv.idArchive) AS nombre_favoris,
    COUNT(DISTINCT v.idVisionnage) AS nombre_visionnees
FROM Utilisateur u
LEFT JOIN Utilisateur_Abonne_Emission uae ON u.idUtilisateur = uae.idUtilisateur
LEFT JOIN Utilisateur_Fav_Video ufv ON u.idUtilisateur = ufv.idUtilisateur
LEFT JOIN Visionnage v ON u.idUtilisateur = v.idUtilisateur
GROUP BY u.idUtilisateur, u.login;



--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- 3. Pour chaque vidéo, le nombre de visionnages par des utilisateurs français, le nombre de 
--    visionnage par des utilisateurs allemands, la différence entre les deux, triés par valeur 
--    absolue de la différence entre les deux.
SELECT 
    av.nom AS nomVideo,
    COUNT(CASE WHEN u.pays = 'France' THEN v.idVisionnage END) AS nombre_visionnages_francais,
    COUNT(CASE WHEN u.pays = 'Germany' THEN v.idVisionnage END) AS nombre_visionnages_allemands,
    ABS(COUNT(CASE WHEN u.pays = 'France' THEN v.idVisionnage END) - 
    COUNT(CASE WHEN u.pays = 'Germany' THEN v.idVisionnage END)) AS difference_visionnages
FROM AllVideos av 
LEFT JOIN 
    Visionnage v ON (v.idVideo = av.id OR v.idArchive = av.id)
LEFT JOIN 
    Utilisateur u ON v.idUtilisateur = u.idUtilisateur
GROUP BY av.nom
ORDER BY difference_visionnages DESC;


--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- 4. Les épisodes d’émissions qui ont au moins deux fois plus de visionnage que la moyenne 
--    des visionnages des autres épisodes de l’émission.
CREATE INDEX idx_ee_idEmission ON Emission_Episode (idEmission);
SELECT 
    ee.idEmission,
    e.nom,
    COALESCE(ee.idVideo, ee.idArchive) AS idEpisode,
    av.nom,
    av.description
FROM Emission_Episode ee
JOIN Emission e ON ee.idEmission = e.idEmission
JOIN AllVideos av ON av.id = COALESCE(ee.idVideo, ee.idArchive)
JOIN nbVisionnagesParVideo v ON COALESCE(ee.idVideo, ee.idArchive) = v.idVideo
JOIN MoyenneVisionnagesParEmission m ON ee.idEmission = m.idEmission
WHERE v.nb_visionnages >= 2 * m.moyenne_visionnages;
DROP INDEX idx_ee_idEmission;

--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
-- 5. Les 10 couples de vidéos apparaissant le plus souvent simultanément dans un historique 
--	  de visionnage d’utilisateur.
CREATE INDEX idx_visionnage_idUtilisateur ON Visionnage(idUtilisateur);
CREATE INDEX idx_visionnage_video_archive ON Visionnage(idVideo, idArchive);

SELECT
    COALESCE(v1.idVideo, v1.idArchive) AS video1,
    COALESCE(v2.idVideo, v2.idArchive) AS video2,
    COUNT(*) AS nombre_occurences,
FROM Visionnage v1

----- Creation de sequences -----

CREATE SEQUENCE seq_video START WITH 1;
CREATE SEQUENCE seq_utilisateur START WITH 1;
CREATE SEQUENCE seq_emission START WITH 1;
CREATE SEQUENCE seq_categorie START WITH 1;
CREATE SEQUENCE seq_visionnage START WITH 1;


----- Creation de tables -----

CREATE TABLE Categorie (
	idCategorie INTEGER,
	nom VARCHAR(128) NOT NULL,
	CONSTRAINT PK_categorie PRIMARY KEY (idCategorie) -- PK
);

CREATE TABLE Utilisateur (
	idUtilisateur INTEGER,
	login VARCHAR(128) NOT NULL,
	mdp VARCHAR(255) NOT NULL,
	nom VARCHAR(128) NOT NULL,
	prenom VARCHAR(128) NOT NULL,
	dateNaiss DATE NOT NULL,
	mail VARCHAR(255) NOT NULL UNIQUE, -- Une adresse mail ne peut être inscrit qu'une seule fois
	dateInscription DATE DEFAULT SYSDATE NOT NULL,	-- par defaut, date du jour
	abonnement CHAR(1) DEFAULT 'N' NOT NULL, -- par defaut, un utilisateur n'a pas d'abonnement
	pays VARCHAR(128) NOT NULL,
    CONSTRAINT PK_utilisateur PRIMARY KEY (idUtilisateur), -- Clé primaire
	CONSTRAINT CK_utilisateur_abonnement CHECK (abonnement IN ('N','Y')),
	CONSTRAINT U_utilisateur_LM UNIQUE (login,mdp) -- Unicité de ce couple
);


CREATE TABLE Video (
    idVideo INTEGER,
    nom VARCHAR(255) NOT NULL,
    description VARCHAR(512) NOT NULL,
    duree INTEGER NOT NULL, -- minutes
    dateSortie DATE DEFAULT SYSDATE NOT NULL,
    dateExpiree DATE NOT NULL,
    paysOrigin VARCHAR(128) NOT NULL,
    multiLangue CHAR(1) DEFAULT 'N' NOT NULL, -- par défaut, ne supporte pas de multilangue
	videoType VARCHAR(8) NOT NULL,

    CONSTRAINT PK_video PRIMARY KEY (idVideo), -- Clé primaire
	CONSTRAINT CK_video_multiLangue CHECK (multiLangue IN ('N', 'Y')), -- Check multiLangue
	CONSTRAINT CK_video_dateExpiree CHECK (dateExpiree > dateSortie), -- Validation basique
	CONSTRAINT CK_video_videoType CHECK (videoType IN ('Movie','Episode')) -- Check videoType
);


CREATE TABLE Emission (
	idEmission INTEGER,
	nom VARCHAR(255) NOT NULL,
	description VARCHAR(512) NOT NULL,
	dateSortie DATE DEFAULT SYSDATE NOT NULL,
    dateExpiree DATE NOT NULL,
    paysOrigin VARCHAR(128) NOT NULL,
    multiLangue CHAR(1) DEFAULT 'N' NOT NULL, -- par défaut, ne supporte pas de multilangue
    statut VARCHAR(8) DEFAULT 'ACTIVE' NOT NULL, -- si emissionn archivee, on le supprime pas, 
    										     -- on change que sa statut, et puis déplace tous ses épisodes vers les archives
    CONSTRAINT PK_emission PRIMARY KEY (idEmission), -- Clé primaire
	CONSTRAINT CK_emission_multiLangue CHECK (multiLangue IN ('N', 'Y')), -- Check multiLangue
	CONSTRAINT CK_emission_dateExpiree CHECK (dateExpiree > dateSortie), -- Validation basique
	CONSTRAINT CK_emission_statut CHECK (statut IN ('ACTIVE', 'ARCHIVE')) -- Check statut
);


CREATE TABLE Archivage (
	idArchive INTEGER,
	nom VARCHAR(255) NOT NULL UNIQUE,
	description VARCHAR(512) NOT NULL,
	duree INTEGER NOT NULL,
	dateSortie DATE DEFAULT SYSDATE NOT NULL,
    dateExpiree DATE NOT NULL,
	paysOrigin VARCHAR(128) NOT NULL,
	multiLangue CHAR(1) DEFAULT 'N' NOT NULL, -- par defaut, une video ne supporte pas de multilangue
	videoType VARCHAR(8) NOT NULL,
	CONSTRAINT PK_archivage PRIMARY KEY (idArchive), -- PK
	CONSTRAINT CK_archivage_multiLangue CHECK (multiLangue IN ('N','Y')), -- Check multiLangue
	CONSTRAINT CK_archivage_videoType CHECK (videoType IN ('Movie','Episode')) -- Check videoType
);


CREATE TABLE Emission_Episode (
	idEmission INTEGER NOT NULL,
    idVideo INTEGER,
    idArchive INTEGER,
    
  	CONSTRAINT FK_ee_idEmission FOREIGN KEY (idEmission) REFERENCES Emission(idEmission) ON DELETE CASCADE,
    CONSTRAINT FK_ee_idVideo FOREIGN KEY (idVideo) REFERENCES Video(idVideo) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT FK_ee_idArchive FOREIGN KEY (idArchive) REFERENCES Archivage(idArchive) DEFERRABLE INITIALLY DEFERRED,
    
    CONSTRAINT CK_ee_reference CHECK (
        (idVideo IS NOT NULL AND idArchive IS NULL) OR 
        (idVideo IS NULL AND idArchive IS NOT NULL)
    )
);


CREATE TABLE Visionnage (
    idVisionnage INTEGER,
    idVideo INTEGER, -- REF vers Video
    idArchive INTEGER, -- REF vers Archivage
    idUtilisateur INTEGER,
    dateVision DATE DEFAULT SYSDATE,
    
    -- Clé primaire
    CONSTRAINT PK_visionnage PRIMARY KEY (idVisionnage),
    
    -- Clés étrangères (utilisation de DEFERRABLE INITIALLY DEFERRED)
    -- Cela permet de supprimer une vidéo de la table Video et de l’ajouter à la table Archivage dans la même transaction sans violer les contraintes de clé étrangère pendant la transaction.
    CONSTRAINT FK_visionnage_idUtilisateur FOREIGN KEY (idUtilisateur) REFERENCES Utilisateur(idUtilisateur) ON DELETE SET NULL, --  la vérification des clés étrangères peut être différée jusqu’à la fin de la transaction
    CONSTRAINT FK_visionnage_idVideo FOREIGN KEY (idVideo) REFERENCES Video(idVideo) DEFERRABLE INITIALLY DEFERRED, --  la vérification des clés étrangères peut être différée jusqu’à la fin de la transaction
	CONSTRAINT FK_visionnage_idArchive FOREIGN KEY (idArchive) REFERENCES Archivage(idArchive) DEFERRABLE INITIALLY DEFERRED,

    -- Contrainte de vérification pour que seulement un des deux champs soit renseigné (idVideo ou idArchive)
    -- Ajouter un trigger ici pour transférer automatiquement la référence de idVideo à idArchive lors du déplacement d’une vidéo vers Archivage.
    CONSTRAINT CK_visionnage_reference CHECK (
        (idVideo IS NOT NULL AND idArchive IS NULL) OR 
        (idVideo IS NULL AND idArchive IS NOT NULL)
    )
);



CREATE TABLE Utilisateur_Aime_Categorie (
	idUtilisateur INTEGER NOT NULL,
	idCategorie INTEGER NOT NULL,
	CONSTRAINT PK_uac PRIMARY KEY (idUtilisateur, idCategorie), -- PK
	CONSTRAINT FK_uac_idUtilisateur FOREIGN KEY (idUtilisateur) REFERENCES Utilisateur ON DELETE CASCADE, -- FK
	CONSTRAINT FK_uac_idCategorie FOREIGN KEY (idCategorie) REFERENCES Categorie ON DELETE CASCADE -- FK
);



CREATE TABLE Utilisateur_Fav_Video (
    idUtilisateur INTEGER NOT NULL,
    idVideo INTEGER, -- référence vers une vidéo active
    idArchive INTEGER, -- référence vers une archive si la vidéo est expirée
    
    -- Clés étrangères avec vérification différée
    CONSTRAINT FK_ufv_idUtilisateur FOREIGN KEY (idUtilisateur) REFERENCES Utilisateur ON DELETE CASCADE,
    CONSTRAINT FK_ufv_idVideo FOREIGN KEY (idVideo) REFERENCES Video(idVideo) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT FK_ufv_idArchive FOREIGN KEY (idArchive) REFERENCES Archivage(idArchive) DEFERRABLE INITIALLY DEFERRED,
    -- Contrainte CHECK pour garantir qu'une seule des colonnes idVideo ou idArchive est remplie
    CONSTRAINT CK_ufv_reference CHECK (
        (idVideo IS NOT NULL AND idArchive IS NULL) OR 
        (idVideo IS NULL AND idArchive IS NOT NULL)
    )
);


CREATE TABLE Utilisateur_Abonne_Emission (
	idUtilisateur INTEGER NOT NULL,
	idEmission INTEGER NOT NULL,
	CONSTRAINT PK_uae PRIMARY KEY (idUtilisateur, idEmission), -- PK
	CONSTRAINT FK_uae_idUtilisateur FOREIGN KEY (idUtilisateur) REFERENCES Utilisateur ON DELETE CASCADE, -- FK
	CONSTRAINT FK_uae_idEmission FOREIGN KEY (idEmission) REFERENCES Emission ON DELETE CASCADE-- FK
);


CREATE TABLE Video_Categorie (
	idVideo INTEGER,
	idArchive INTEGER,
	idCategorie INTEGER NOT NULL,
    CONSTRAINT FK_vc_idCategorie FOREIGN KEY (idCategorie) REFERENCES Categorie DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT FK_vc_idVideo FOREIGN KEY (idVideo) REFERENCES Video(idVideo) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT FK_vc_idArchive FOREIGN KEY (idArchive) REFERENCES Archivage(idArchive) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT CK_vc_reference CHECK (
        (idVideo IS NOT NULL AND idArchive IS NULL) OR 
        (idVideo IS NULL AND idArchive IS NOT NULL)
    )
);

CREATE TABLE Emission_Categorie (
	idEmission INTEGER NOT NULL,
	idCategorie INTEGER NOT NULL,
	CONSTRAINT PK_ec PRIMARY KEY(idEmission, idCategorie),
	CONSTRAINT FK_ec_idEmission FOREIGN KEY (idEmission) REFERENCES Emission DEFERRABLE INITIALLY DEFERRED,
	CONSTRAINT FK_ec_idCategorie FOREIGN KEY (idCategorie) REFERENCES Categorie DEFERRABLE INITIALLY DEFERRED
);



----- Creation de vues -----

-- toutes les vidéos (disponibles et indisponibles) du site Replay
CREATE OR REPLACE VIEW allVideos AS
	SELECT 
	    idVideo AS id, 
	    nom, 
	    description, 
	    duree, 
	    dateSortie, 
	    dateExpiree, 
	    paysOrigin, 
	    multiLangue, 
	    videoType,
	    'DISPONIBLE' AS statut
	FROM 
	    Video
	UNION ALL
	SELECT 
	    idArchive AS id, 
	    nom, 
	    description, 
	    duree, 
	    dateSortie, 
	    dateExpiree, 
	    paysOrigin, 
	    multiLangue, 
	    videoType,
	    'INDISPONIBLE' AS statut
	FROM 
	    Archivage;


-- nombre de visionnages par video
CREATE OR REPLACE VIEW nbVisionnageParVideo AS
	SELECT 
	    COALESCE(v.idVideo, a.idArchive) AS video_id,
	    COUNT(*) AS nb_visionnages
	FROM Visionnage vi
	LEFT JOIN Video v ON vi.idVideo = v.idVideo
	LEFT JOIN Archivage a ON vi.idArchive = a.idArchive
	GROUP BY COALESCE(v.idVideo, a.idArchive);

   
-- nombre de visionnages par emission
CREATE OR REPLACE VIEW nbVisionnagesParEmission AS
	SELECT ee.idEmission, SUM(v.nb_visionnages) AS nb_visionnages
	FROM Emission_Episode ee 
	LEFT JOIN nbVisionnagesParVideo v 
	ON COALESCE(ee.idVideo, ee.idArchive) = v.idVideo
	GROUP BY ee.idEmission;


-- nombre d'episodes par emission
CREATE OR REPLACE VIEW nbEpisodesParEmission AS
	SELECT ee.idEmission, COUNT(COALESCE(ee.idVideo, ee.idArchive)) AS nb_episodes
	FROM Emission_Episode ee
	GROUP BY ee.idEmission;
;

-- nombre moyen de visionnages par emission
CREATE OR REPLACE VIEW MoyenneVisionnagesParEmission AS
    SELECT e.idEmission,
        CASE 
            WHEN ep.nb_episodes > 0 THEN e.nb_visionnages / ep.nb_episodes
            ELSE 0
        END AS moyenne_visionnages
    FROM nbVisionnagesParEmission e
    JOIN nbEpisodesParEmission ep
   	ON e.idEmission = ep.idEmission;

CREATE TABLE country (
  country_id       int NOT NULL,
  country_iso_code varchar(10) DEFAULT NULL,
  country_name     varchar(200) DEFAULT NULL,
  PRIMARY KEY (country_id)
);

CREATE TABLE department (
  department_id   int NOT NULL,
  department_name varchar(200) DEFAULT NULL,
  PRIMARY KEY (department_id)
);

CREATE TABLE gender (
  gender_id int NOT NULL,
  gender    varchar(20) DEFAULT NULL,
  PRIMARY KEY (gender_id)
);

CREATE TABLE genre (
  genre_id   int NOT NULL,
  genre_name varchar(100) DEFAULT NULL,
  PRIMARY KEY (genre_id)
);

CREATE TABLE keyword (
  keyword_id   int NOT NULL,
  keyword_name varchar(100) DEFAULT NULL,
  PRIMARY KEY (keyword_id)
);

CREATE TABLE "language" (
  language_id   int NOT NULL,
  language_code varchar(10)  DEFAULT NULL,
  language_name varchar(500) DEFAULT NULL,
  PRIMARY KEY (language_id)
);

CREATE TABLE language_role (
  role_id       int NOT NULL,
  language_role varchar(20) DEFAULT NULL,
  PRIMARY KEY (role_id)
);

CREATE TABLE movie (
  movie_id     int            NOT NULL,
  title        varchar(1000)  DEFAULT NULL,
  budget       int            DEFAULT NULL,
  homepage     varchar(1000)  DEFAULT NULL,
  overview     varchar(1000)  DEFAULT NULL,
  popularity   decimal(12, 6) DEFAULT NULL,
  release_date date           DEFAULT NULL,
  revenue      bigint         DEFAULT NULL,
  runtime      int            DEFAULT NULL,
  movie_status varchar        DEFAULT NULL,
  tagline      varchar(1000)  DEFAULT NULL,
  vote_average decimal(4, 2)  DEFAULT NULL,
  vote_count   int            DEFAULT NULL,
  PRIMARY KEY (movie_id)
);

CREATE TABLE person (
  person_id   int NOT NULL,
  person_name varchar(500) DEFAULT NULL,
  PRIMARY KEY (person_id)
);

CREATE TABLE production_company (
  company_id   int NOT NULL,
  company_name varchar(200) DEFAULT NULL,
  PRIMARY KEY (company_id)
);

CREATE TABLE movie_cast (
  movie_id       int          DEFAULT NULL,
  person_id      int          DEFAULT NULL,
  character_name varchar(400) DEFAULT NULL,
  gender_id      int          DEFAULT NULL,
  cast_order     int          DEFAULT NULL,
  CONSTRAINT fk_mca_gender FOREIGN KEY (gender_id) REFERENCES gender (gender_id),
  CONSTRAINT fk_mca_movie  FOREIGN KEY (movie_id)  REFERENCES movie (movie_id),
  CONSTRAINT fk_mca_per    FOREIGN KEY (person_id) REFERENCES person (person_id)
);

CREATE TABLE movie_company (
  movie_id   int DEFAULT NULL,
  company_id int DEFAULT NULL,
  CONSTRAINT fk_mc_comp  FOREIGN KEY (company_id) REFERENCES production_company (company_id),
  CONSTRAINT fk_mc_movie FOREIGN KEY (movie_id)   REFERENCES movie (movie_id)
);

CREATE TABLE movie_crew (
  movie_id      int DEFAULT NULL,
  person_id     int DEFAULT NULL,
  department_id int DEFAULT NULL,
  job           varchar(200) DEFAULT NULL,
  CONSTRAINT fk_mcr_dept  FOREIGN KEY (department_id) REFERENCES department (department_id),
  CONSTRAINT fk_mcr_movie FOREIGN KEY (movie_id)      REFERENCES movie (movie_id),
  CONSTRAINT fk_mcr_per   FOREIGN KEY (person_id)     REFERENCES person (person_id)
);

CREATE TABLE movie_genres (
  movie_id int DEFAULT NULL,
  genre_id int DEFAULT NULL,
  CONSTRAINT fk_mg_genre FOREIGN KEY (genre_id) REFERENCES genre (genre_id),
  CONSTRAINT fk_mg_movie FOREIGN KEY (movie_id) REFERENCES movie (movie_id)
);

CREATE TABLE movie_keywords (
  movie_id   int DEFAULT NULL,
  keyword_id int DEFAULT NULL,
  CONSTRAINT fk_mk_keyword FOREIGN KEY (keyword_id) REFERENCES keyword (keyword_id),
  CONSTRAINT fk_mk_movie   FOREIGN KEY (movie_id)   REFERENCES movie (movie_id)
);

CREATE TABLE movie_languages (
  movie_id         int DEFAULT NULL,
  language_id      int DEFAULT NULL,
  language_role_id int DEFAULT NULL,
  CONSTRAINT fk_ml_lang  FOREIGN KEY (language_id)      REFERENCES "language" (language_id),
  CONSTRAINT fk_ml_movie FOREIGN KEY (movie_id)         REFERENCES movie (movie_id),
  CONSTRAINT fk_ml_role  FOREIGN KEY (language_role_id) REFERENCES language_role (role_id)
);

CREATE TABLE production_country (
  movie_id   int DEFAULT NULL,
  country_id int DEFAULT NULL,
  CONSTRAINT fk_pc_country FOREIGN KEY (country_id) REFERENCES country (country_id),
  CONSTRAINT fk_pc_movie   FOREIGN KEY (movie_id)   REFERENCES movie (movie_id)
);

INSERT INTO country VALUES (128,'AE','United Arab Emirates'),(129,'AF','Afghanistan'),(130,'AO','Angola'),(131,'AR','Argentina'),(132,'AT','Austria'),(133,'AU','Australia'),(134,'AW','Aruba'),(135,'BA','Bosnia and Herzegovina'),(136,'BE','Belgium'),(137,'BG','Bulgaria'),(138,'BO','Bolivia'),(139,'BR','Brazil'),(140,'BS','Bahamas'),(141,'BT','Bhutan'),(142,'CA','Canada'),(143,'CH','Switzerland'),(144,'CL','Chile'),(145,'CM','Cameroon'),(146,'CN','China'),(147,'CO','Colombia'),(148,'CS','Serbia and Montenegro'),(149,'CY','Cyprus'),(150,'CZ','Czech Republic'),(151,'DE','Germany'),(152,'DK','Denmark'),(153,'DM','Dominica'),(154,'DO','Dominican Republic'),(155,'DZ','Algeria'),(156,'EC','Ecuador'),(157,'EG','Egypt'),(158,'ES','Spain'),(159,'FI','Finland'),(160,'FJ','Fiji'),(161,'FR','France'),(162,'GB','United Kingdom'),(163,'GP','Guadaloupe'),(164,'GR','Greece'),(165,'GY','Guyana'),(166,'HK','Hong Kong'),(167,'HU','Hungary'),(168,'ID','Indonesia'),(169,'IE','Ireland'),(170,'IL','Israel'),(171,'IN','India'),(172,'IR','Iran'),(173,'IS','Iceland'),(174,'IT','Italy'),(175,'JM','Jamaica'),(176,'JO','Jordan'),(177,'JP','Japan'),(178,'KE','Kenya'),(179,'KG','Kyrgyz Republic'),(180,'KH','Cambodia'),(181,'KR','South Korea'),(182,'KZ','Kazakhstan'),(183,'LB','Lebanon'),(184,'LT','Lithuania'),(185,'LU','Luxembourg'),(186,'LY','Libyan Arab Jamahiriya'),(187,'MA','Morocco'),(188,'MC','Monaco'),(189,'MT','Malta'),(190,'MX','Mexico'),(191,'MY','Malaysia'),(192,'NG','Nigeria'),(193,'NL','Netherlands'),(194,'NO','Norway'),(195,'NZ','New Zealand'),(196,'PA','Panama'),(197,'PE','Peru'),(198,'PH','Philippines'),(199,'PK','Pakistan'),(200,'PL','Poland'),(201,'PT','Portugal'),(202,'RO','Romania'),(203,'RS','Serbia'),(204,'RU','Russia'),(205,'SE','Sweden'),(206,'SG','Singapore'),(207,'SI','Slovenia'),(208,'SK','Slovakia'),(209,'TH','Thailand'),(210,'TN','Tunisia'),(211,'TR','Turkey'),(212,'TW','Taiwan'),(213,'UA','Ukraine'),(214,'US','United States of America'),(215,'ZA','South Africa');
INSERT INTO department VALUES (1,'Camera'),(2,'Directing'),(3,'Production'),(4,'Writing'),(5,'Editing'),(6,'Sound'),(7,'Art'),(8,'Costume & Make-Up'),(9,'Crew'),(10,'Visual Effects'),(11,'Lighting'),(12,'Actors');
INSERT INTO gender VALUES (0,'Unspecified'),(1,'Female'),(2,'Male');
INSERT INTO genre VALUES (12,'Adventure'),(14,'Fantasy'),(16,'Animation'),(18,'Drama'),(27,'Horror'),(28,'Action'),(35,'Comedy'),(36,'History'),(37,'Western'),(53,'Thriller'),(80,'Crime'),(99,'Documentary'),(878,'Science Fiction'),(9648,'Mystery'),(10402,'Music'),(10749,'Romance'),(10751,'Family'),(10752,'War'),(10769,'Foreign'),(10770,'TV Movie');
INSERT INTO "language" VALUES (24574,'en','English'),(24575,'sv','svenska'),(24576,'de','Deutsch'),(24577,'xx','No Language'),(24578,'ja','u65e5u672cu8a9e'),(24579,'fr','Franu00e7ais'),(24580,'es','Espau00f1ol'),(24581,'ar','u0627u0644u0639u0631u0628u064au0629'),(24582,'la','Latin'),(24583,'km',''),(24584,'vi','Tiu1ebfng Viu1ec7t'),(24585,'tr','Tu00fcrku00e7e'),(24586,'el','u03b5u03bbu03bbu03b7u03bdu03b9u03bau03ac'),(24587,'zh','u666eu901au8bdd'),(24588,'ru','Pu0443u0441u0441u043au0438u0439'),(24589,'ga','Gaeilge'),(24590,'cn','u5e7fu5ddeu8bdd / u5ee3u5ddeu8a71'),(24591,'hu','Magyar'),(24592,'he','u05e2u05b4u05d1u05b0u05e8u05b4u05d9u05ea'),(24593,'ne',''),(24594,'si',''),(24595,'it','Italiano'),(24596,'nl','Nederlands'),(24597,'fi','suomi'),(24598,'pt','Portuguu00eas'),(24599,'gd',''),(24600,'fa','u0641u0627u0631u0633u06cc'),(24601,'ur','u0627u0631u062fu0648'),(24602,'da','Dansk'),(24603,'th','u0e20u0e32u0e29u0e32u0e44u0e17u0e22'),(24604,'no','Norsk'),(24605,'sq','shqip'),(24606,'pl','Polski'),(24607,'is','u00cdslenska'),(24608,'tl',''),(24609,'pa','u0a2au0a70u0a1cu0a3eu0a2cu0a40'),(24610,'hi','u0939u093fu0928u094du0926u0940'),(24611,'kk','u049bu0430u0437u0430u049b'),(24612,'bg','u0431u044au043bu0433u0430u0440u0441u043au0438 u0435u0437u0438u043a'),(24613,'sw','Kiswahili'),(24614,'ro','Romu00e2nu0103'),(24615,'ko','ud55cuad6duc5b4/uc870uc120ub9d0'),(24616,'cs','u010cesku00fd'),(24617,'sk','Slovenu010dina'),(24618,'mi',''),(24619,'eo','Esperanto'),(24620,'so','Somali'),(24621,'af','Afrikaans'),(24622,'xh',''),(24623,'zu','isiZulu'),(24624,'yi',''),(24625,'ca','Catalu00e0'),(24626,'sr','Srpski'),(24627,'sa',''),(24628,'uk','u0423u043au0440u0430u0457u043du0441u044cu043au0438u0439'),(24629,'hr','Hrvatski'),(24630,'gl','Galego'),(24631,'sh',''),(24632,'co',''),(24633,'kw',''),(24634,'bo',''),(24635,'bs','Bosanski'),(24636,'ps','u067eu069au062au0648'),(24637,'iu',''),(24638,'hy',''),(24639,'am',''),(24640,'ce',''),(24641,'et','Eesti'),(24642,'ku',''),(24643,'nv',''),(24644,'mn',''),(24645,'to',''),(24646,'bn','u09acu09beu0982u09b2u09be'),(24647,'ny',''),(24648,'st',''),(24649,'dz',''),(24650,'cy','Cymraeg'),(24651,'wo','Wolof'),(24652,'ka','u10e5u10d0u10e0u10d7u10e3u10dau10d8'),(24653,'br',''),(24654,'ta','u0ba4u0baeu0bbfu0bb4u0bcd'),(24655,'id','Bahasa indonesia'),(24656,'ml',''),(24657,'te','u0c24u0c46u0c32u0c41u0c17u0c41'),(24658,'ky','??????'),(24659,'bm','Bamanankan'),(24660,'sl','Slovenu0161u010dina'),(24701,'nb','Unknown');
INSERT INTO language_role VALUES (1,'Original'),(2,'Spoken');
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*																					   */
/*  	CALAGE DES DEPENSES DE CONSOMMATION SUR LA COMPTABILITE NATIONALE 	           */
/*																					   */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/* Le programme prépare la table de dépenses de consommation avant appariement avec INES 
et calcule des taxes : ajout de postes détaillés quand nécessaire, calcul des coefficients 
de calage et ajustement des dépenses sur la Comptabilité Nationale.                     */

/* Tables d'entrées : 
		- bdf&anBDF..C05 (consommation au niveau COICOP 5 chiffres  - 1 obs = 1 ménage)
		- bdf&anBDF..C06 (consommation au niveau COICOP 6 chiffres pour quelques postes  -   
		  1 obs = 1 ménage - sur demande auprès de l'équipe BDF)
		- bdf&anBDF..a04 (auto-consommation au niveau COICOP 4 chiffres - 1 obs = 1 ménage) 
		- bdf&anBDF..menage (données socio-démo et de revenu - 1 obs = 1 ménage) 		*/

/* Fichier de paramètres :
		-  compta_nat_nomen3.xls (Comptes nationaux sur plusieurs années - à préparer)			*/
	
/* Tables de sortie (dans la work) : 
		- consommation (table C05 avec nomen6 pour qq produits - 1 obs = 1 ménage)
		- depenses (table C05 avec nomen6 pour qq produits - 1 obs = 1 ménage-produit; 
          calée sur la CN)
		- coef_calage (coefficients de calage sur la CN) */

/* Le programme est en deux étapes : 	

/*	I -	Préparation des données

		A - On ajoute les postes nomen6 à la table de dépenses (C05) pour alcools, tabac, carburants et assurances 
	  	B - On répartit les "autres dépenses" (hors nomenclature) au sein des postes de la même grande fonction 
			de consommation (proportionnellement à leur poids) 
		C - Ajout des labels pour les postes du 6e niveau de la nomenclature
		D - Agrégation des consommations au niveau COICOP à 3 chiffres, ajout de l'autoconsommation et rapprochement 
			du champ de la comptabilité nationale 
			=> table consommation                     */ 

/* II - Calcul des coefficients de calage et calage sur la CN 
			=> table conso_aj                         */ 


/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                                                                             */
/*                                      I - Préparation des données                                           */
/*                                                                                                             */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/


/***** On modifie les postes de consommation pour avoir le même champ que la CN *****/ 

/* Remarque : Pour le moment, on élimine automatiquement les "autres dépenses" lorsque  ce sont les seules dépenses d'un ménage.
Pourrait être amélioré, mais négligeable : conso totale avant calage inférieure d'environ 1 milliard sur 745 milliards */

/* A - Ajout des postes nomen6 à la table de dépenses (C05) pour alcools, tabac, carburants et assurances */

data consommation (drop = m_: s_: f_:) ;
	merge  bdf&anBDF..c05 (in=a) bdf&anBDF..c06 ; 
	by ident_men;
	if a;
	/* On fusionne les tables de consommation en COICOP 5 et COICOP 6 (on ne dispose que de quelques postes) et 
on se débarrasse des postes en COICOP 5 pour lesquels on a la COICOP 6   */

		/***** arrondi des montants issus de la table carnets6 *****/
	%MACRO arrondi;
		%do i = 1 %to 8 ; C02111&i. = round(C02111&i.) ; %end ;
		C02111Z = round(C02111Z) ;
		%do i = 1 %to 2 ; C02121&i. = round(C02121&i.) ; %end ;
		C02121Z = round(C02121Z) ;
		%do i = 1 %to 3 ; C02122&i. = round(C02122&i.) ; %end ;
		C02122Z = round(C02122Z) ;
		%do i = 1 %to 2 ; C02213&i. = round(C02213&i.) ; %end ;
		%do i = 1 %to 3 ; C07221&i. = round(C07221&i.) ; %end ;
		C072215 = round(C072215) ;
		C07221Z = round(C07221Z) ;
		%do i = 1 %to 9 ; C12551&i. = round(C12551&i.) ; %end ;
		C12551A = round(C12551A) ;
		C12551B = round(C12551B) ;
		C12551C = round(C12551C) ;
	%MEND arrondi;
	%arrondi;

	drop C02111 C02121 C02122 C02213 C07221 C12551; /*on enlève aussi liqueurs alcool tabac*/
	/* On exclut les postes 13, i.e. dépenses hors consommation (IMPOTS ET TAXES, GROS TRAVAUX, REMBOURSEMENT PRET,
		CADEAUX, PRELEVEMENT EMPLOYEUR, EPARGNE) */
	drop C13: ;
	drop ctot c14111; /*consommation totale et  allocations logement reçues*/

/* B - Répartition des "autres dépenses" (hors nomenclature) au sein des postes de la même grande fonction 
			de consommation (proportionnellement à leur poids) */

	/* macro pour créer des variables temporaires m_C01111, m_C01112, etc., pour tous les postes de consommation */
	%MACRO Create_m_ListVar(ListeVar);
	%do i=1 %to %sysfunc(countw(&ListeVar.));
		m_%scan(&ListeVar.,&i.) = %scan(&ListeVar.,&i.) ; 
	%end;
	%MEND Create_m_ListVar;
	%Create_m_ListVar(&liste_conso.);
	
	/* on crée pour chaque grand poste de consommation (COICOP2) une var. s_ donnant la somme des consommations du
	poste, et une var. f_ donnant la consommation hors nomenclature à répartir au sein du poste (autres dépenses) */
		/* Alimentation */
		s_C01 = sum(0, of m_C011: m_C012:);
		f_C01 = C01311 + C01312 ;
		/* Tabac alcool (attention, la plupart des postes sont en COICOP 6 chiffres) */ 
		s_C02 = sum(0, of m_C021: m_C022:);
		f_C02 = C02411;
		/* Habillement */
		s_C03 = sum(0, of m_C031: m_C032:);
		f_C03 = C03311 + C03312 ;
		/* Logement */
		s_C04 = sum(0, of m_C041: m_C043: m_C044: m_C045:);
		f_C04 = C04611;
		/* Ameublement et entretien */
		s_C05 = sum(0, of m_C051: m_C052: m_C053: m_C054: m_C055: m_C056:);
		f_C05 = C05711 + C05712 ;
		/* Transports */
		s_C07 = sum(0, of m_C071: m_C072: m_C073: );
		f_C07 = C07411 + C07412 ;
		/* Loisirs  */
		s_C09 = sum(0, of m_C091: m_C092: m_C093: m_C094: m_C095: m_C096:);
		f_C09 = C09711 + C09712 ;
		/* Services */
		s_C12 = sum(0, of m_C121: m_C123: m_C124: m_C125: m_C126: m_C127:);
		f_C12 = C12811 + C12911 ;

		/* %prepare_conso  répartit les "autres dépenses" dans les postes de la même fonction de consommation */
		/* les "autres dépenses" sont des postes qui n'existent pas dans la CN mais sont dans les carnets de l'enquête */
%MACRO prepare_conso(ListeVar) ;
	%do i=1 %to %sysfunc(countw(&ListeVar.));
		%let n5_temp= %scan(&ListeVar.,&i.); /*nomen5*/
		%let n2_temp = %sysfunc(substr(&n5_temp.,1, 3)); /*nomen2*/
		/*certains postes sont exclus ou traités plus tard*/
		%if &n2_temp. ne C06 %then %do; 	/* santé*/
			%if &n2_temp. ne C08 %then %do;	/* communications*/
				%if &n2_temp. ne C10 %then %do; 	/* enseignement*/
					%if &n2_temp. ne C11 %then %do; 	/* restaurations*/
							if s_&n2_temp. ne . and s_&n2_temp. ne 0 then do;
								&n5_temp. =  round(m_&n5_temp. + f_&n2_temp.*(m_&n5_temp./s_&n2_temp.)) ; 
							end;
				%end;
				%end;
			%end;
		%end;
	%end;
	%MEND prepare_conso ; 
	%prepare_conso(&liste_conso.);

	/***** Remplacement des valeurs manquantes (au cas où) *****/
	%MissingToZero(&liste_conso.) ;

/* C - Ajout des labels pour les postes du 6e niveau de la nomenclature */

	drop C01311 C01312 /*autres dépenses alimentations*/
	C02311 /*stupéfiants*/
	C02411 /*autres dépenses alcool, tabac*/
	C03311 C03312 /*autres dépenses habillement*/
	C04611 /*autres dépenses habitation */
	C05711 C05712 /*autres dépenses ameublement et entretien */
	C07411 C07412 /*autres dépenses transports*/
	C09711 C09712 /*autres dépenses loisirs */
	C12811 C12911 /*autres dépenses services*/;

	/*labelisation des consommations au niveau COICOP6  */
	label C021111= "Apéritifs anisés";
	label C021112= "Autres apéritifs";
	label C021113= "Whisky, bourbon";
	label C021114= "Eau de vie, cognac, armagnac, calvados, vodka, gin, Cointreau, brandy, Baileys, saké, hydromel…";
	label C021115= "Rhum, Baccardi";
	label C021116= "Punch, planteur";
	label C021117= "Liqueurs de cassis, de framboise…,";
	label C021118= "Autres boissons : cocktail, apéritif sans alcool…";
	label C021211= "Vins";
	label C021212= "Cidre Y.C. poiré, pétillant de raisin, framboise ou pêche";
	label C021221= "Vins mousseux et vins champagnisés (Blanquette de Limoux, Ackerman, Clairette de Die…)";
	label C021222= "Champagne";
	label C021223= "Vins doux naturels, vins de liqueur (madère, pineau, porto, muscat, guignolet, sangria, Picon, Ambassadeur…)";
	label C022131= "tabac à rouler, à pipe, à mâcher, priser, chiquer";
	label C022132= "papier à cigarettes, tubes, filtres";
	label C072211= "super, ordinaire, super sans plomb, mélange 2T";
	label C072212= "gas oil, diesel";
	label C072213= "GPL";
	label C072215= "Huiles et lubrifiants yc antigel, liquide nettoyage vitre, additif, liquide de frein, de transmission, de refroidissement";
	label C125511= "Pack assurance (voiture + maison) ou SAI";
	label C125512= "Assurance retraite complémentaire : volontaire suite à une démarche volontaire";
	label C125513= "Assurance dépendance (personne âgée)";
	label C125514= "Assurance scolaire";
	label C125515= "Assurance protection juridique";
	label C125516= "Assurance sport et loisirs N.C. assurance liée à une activité particulière";
	label C125517= "Assurance pour un bien particulier (oeuvre d'art…)";
	label C125518= "Assurance chômage volontaire souscrite séparément";
	label C125519= "Assurance individuelle accident";
	label C12551A= "Assurance prévoyance SAI"; 
	label C12551B= "Autre assurance yc assurance animaux, obsèques…"; 
	label C12551C= "Assurance responsabilité civile"; 
	label C02111Z= "Spiritueux et liqueurs (résidu imputation Coicop 5)";
	label C02121Z= "Vins et cidres (résidu imputation Coicop 5)";
	label C02122Z= "Autres apéritifs (résidu imputation Coicop 5)";
	label C07221Z= "Carburants (résidu imputation Coicop 5)";
run;

/* D - Agrégation des consommations au niveau COICOP à 3 chiffres, ajout de l'autoconsommation et rapprochement 
du champ de la comptabilité nationale (CN) */

/***** On agrège les consommations au niveau COICOP à 3 chiffres, en ne conservant que les postes utiles *****/
data conso_nomen3 (keep = ident_men pondmen C011--C127); 
	set consommation; 
	%sum_conso(C01,2);
	%sum_conso(C02,2);
	%sum_conso(C03,2);
	/*on ne prend pas C042 : loyers imputés*/
	C041 = sum(0, of C041:);
	C043 = sum(0, of C043:);
	C044 = sum(0, of C044:);
	C045 = sum(0, of C045:);
	%sum_conso(C05,6);
	%sum_conso(C06,4);
	%sum_conso(C07,3);
	%sum_conso(C08,1);
	%sum_conso(C09,6);
	%sum_conso(C10,1);
	%sum_conso(C11,2);
	/*C122 n'existe pas dans BDF */
	C121 = sum(0, of C121:);
	C123 = sum(0, of C123:);
	C124 = sum(0, of C124:);
	C125 = sum(0, of C125:);
	C126 = sum(0, of C126:);
	C127 = sum(0, of C127:);
run;

data autoconso_nomen3 (keep=ident_men A011--A021); 
	set bdf&anBDF..A04; 
	%sum_conso(A01,2);
	%sum_conso(A02,1);
run;


proc sort data = conso_nomen3 ; by ident_men ; run ;
proc sort data = autoconso_nomen3 ; by ident_men ; run ;
data conso_nomen3 ;
	merge conso_nomen3 (in = a )  autoconso_nomen3 ;
	by ident_men ;
	if a ; 
run ;


/***** Montants agrégés par postes de consommation *****/
proc means 
	data=conso_nomen3 ;
	var C: A:;
	weight pondmen ;
	output out=bdf_nomen3 sum= ;
run ;

/***** On modifie les postes pour lesquels il n'y a pas concordance exacte avec la CN *****/
data bdf_nomen3 ;
	set bdf_nomen3 ;
	/* Ajout de l'autoconsommation */
	C011 = C011 + A011 ; 
	C012 = C012 + A012 ;
	C021 = C021 + A021 ;
	/* Dépenses de santé : agrégation et coef de calage au niveau coicop 2 chiffres */
	n_C061 = sum(of C06:) ;
	n_C062 = sum(of C06:) ;
	n_C063 = sum(of C06:) ;
	n_C064 = sum(of C06:) ;
	drop C061 C062 C063 C064 ;
	rename n_C061 = C061 ;
	rename n_C062 = C062 ;
	rename n_C063 = C063 ;
	rename n_C064 = C064 ;
	/* Cas des voyages à forfaits, services d'hébergement et de restauration : calcul du coef de calage au niveau agrégé de ces 3 postes */
	n_C096 = C096 + C111 + C112 ;
	n_C111 = C096 + C111 + C112 ;
	n_C112 = C096 + C111 + C112 ;
	drop C096 C111 C112 ;
	rename n_C096 = C096 ;
	rename n_C111 = C111 ;
	rename n_C112 = C112 ;
	drop  _type_ _freq_ A011 A012 A021 ;
run ;

/***** On transpose la table avec les montants agrégés *****/
proc transpose 
	data=bdf_nomen3 out=bdfnomen3  ;
	var _all_ ;
	run ;
data bdfnomen3 ; 
	set bdfnomen3 (rename = (col1 = dep_BDF&anBDF.));
	nomen3 = substr(_name_,2) ;
	drop _name_ ;
	label nomen3 = "nomenclature COICOP 3 chiffres"  ;
	label dep_BDF&anBDF. = "Dépenses agrégées par postes de BDF &anBDF." ;
run ;

/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                                                 														                     */
/*        II - Calcul des coefficients de calage et calage de la consommation sur la CN                      */
/*                                                                                                             												*/
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/


/***** On fusionne la table transposée avec les montants issus de la CN *****/
%importFichier(compta_nat_nomen3,feuille=CN,table=CN);
proc sort data =dossier.CN ; by nomen3 ; run ;
proc sort data = bdfnomen3 ;  by nomen3 ; run ;

/*Calcul et création des macros-variables de calage au niveau nomen3 (40 variables)*/
data coef_calage ; 
	merge bdfnomen3 (in = a) dossier.CN (keep = nomen3 CN20&anr2.) ; 
	by nomen3 ; 
	if a ;
	/***** On calcule les coefficients de calage *****/
	coef_cal_20&anr2. = (0.975*CN20&anr2.*1000000)/dep_BDF&anBDF.; 
	/* on considère que les ménages ordinaires (champ de BDF) représente 97,5 % des ménages */
	/*TODO : ne pas mettre en dur ce coefficient et prendre celui de la note de validation*/
	do i = 1 to _N_ ; 
		call symputx ("coef_cal_C"!!nomen3, coef_cal_20&anr2. );
	end; 
run;

/* on calcule les dépenses annuelles calées sur la CN */
data conso_aj;
	set consommation;
	%MACRO calage_conso(ListeVar) ;
		%do i=1 %to %sysfunc(countw(&ListeVar.));
			%let n5_temp= %scan(&ListeVar.,&i.); /*nomen5*/
			%let n3_temp = %sysfunc(substr(&n5_temp.,1, 4)); /*nomen3*/
			%scan(&ListeVar.,&i.) = %scan(&ListeVar.,&i.)*&&coef_cal_&n3_temp..;
			%end;
	%MEND calage_conso;
	%calage_conso(&liste_conso.);
run;


/****************************************************************
© Logiciel élaboré par l’État, via l’Insee, la Drees et la Cnaf, 2018. 

Ce logiciel est un programme informatique initialement développé par l'Insee 
et la Drees. Il permet d'exécuter le modèle de microsimulation Ines, simulant 
la législation sociale et fiscale française.

Ce logiciel est régi par la licence CeCILL V2.1 soumise au droit français et 
respectant les principes de diffusion des logiciels libres. Vous pouvez utiliser, 
modifier et/ou redistribuer ce programme sous les conditions de la licence 
CeCILL V2.1 telle que diffusée par le CEA, le CNRS et l'Inria sur le site 
http://www.cecill.info. 

En contrepartie de l'accessibilité au code source et des droits de copie, de 
modification et de redistribution accordés par cette licence, il n'est offert aux 
utilisateurs qu'une garantie limitée. Pour les mêmes raisons, seule une 
responsabilité restreinte pèse sur l'auteur du programme, le titulaire des 
droits patrimoniaux et les concédants successifs.

À cet égard l'attention de l'utilisateur est attirée sur les risques associés au 
chargement, à l'utilisation, à la modification et/ou au développement et à 
la reproduction du logiciel par l'utilisateur étant donné sa spécificité de logiciel 
libre, qui peut le rendre complexe à manipuler et qui le réserve donc à des 
développeurs et des professionnels avertis possédant des connaissances 
informatiques approfondies. Les utilisateurs sont donc invités à charger et 
tester l'adéquation du logiciel à leurs besoins dans des conditions permettant 
d'assurer la sécurité de leurs systèmes et ou de leurs données et, plus 
généralement, à l'utiliser et l'exploiter dans les mêmes conditions de sécurité.

Le fait que vous puissiez accéder à ce pied de page signifie que vous avez pris 
connaissance de la licence CeCILL V2.1, et que vous en avez accepté les
termes.
****************************************************************/

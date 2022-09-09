/************************************************************************************/
/*																					*/
/*					4_Controles_Niveau_Foyer										*/
/*																					*/
/************************************************************************************/


/* Vérification propres à la table foyer
Il est nécessaire d'avoir fait tourner le programme init_foyer avant ce programme*/
/************************************************************************************/
/* En entrée : travail.foyer&anr.					          						*/
/************************************************************************************/
/* PLAN : */
/*	00. Vérification du SIF 
/*	0. Préparation d'une table fiscale sans les cases 								*/
/*  1. Analyse de la variable declar (A&M)	 										*/
/*  2. Analyse des évènements XYZ dans l'année (M)								 	*/
/*  3. Analyse de la variable mcdvo (M)											 	*/
/*  4. Vérification de valeurs aberrantes (M)									 	*/
/*  5. Analyse de la variable anaisenf (A&M)									 	*/
/************************************************************************************/
/* Remarque : 																		*/
/* - A indique que la correction est automatique dans les pgms de corrections 		*/
/* - M indique un traitement manuel à faire (par exemple modifier un declar)		*/
/************************************************************************************/


/******************************************************************************************/
/*	00	Vérification du SIF
/******************************************************************************************/

/*Vérification de la position de tous les caractères du SIF pour voir si il y a eu des évolutions par rapport aux années précédentes
les éventuelles modifications doivent se gérer dans la macro gérer_SIF dans le programme init_foyer et dans la macro Standard_Foyer du prog "macro" */

%macro pos_sif (annee, libr, var);
%let an=%substr(&annee.,3,2);
data z;
set &libr..foyer&an. (keep=sif:); 
run;

data z_;
set z;
%do i=1 %to 100;
Pos_&i.=substr(&var.,&i.,1); 
%end;
run;

proc freq data=z_;
tables pos:;
run;

%mend pos_sif;

%pos_sif (2016, work, sif1); /*Vide à partir de la 89e position*/
%pos_sif (2016, noyau, sif); /*Vide à partir de la 89e position*/
%pos_sif (2016, travail, sif); /*Vide à partir de la 96e position*/

/*Avec anref 2015 pour vérif (attention il faut avoir fait tourner le début de l'enchaînement avec anref = 2015*/
%pos_sif (2015, travail, sif); /*Vide à partir de la 96e position*/

/*possibilité de faire tourner cette macro aussi à partir des librairies : (en adaptant les arguments de la macro)  
- "noyau" pour comparer directement avec l'année précédente (on a la table foyer de l'année précédente) 
- "travail" pour voir ce que ca donne après les modifications apportées par la macro gérer_SIF dans le programme init_foyer
dans les deux cas, pour ces librairie utiliser la variable sif et non sif1*/
/*exemple : %pos_sif (2014, travail, sif);*/


/************************************************************************************/
/*	0. Préparation d'une table fiscale sans les cases 								*/
/************************************************************************************/
data foyer_sans_cases; 
	set travail.foyer&anr.(drop=_:); 
	annee_mariage	=substr(sif,40,4);
	annee_divorce	=substr(sif,49,4);
	annee_deces		=substr(sif,58,4);
	varX=substr(sif,35,1);
	varY=substr(sif,44,1);
	varZ=substr(sif,53,1);
	run;

/************************************************************************************/
/*  1. Analyse de la variable declar (A&M)	 										*/
/************************************************************************************/
/* Problème de décalage sur declar (A)*/
data pb_decalage pb_J;
	set foyer_sans_cases;
	if substr(declar,30,1)='' & substr(declar,31,1) ne '' then do;
		if substr(declar,33,1)='J' then output pb_J;/* Ca se corrige avec declar=substr(declar,1,29)!!substr(declar,31,39); */
		else output pb_decalage;
		end;
	run;
/* 	ERFS 2012 : 651 décalages lorsque l'on a des enfants majeurs à charge, 0 sinon. */
/* 	ERFS 2013 : 0 décalages */
/* 	ERFS 2014 : 0 décalages */
/* 	ERFS 2015 : 0 décalages */
/* 	ERFS 2016 : 0 décalages */

/* Cohérence entre le declar et vousconj, entre declar et mcdvo (M) */
data declar; 
	set foyer_sans_cases; 
	if substr(declar,14,9) ne vousconj ! substr(declar,13,1) ne mcdvo; 
	run;
/*	ERFS 2009 : 0 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 1 cas 
	ERFS 2014 : 0 cas
	ERFS 2015 : 0 cas
	ERFS 2016 : 0 cas  */

/* Cohérence entre declar et anaisenf (M) */
data declar_enf;
	set foyer_sans_cases; 
	if (substr(declar,30,50) ne anaisenf); 
	run;
/*	ERFS 2009 : 0 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 0 cas 
	ERFS 2014 : 540 cas avant correction (cf. vérification de la variable anaisenf ci-dessous). 0 cas après 
	ERFS 2015 : 784 cas avant correction ; 0 cas après
	ERFS 2016 : 2 cas avant correction ; 0 cas après*/

/************************************************************************************/
/*  2. Analyse des évènements XYZ dans l'année (M)								 	*/
/************************************************************************************/
/* Evènements multiples dans la meme annee */
proc freq data=foyer_sans_cases; 
	tables varX*varY*varZ;
	run; 
/*	ERFS 2008 : 1 mariage puis décès et 1 mariage et divorce
	ERFS 2009 : 1 cas de mariage + divorce mais peut-être plus qui sont juste mal renseigné
	ERFS 2011 : 0 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 0 cas
	ERFS 2014 : 1 cas : 1 mariage + 1 décès ; pas corrigé (à vérifier) 
	ERFS 2015 : 1 cas : 1 mariage + 1 décès ; pas corrigé (à vérifier) 
	ERFS 2016 : 0 cas*/

/* Valeurs vraisemblables pour les dates (M) */ 
proc freq data=foyer_sans_cases;
	table annee_mariage annee_divorce annee_deces;
	run; 
/* 	ERFS 2011 : des valeurs bizarres
	ERFS 2012 : un mariage en 2011, un décalage sur les dates
	ERFS 2013 : OK 
	ERFS 2014 : OK
	ERFS 2015 : OK
	ERFS 2016 : OK*/

/* Valeurs vraisemblables pour les mois et jours des évènements (M) */
proc sort data=foyer_sans_cases (where=(xyz ne '0')) out=xyz; by xyz; run;
proc freq data=xyz;
	table moisev jourev;
	by xyz;
	run;
/* 	ERFS 2011 : OK
	ERFS 2012 : OK
	ERFS 2013 : OK
	ERFS 2014 : OK
	ERFS 2015 : OK
	ERFS 2016 : OK*/

/************************************************************************************/
/*  3. Analyse de la variable mcdvo (M)											 	*/
/************************************************************************************/
/* Vérification du statut mcdvo en fonction du nombre de personne sur la déclaration */
data celibataire_2pers_ds_vousconj; 
	set foyer_sans_cases; 
	if substr(vousconj,6,4) ne '9999' & mcdvo not in ('M','O'); 
	run;
/*	ERFS 2009 : 0 cas
	ERFS 2011 : 0 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 0 cas
	ERFS 2014 : 0 cas
	ERFS 2015 : 0 cas
	ERFS 2016 : 0 cas*/

data marie_1pers_ds_vousconj; 
	set foyer_sans_cases; 
	if substr(vousconj,6,4)='9999' & mcdvo in ('M','O'); 
	run;
/*	ERFS 2009 : 0 cas
	ERFS 2011 : 13 cas
	ERFS 2012 : 1 cas
	ERFS 2013 : 0 cas
	ERFS 2014 : 0 cas
	ERFS 2015 : 0 cas
	ERFS 2016 : 0 cas*/

/* Cohérence des statuts et des événements */
data faux_celibataires;
	set foyer_sans_cases;
	if (xyz='Y' ! xyz='Z') & mcdvo='C';
	run;
/*	ERFS 2009 : 0 cas
	ERFS 2011 : 8 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 0 cas
	ERFS 2014 : 0 cas
	ERFS 2015 : 0 cas
	ERFS 2016 : 0 cas*/

/************************************************************************************/
/*  4. Vérification de valeurs aberrantes (M)									 	*/
/************************************************************************************/
/* Années de naissance extrèmes (M) */
data naissance; 
	set foyer_sans_cases;
	if  &anref.-input(substr(vousconj,1,4),4.)>115 /* Déclarant âgé de plus de 115 ans */
	! 	(&anref.-input(substr(vousconj,1,4),4.)<=15 & substr(vousconj,1,4) not in ('9998') )/* Déclarant âgé de moins de 15 ans */
	! 	&anref.-input(substr(vousconj,6,4),4.)>115 /* Conjoint âgé de plus de 115 ans */
	! 	(&anref.-input(substr(vousconj,6,4),4.)<=15 & substr(vousconj,6,4) not in ('9998','9999')); /* Conjoint âgé de moins de 15 ans */
	run;
/*	ERFS 2009 : 0 cas
	ERFS 2012 : 1 cas
	ERFS 2013 : 0 cas
	ERFS 2014 : 0 cas	
	ERFS 2015 : 0 cas
	ERFS 2016 : 0 cas*/

/* Vérification du contenu des 'cases' (M) */
proc freq data=foyer_sans_cases;
	table case_e case_f case_g case_k case_l case_p case_s case_w case_n case_t case_l2;
	run;
/* 	ERFS 2011 : pas de valeurs bizarres sur les cases E à T
	ERFS 2012 : OK
	ERFS 2013 : OK
	ERFS 2014 : OK	
	ERFS 2015 : OK	
	ERFS 2016 : OK*/

/* Nombres d'enfants négatifs ou extrèmes (M) */
data enfant; 
	 set foyer_sans_cases;
	/* Nombre d'enfants déclarés */
	if nbf<0 ! nbf>18 ! nbg<0 ! nbg>nbf ! nbj<0 ! nbj>5 ! nbn<0 ! nbn>5 ! nbr<0 ! nbr>20 ! nbh<0 ! nbh>5 ! nbi<0 ! nbi>5;
	run;
/*	ERFS 2009 : 0 cas
	ERFS 2012 : 1 cas avec 6 enfants en garde alternée. On laisse. 
	ERFS 2013 : De même, 1 cas avec 6 enfants en garde alternée. On laisse. 	
	ERFS 2014 : 0 cas	
	ERFS 2015 : 0 cas
	ERFS 2016 : 0 cas*/

/************************************************************************************/
/*  5. Analyse de la variable anaisenf (A&M)									 	*/
/************************************************************************************/
/* Décalages sur anaisenf (A) */
data decal; 
	set foyer_sans_cases;
	if substr(anaisenf,1,1)='' & substr(anaisenf,2,1) ne '';
	run;
/* 	ERFS 2009 : 0 cas
	ERFS 2012 : 651 cas (ceux repérés plus haut)
	ERFS 2013 : 0 cas
	ERFS 2014 : 540 cas ==> décalage à corriger dans 4_correction_foyer ; OK après correction 
	ERFS 2015 : 784 cas ==> décalage à corriger dans 4_correction_foyer ; OK après correction
	ERFS 2016 : 2 cas (MEMES CAS QUE LES OBSERVATIONS DE declar_enf) ; OK après correction*/

/* Coherence entre anaisenf et le nombre d'enfants à charge du sif (à faire tourner une fois le décalage de anaisenf corrigé) */
data mqdat mqdatj tropdat invalf incodatnaiss;
	set foyer_sans_cases;
	%Init_Valeur(nbfan nbgan nbjan nbran nbnan nbhan nbian);
	do i=0 to ((length(anaisenf)-5)/5) ;
		if substr(anaisenf,i*5+1,1)='F' then do;
			nbfan=nbfan+1;
			if substr(anaisenf,i*5+2,4)<='1901' ! &anref.-input(substr(anaisenf,i*5+2,4),4.)<0 then anincoher=1;
			end; 
		if substr(anaisenf,i*5+1,1)='G' then do;
			nbgan=nbgan+1;
			if substr(anaisenf,i*5+2,4)<='1901' ! &anref.-input(substr(anaisenf,i*5+2,4),4.)<0 then anincoher=1;
			end;
		if substr(anaisenf,i*5+1,1)='J' then do;
			nbjan=nbjan+1;
			if &anref.-input(substr(anaisenf,i*5+2,4),4.)>26 ! &anref.-input(substr(anaisenf,i*5+2,4),4.)<18 then anincoher=1;
			end;
		if substr(anaisenf,i*5+1,1)='N' then nbnan=nbnan+1;
		if substr(anaisenf,i*5+1,1)='R' then nbran=nbran+1;
		if substr(anaisenf,i*5+1,1)='H' then nbhan=nbhan+1;
		if substr(anaisenf,i*5+1,1)='I' then nbian=nbian+1;
		end;
	npactot=sum(nbf,nbj,nbn,nbr,nbh,nbi);
	npactotan=sum(nbfan,nbjan,nbnan,nbran,nbhan,nbian);
	if nbf ne nbfan ! nbg ne nbgan ! nbj ne nbjan ! nbr ne nbran ! nbn ne nbnan ! nbh ne nbhan ! nbi ne nbian then do;
		if npactotan<npactot & not (nbjan < nbj) then output mqdat;
	    else if npactotan<npactot & nbjan < nbj then output mqdatj;
		else if npactot<npactotan then output tropdat;
		else output invalf;
		end;
	if anincoher=1 then output incodatnaiss;
	run;

/* RQ : Voir brochure pratique, au début de la 2042 K, pour la signification des lettres*/

/* tropdat :
	ERFS 2009 : dans 2 cas il y a des dates de naissance en trop : ce sont des individus FIP.
	ERFS 2012 : 1 cas (une erreur de déclaration d'un enfant majeur en J et F)
	ERFS 2013 : 3 cas
	ERFS 2014 : 1 cas (2 enfants nés en 2014 dans le declar alors qu'1 seul enfant à charge) ; 0 après corrections 
	ERFS 2015 : 0 cas
	ERFS 2016 : 1 cas ; 0 après correction */
/* invalf : 
	ERFS 2009 : dans 4 cas, la date de naissance de l'enft invalide n'a pas ete reprecisee mais il 
	est en F, dans l'autre un adulte (J) rattaché est donné en F
	ERFS 2012 : dans 2 cas un enfant mineur est classé J dans anaisenf
	ERFS 2013 : 1 cas d'enfant mineur classé J au lieu de F dans nbenf	
	ERFS 2014 : 1 cas : dans declar, semble manquer la date de naissance d'un des enfants titulaire de la carte d'invalidité ; 0 après corrections 
	ERFS 2015 : 1 cas 
	ERFS 2016 : 0 cas */
/*incodatnaiss :
	ERFS 2014 : 10 cas (mineurs en enfants adultes célibataires à charge ou adultes de plus de 26 ans à charge); 0 après corrections 
	ERFS 2015 : 2 cas
	ERFS 2016 : 5 cas ; 0 après correction */
/* mqdat : 
	ERFS 2009 : dans 932 cas il manque la précision des annees de naissance : souvent des enfants EE, qu'il faut les réintégrer.
	ERFS 2012 : 54 + 745 majeurs
	ERFS 2013 : 20 + 385 majeurs
	ERFS 2014 : 26 dont 1 cas où date de naissance d'un enfant handicapé en résidence alternée et titulaire de la carte d'invalidité pas reprécisé avec case I. 
				25 cas non corrigés 
	ERFS 2015 : 22
	ERFS 2016 : 16 avant et après corrections*/
/* mqdatj :
	ERFS 2014 : 406 cas avant et après corrections
	ERFS 2015 : 507 cas après corrections 
	ERFS 2016 : 3 cas avant et après corrections*/

/* A propos de MQDAT, il n'y a pas systématiquement cohérence parfaite entre SIF et ANAISENF. 
	La date de naissance n'est pas renseignée pour toutes les personnes à charge (essentiellement les majeurs 
	rattachés fiscalement à leurs parents, dans l'ordre de 10% des cas). En effet, sur la déclaration papier du moins, 
	il n'y a pas de cases pour mettre la date de naissance des enfants majeurs, juste de la place pour du texte, 
	ce qui doit contribuer à la mauvaise déclaration. Le "bon" nombre de personnes à charge 
	est celui de la variable SIF.
	On a aussi des familles avec beaucoup d'enfants, plus que la place possible pour mettre les naissances. 
	Dans ce cas, les dates de naissances sont ignorées. */ 

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

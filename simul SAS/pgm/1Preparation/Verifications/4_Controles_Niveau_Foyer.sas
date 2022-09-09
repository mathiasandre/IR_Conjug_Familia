/************************************************************************************/
/*																					*/
/*					4_Controles_Niveau_Foyer										*/
/*																					*/
/************************************************************************************/


/* V�rification propres � la table foyer
Il est n�cessaire d'avoir fait tourner le programme init_foyer avant ce programme*/
/************************************************************************************/
/* En entr�e : travail.foyer&anr.					          						*/
/************************************************************************************/
/* PLAN : */
/*	00. V�rification du SIF 
/*	0. Pr�paration d'une table fiscale sans les cases 								*/
/*  1. Analyse de la variable declar (A&M)	 										*/
/*  2. Analyse des �v�nements XYZ dans l'ann�e (M)								 	*/
/*  3. Analyse de la variable mcdvo (M)											 	*/
/*  4. V�rification de valeurs aberrantes (M)									 	*/
/*  5. Analyse de la variable anaisenf (A&M)									 	*/
/************************************************************************************/
/* Remarque : 																		*/
/* - A indique que la correction est automatique dans les pgms de corrections 		*/
/* - M indique un traitement manuel � faire (par exemple modifier un declar)		*/
/************************************************************************************/


/******************************************************************************************/
/*	00	V�rification du SIF
/******************************************************************************************/

/*V�rification de la position de tous les caract�res du SIF pour voir si il y a eu des �volutions par rapport aux ann�es pr�c�dentes
les �ventuelles modifications doivent se g�rer dans la macro g�rer_SIF dans le programme init_foyer et dans la macro Standard_Foyer du prog "macro" */

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

%pos_sif (2016, work, sif1); /*Vide � partir de la 89e position*/
%pos_sif (2016, noyau, sif); /*Vide � partir de la 89e position*/
%pos_sif (2016, travail, sif); /*Vide � partir de la 96e position*/

/*Avec anref 2015 pour v�rif (attention il faut avoir fait tourner le d�but de l'encha�nement avec anref = 2015*/
%pos_sif (2015, travail, sif); /*Vide � partir de la 96e position*/

/*possibilit� de faire tourner cette macro aussi � partir des librairies : (en adaptant les arguments de la macro)  
- "noyau" pour comparer directement avec l'ann�e pr�c�dente (on a la table foyer de l'ann�e pr�c�dente) 
- "travail" pour voir ce que ca donne apr�s les modifications apport�es par la macro g�rer_SIF dans le programme init_foyer
dans les deux cas, pour ces librairie utiliser la variable sif et non sif1*/
/*exemple : %pos_sif (2014, travail, sif);*/


/************************************************************************************/
/*	0. Pr�paration d'une table fiscale sans les cases 								*/
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
/* Probl�me de d�calage sur declar (A)*/
data pb_decalage pb_J;
	set foyer_sans_cases;
	if substr(declar,30,1)='' & substr(declar,31,1) ne '' then do;
		if substr(declar,33,1)='J' then output pb_J;/* Ca se corrige avec declar=substr(declar,1,29)!!substr(declar,31,39); */
		else output pb_decalage;
		end;
	run;
/* 	ERFS 2012 : 651 d�calages lorsque l'on a des enfants majeurs � charge, 0 sinon. */
/* 	ERFS 2013 : 0 d�calages */
/* 	ERFS 2014 : 0 d�calages */
/* 	ERFS 2015 : 0 d�calages */
/* 	ERFS 2016 : 0 d�calages */

/* Coh�rence entre le declar et vousconj, entre declar et mcdvo (M) */
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

/* Coh�rence entre declar et anaisenf (M) */
data declar_enf;
	set foyer_sans_cases; 
	if (substr(declar,30,50) ne anaisenf); 
	run;
/*	ERFS 2009 : 0 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 0 cas 
	ERFS 2014 : 540 cas avant correction (cf. v�rification de la variable anaisenf ci-dessous). 0 cas apr�s 
	ERFS 2015 : 784 cas avant correction ; 0 cas apr�s
	ERFS 2016 : 2 cas avant correction ; 0 cas apr�s*/

/************************************************************************************/
/*  2. Analyse des �v�nements XYZ dans l'ann�e (M)								 	*/
/************************************************************************************/
/* Ev�nements multiples dans la meme annee */
proc freq data=foyer_sans_cases; 
	tables varX*varY*varZ;
	run; 
/*	ERFS 2008 : 1 mariage puis d�c�s et 1 mariage et divorce
	ERFS 2009 : 1 cas de mariage + divorce mais peut-�tre plus qui sont juste mal renseign�
	ERFS 2011 : 0 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 0 cas
	ERFS 2014 : 1 cas : 1 mariage + 1 d�c�s ; pas corrig� (� v�rifier) 
	ERFS 2015 : 1 cas : 1 mariage + 1 d�c�s ; pas corrig� (� v�rifier) 
	ERFS 2016 : 0 cas*/

/* Valeurs vraisemblables pour les dates (M) */ 
proc freq data=foyer_sans_cases;
	table annee_mariage annee_divorce annee_deces;
	run; 
/* 	ERFS 2011 : des valeurs bizarres
	ERFS 2012 : un mariage en 2011, un d�calage sur les dates
	ERFS 2013 : OK 
	ERFS 2014 : OK
	ERFS 2015 : OK
	ERFS 2016 : OK*/

/* Valeurs vraisemblables pour les mois et jours des �v�nements (M) */
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
/* V�rification du statut mcdvo en fonction du nombre de personne sur la d�claration */
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

/* Coh�rence des statuts et des �v�nements */
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
/*  4. V�rification de valeurs aberrantes (M)									 	*/
/************************************************************************************/
/* Ann�es de naissance extr�mes (M) */
data naissance; 
	set foyer_sans_cases;
	if  &anref.-input(substr(vousconj,1,4),4.)>115 /* D�clarant �g� de plus de 115 ans */
	! 	(&anref.-input(substr(vousconj,1,4),4.)<=15 & substr(vousconj,1,4) not in ('9998') )/* D�clarant �g� de moins de 15 ans */
	! 	&anref.-input(substr(vousconj,6,4),4.)>115 /* Conjoint �g� de plus de 115 ans */
	! 	(&anref.-input(substr(vousconj,6,4),4.)<=15 & substr(vousconj,6,4) not in ('9998','9999')); /* Conjoint �g� de moins de 15 ans */
	run;
/*	ERFS 2009 : 0 cas
	ERFS 2012 : 1 cas
	ERFS 2013 : 0 cas
	ERFS 2014 : 0 cas	
	ERFS 2015 : 0 cas
	ERFS 2016 : 0 cas*/

/* V�rification du contenu des 'cases' (M) */
proc freq data=foyer_sans_cases;
	table case_e case_f case_g case_k case_l case_p case_s case_w case_n case_t case_l2;
	run;
/* 	ERFS 2011 : pas de valeurs bizarres sur les cases E � T
	ERFS 2012 : OK
	ERFS 2013 : OK
	ERFS 2014 : OK	
	ERFS 2015 : OK	
	ERFS 2016 : OK*/

/* Nombres d'enfants n�gatifs ou extr�mes (M) */
data enfant; 
	 set foyer_sans_cases;
	/* Nombre d'enfants d�clar�s */
	if nbf<0 ! nbf>18 ! nbg<0 ! nbg>nbf ! nbj<0 ! nbj>5 ! nbn<0 ! nbn>5 ! nbr<0 ! nbr>20 ! nbh<0 ! nbh>5 ! nbi<0 ! nbi>5;
	run;
/*	ERFS 2009 : 0 cas
	ERFS 2012 : 1 cas avec 6 enfants en garde altern�e. On laisse. 
	ERFS 2013 : De m�me, 1 cas avec 6 enfants en garde altern�e. On laisse. 	
	ERFS 2014 : 0 cas	
	ERFS 2015 : 0 cas
	ERFS 2016 : 0 cas*/

/************************************************************************************/
/*  5. Analyse de la variable anaisenf (A&M)									 	*/
/************************************************************************************/
/* D�calages sur anaisenf (A) */
data decal; 
	set foyer_sans_cases;
	if substr(anaisenf,1,1)='' & substr(anaisenf,2,1) ne '';
	run;
/* 	ERFS 2009 : 0 cas
	ERFS 2012 : 651 cas (ceux rep�r�s plus haut)
	ERFS 2013 : 0 cas
	ERFS 2014 : 540 cas ==> d�calage � corriger dans 4_correction_foyer ; OK apr�s correction 
	ERFS 2015 : 784 cas ==> d�calage � corriger dans 4_correction_foyer ; OK apr�s correction
	ERFS 2016 : 2 cas (MEMES CAS QUE LES OBSERVATIONS DE declar_enf) ; OK apr�s correction*/

/* Coherence entre anaisenf et le nombre d'enfants � charge du sif (� faire tourner une fois le d�calage de anaisenf corrig�) */
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

/* RQ : Voir brochure pratique, au d�but de la 2042 K, pour la signification des lettres*/

/* tropdat :
	ERFS 2009 : dans 2 cas il y a des dates de naissance en trop : ce sont des individus FIP.
	ERFS 2012 : 1 cas (une erreur de d�claration d'un enfant majeur en J et F)
	ERFS 2013 : 3 cas
	ERFS 2014 : 1 cas (2 enfants n�s en 2014 dans le declar alors qu'1 seul enfant � charge) ; 0 apr�s corrections 
	ERFS 2015 : 0 cas
	ERFS 2016 : 1 cas ; 0 apr�s correction */
/* invalf : 
	ERFS 2009 : dans 4 cas, la date de naissance de l'enft invalide n'a pas ete reprecisee mais il 
	est en F, dans l'autre un adulte (J) rattach� est donn� en F
	ERFS 2012 : dans 2 cas un enfant mineur est class� J dans anaisenf
	ERFS 2013 : 1 cas d'enfant mineur class� J au lieu de F dans nbenf	
	ERFS 2014 : 1 cas : dans declar, semble manquer la date de naissance d'un des enfants titulaire de la carte d'invalidit� ; 0 apr�s corrections 
	ERFS 2015 : 1 cas 
	ERFS 2016 : 0 cas */
/*incodatnaiss :
	ERFS 2014 : 10 cas (mineurs en enfants adultes c�libataires � charge ou adultes de plus de 26 ans � charge); 0 apr�s corrections 
	ERFS 2015 : 2 cas
	ERFS 2016 : 5 cas ; 0 apr�s correction */
/* mqdat : 
	ERFS 2009 : dans 932 cas il manque la pr�cision des annees de naissance : souvent des enfants EE, qu'il faut les r�int�grer.
	ERFS 2012 : 54 + 745 majeurs
	ERFS 2013 : 20 + 385 majeurs
	ERFS 2014 : 26 dont 1 cas o� date de naissance d'un enfant handicap� en r�sidence altern�e et titulaire de la carte d'invalidit� pas repr�cis� avec case I. 
				25 cas non corrig�s 
	ERFS 2015 : 22
	ERFS 2016 : 16 avant et apr�s corrections*/
/* mqdatj :
	ERFS 2014 : 406 cas avant et apr�s corrections
	ERFS 2015 : 507 cas apr�s corrections 
	ERFS 2016 : 3 cas avant et apr�s corrections*/

/* A propos de MQDAT, il n'y a pas syst�matiquement coh�rence parfaite entre SIF et ANAISENF. 
	La date de naissance n'est pas renseign�e pour toutes les personnes � charge (essentiellement les majeurs 
	rattach�s fiscalement � leurs parents, dans l'ordre de 10% des cas). En effet, sur la d�claration papier du moins, 
	il n'y a pas de cases pour mettre la date de naissance des enfants majeurs, juste de la place pour du texte, 
	ce qui doit contribuer � la mauvaise d�claration. Le "bon" nombre de personnes � charge 
	est celui de la variable SIF.
	On a aussi des familles avec beaucoup d'enfants, plus que la place possible pour mettre les naissances. 
	Dans ce cas, les dates de naissances sont ignor�es. */ 

/****************************************************************
� Logiciel �labor� par l��tat, via l�Insee, la Drees et la Cnaf, 2018. 

Ce logiciel est un programme informatique initialement d�velopp� par l'Insee 
et la Drees. Il permet d'ex�cuter le mod�le de microsimulation Ines, simulant 
la l�gislation sociale et fiscale fran�aise.

Ce logiciel est r�gi par la licence CeCILL V2.1 soumise au droit fran�ais et 
respectant les principes de diffusion des logiciels libres. Vous pouvez utiliser, 
modifier et/ou redistribuer ce programme sous les conditions de la licence 
CeCILL V2.1 telle que diffus�e par le CEA, le CNRS et l'Inria sur le site 
http://www.cecill.info. 

En contrepartie de l'accessibilit� au code source et des droits de copie, de 
modification et de redistribution accord�s par cette licence, il n'est offert aux 
utilisateurs qu'une garantie limit�e. Pour les m�mes raisons, seule une 
responsabilit� restreinte p�se sur l'auteur du programme, le titulaire des 
droits patrimoniaux et les conc�dants successifs.

� cet �gard l'attention de l'utilisateur est attir�e sur les risques associ�s au 
chargement, � l'utilisation, � la modification et/ou au d�veloppement et � 
la reproduction du logiciel par l'utilisateur �tant donn� sa sp�cificit� de logiciel 
libre, qui peut le rendre complexe � manipuler et qui le r�serve donc � des 
d�veloppeurs et des professionnels avertis poss�dant des connaissances 
informatiques approfondies. Les utilisateurs sont donc invit�s � charger et 
tester l'ad�quation du logiciel � leurs besoins dans des conditions permettant 
d'assurer la s�curit� de leurs syst�mes et ou de leurs donn�es et, plus 
g�n�ralement, � l'utiliser et l'exploiter dans les m�mes conditions de s�curit�.

Le fait que vous puissiez acc�der � ce pied de page signifie que vous avez pris 
connaissance de la licence CeCILL V2.1, et que vous en avez accept� les
termes.
****************************************************************/

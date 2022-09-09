/************************************************************************/
/*																		*/
/*       	10_Travail_CLCA							                  	*/
/*																		*/
/************************************************************************/

/* Récupération d'informations pour une éligibilité au CLCA				*/
/* En entrée : 	modele.baseind											*/
/* 			 	travail.cal_indiv										*/
/* 			 	modele.basefam											*/
/* En sortie : 	base.baseind	                                   		*/
/* 				modele.basefam											*/

/* PLAN
	 I.		Repérage des personnes qui ne travaillent pas pour s'occuper d'un enfant
	 II. 	Sélection des familles éligibles en fonction de l'âge des enfants (cal_nais à 3 positions)  
	 III. 	Recoupement des infos, sélection des éligibles au CLCA 
	 IV.	Répartition des bénéficiaires en fonction de leur quotité de travail et enregistrement dans baseind
*/

/*******************************************************************************/
/* I. Repérage des personnes qui ne travaillent pas pour s'occuper d'un enfant */
/*******************************************************************************/
proc sort data=travail.cal_indiv; by ident noi; run;
%macro info;
	/* la variable rdem disparait à partir de l'EEC 2013 */
	data info; 
		set travail.cal_indiv; 
		if %if &anref.<=2012 %then %do; index(cal_rdem,'2')>0 ! %end;	
		/* démission de l'emploi antérieur pour s'occuper de son enfant ou autre membre de sa famille */
		index(cal_SOCCUPENF,'1')>0 ! /* ne recherche pas d'emploi pour s'occuper d'un enfant ou dautre membre de sa famille */
		%if &anref.<2010 %then %do; index(cal_nondic,'4')>0 !  %end;	
		/* non disponibilité pour travailler dans un délai de 2 semaines pour garder des enfants */
		%if &anref.>=2010 %then %do; index(cal_nondic,'3')>0 !  %end;	
		/* non disponibilité pour travailler dans un délai de 2 semaines pour garder des enfants */
		index(cal_dimtyp,'1')>0 ! 	/* réduction d'horaire pour cause de maternité */
		index(cal_TPENF,'1')>0 ! 	
		/* est à temps partiel principalement pour s'occuper de son enfant ou autre membre de sa famille */
		index(cal_rabs,'5')>0 ! 	/* congé parental */
		index(cal_rabs,'3')>0; 		/* congé maternité */
		run; 
	%mend info;
%info;

/**************************************************************************/
/* II. Sélection des familles éligibles en fonction de l'âge des enfants  */
/**************************************************************************/

/* on construit ici un calendrier de naissance (cal_nai); le calendrier comprend 12 caractères, un par mois de l'année : 
- la valeur 1 correspond au mois de naissance pour les enfants de moins d'un an
- la valeur 2 correspond aux mois jusqu'au 6è mois de l'enfant 
- la valeur 3 correspond aux mois jusqu'au 36è mois de l'enfant
=> les familles ayant une valeur 1 ou 2 un mois donné sont éligibles pour ce mois au CLCA (s'ils remplissent par ailleurs
les conditions de la table info ci-dessus) ; celles ayant une valeur 3 un mois donné sont éligibles si elles ont au moins 
deux enfants à charge (au sens des PF).

Ex 1 : cal_nai='000122222333' : une famille dont le plus jeune enfant est né en avril et a eu 6 mois en septembre
Ex 2 : cal_nai='333333333333' : une famille dont le plus jeune enfant avait moins de 36 mois (mais plus de 6 mois) toute l'année
*/

proc sort data=modele.baseind
	(keep=ident noi naia naim ident_fam wpela&anr2. 
	where=(naia ne '' & ident_fam ne '' & (&anref.-input(naia,4.)<4) & (&anref.-input(naia,4.)>=0)))
	out=jeune_enfant;
	by ident_fam noi; /*On rajoute noi pour trier par ordre décroissant d'âge les enfants et construire cal_nai 
	en écrasant dans le bon ordre s'il y a plusieurs enfants de moins de 3 ans. */
	run;
data cal_nai (drop=age_en_mois i noi naia naim); 
	set jeune_enfant;
	by ident_fam;
	format cal_nai $12.; 
	retain cal_nai;

	if first.ident_fam then cal_nai='000000000000';
	age_en_mois=12*(&anref.-input(naia,4.))+12-input(naim,4.); /*Age en mois en décembre de anref., par exemple=10 si né en février de anref*/
	if 0<=age_en_mois<12 then substr(cal_nai,input(naim,4.),1)='1';
	do i=1 to 12;
		if 1<=age_en_mois+i-12<6 and substr(cal_nai,i,1) ne '1'  then substr(cal_nai,i,1)='2';
		if 6<=age_en_mois+i-12<36 and substr(cal_nai,i,1)='0'  then substr(cal_nai,i,1)='3';
		end;
	if last.ident_fam & cal_nai ne '000000000000'; /* On construit un cal_nai par ident_fam */
	label cal_nai='Calendrier naissance';

	/* on crée une variable pour un âge plus détaillé afin de prendre en compte les réformes
	ne concernant que les enfants nés à compter du 1er Avril 2014*/
	naissance_apres_avril=0;
	if 0<=age_en_mois<=8 then naissance_apres_avril=1; /* enfant né après Avril 2014 en 2014 */
	if 8<age_en_mois<=20 then naissance_apres_avril=2; /* enfant né après Avril 2014 en 2015  */
	if 20<age_en_mois<=32 then naissance_apres_avril=3; /* enfant né après Avril 2014 en 2016  */
	if 20<age_en_mois<=23 then naissance_apres_avril=4; /* enfant né après Avril 2014 en 2017  */
	label naissance_apres_avril='Enfant de moins de trois ans né après avril 2014 par année';
	run;

/* Enrichissement de modele.basefam en lui ajoutant cal_nai */
data modele.basefam;
	merge	modele.basefam(in=a)
			cal_nai(in=b keep=ident_fam cal_nai naissance_apres_avril);
	by ident_fam; 
	if a;
	if not b then cal_nai='000000000000' and naissance_apres_avril=0;
	run;

proc sql;
	create table indiv_ac_naissance as
		select a.ident, a.noi, b.cal_nai, b.ident_fam, b.wpela&anr2.
		from modele.baseind as a right outer join cal_nai as b
		on a.ident_fam=b.ident_fam
		order by ident,noi;
	quit;

/****************************************************************/
/*  III. Recoupement des infos, sélection des éligibles au CLCA */
/****************************************************************/
data clca(keep=ident noi cal_nai ident_fam wpela&anr2.); 
	merge 	indiv_ac_naissance(in=b)
			info(in=c); 
	by ident noi;
	if (b & c);
	run;

************************************************************************************************************;
/* IV. Répartition des bénéficiaires en fonction de leur quotité de travail et enregistrement dans baseind */ 
**********************************************************************************************************;
data clca_tp(drop=i); 
	merge 	clca(in=cl)
			travail.cal_indiv; 
	by ident noi; 
	if cl & cal_tp&anref. ne '353535353535353535353535'; /* Exclusion des personnes à temps plein toute l'année */
	/* Calcul de la quotité moyenne de temps travaillé sur la période pendant laquelle il y a un enfant de moins de 3 ans*/
	somme=0; mois=0;
	do i=1 to 12; 
		if substr(cal_nai,i,1) ne '0' then do ; 
			somme=somme+sum(input(substr(cal_tp&anref.,2*i-1,2),2.),0);
			mois=mois+1;
		end;
	end; 
	temps=(somme/mois)/35;
	clca_tp=1; /* CLCA à temps plein: temps <=0.3 pour inclure artificiellement plus de gens dans le temps plein
	car il en mq vraiment trop. Vus les cal_tp concernés, on choisit de faire cette approximation */ 
	if temps>0.3 then clca_tp=2; /* CLCA jusqu'au mi-temps: 0.3<temps<=0.5 */
	if temps>0.5 then clca_tp=3; /* CLCA temps partiel sup: 0.6<temps<=0.8 */
	if temps>0.8 then delete; /* travail quasi à temps plein sur la période d'éligibilité => non éligibles */
	run;

proc sort data=base.baseind; by ident noi; run;
data base.baseind;
	merge	base.baseind(in=b) 
			clca_tp(in=a keep=ident noi clca_tp);
	by ident noi; 
	if b;
	if clca_tp=. or not a then clca_tp=0;
	label clca_tp='Taux de CLCA (éligible)';
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

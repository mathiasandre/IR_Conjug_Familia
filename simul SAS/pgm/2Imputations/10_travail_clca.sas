/************************************************************************/
/*																		*/
/*       	10_Travail_CLCA							                  	*/
/*																		*/
/************************************************************************/

/* R�cup�ration d'informations pour une �ligibilit� au CLCA				*/
/* En entr�e : 	modele.baseind											*/
/* 			 	travail.cal_indiv										*/
/* 			 	modele.basefam											*/
/* En sortie : 	base.baseind	                                   		*/
/* 				modele.basefam											*/

/* PLAN
	 I.		Rep�rage des personnes qui ne travaillent pas pour s'occuper d'un enfant
	 II. 	S�lection des familles �ligibles en fonction de l'�ge des enfants (cal_nais � 3 positions)  
	 III. 	Recoupement des infos, s�lection des �ligibles au CLCA 
	 IV.	R�partition des b�n�ficiaires en fonction de leur quotit� de travail et enregistrement dans baseind
*/

/*******************************************************************************/
/* I. Rep�rage des personnes qui ne travaillent pas pour s'occuper d'un enfant */
/*******************************************************************************/
proc sort data=travail.cal_indiv; by ident noi; run;
%macro info;
	/* la variable rdem disparait � partir de l'EEC 2013 */
	data info; 
		set travail.cal_indiv; 
		if %if &anref.<=2012 %then %do; index(cal_rdem,'2')>0 ! %end;	
		/* d�mission de l'emploi ant�rieur pour s'occuper de son enfant ou autre membre de sa famille */
		index(cal_SOCCUPENF,'1')>0 ! /* ne recherche pas d'emploi pour s'occuper d'un enfant ou dautre membre de sa famille */
		%if &anref.<2010 %then %do; index(cal_nondic,'4')>0 !  %end;	
		/* non disponibilit� pour travailler dans un d�lai de 2 semaines pour garder des enfants */
		%if &anref.>=2010 %then %do; index(cal_nondic,'3')>0 !  %end;	
		/* non disponibilit� pour travailler dans un d�lai de 2 semaines pour garder des enfants */
		index(cal_dimtyp,'1')>0 ! 	/* r�duction d'horaire pour cause de maternit� */
		index(cal_TPENF,'1')>0 ! 	
		/* est � temps partiel principalement pour s'occuper de son enfant ou autre membre de sa famille */
		index(cal_rabs,'5')>0 ! 	/* cong� parental */
		index(cal_rabs,'3')>0; 		/* cong� maternit� */
		run; 
	%mend info;
%info;

/**************************************************************************/
/* II. S�lection des familles �ligibles en fonction de l'�ge des enfants  */
/**************************************************************************/

/* on construit ici un calendrier de naissance (cal_nai); le calendrier comprend 12 caract�res, un par mois de l'ann�e : 
- la valeur 1 correspond au mois de naissance pour les enfants de moins d'un an
- la valeur 2 correspond aux mois jusqu'au 6� mois de l'enfant 
- la valeur 3 correspond aux mois jusqu'au 36� mois de l'enfant
=> les familles ayant une valeur 1 ou 2 un mois donn� sont �ligibles pour ce mois au CLCA (s'ils remplissent par ailleurs
les conditions de la table info ci-dessus) ; celles ayant une valeur 3 un mois donn� sont �ligibles si elles ont au moins 
deux enfants � charge (au sens des PF).

Ex 1 : cal_nai='000122222333' : une famille dont le plus jeune enfant est n� en avril et a eu 6 mois en septembre
Ex 2 : cal_nai='333333333333' : une famille dont le plus jeune enfant avait moins de 36 mois (mais plus de 6 mois) toute l'ann�e
*/

proc sort data=modele.baseind
	(keep=ident noi naia naim ident_fam wpela&anr2. 
	where=(naia ne '' & ident_fam ne '' & (&anref.-input(naia,4.)<4) & (&anref.-input(naia,4.)>=0)))
	out=jeune_enfant;
	by ident_fam noi; /*On rajoute noi pour trier par ordre d�croissant d'�ge les enfants et construire cal_nai 
	en �crasant dans le bon ordre s'il y a plusieurs enfants de moins de 3 ans. */
	run;
data cal_nai (drop=age_en_mois i noi naia naim); 
	set jeune_enfant;
	by ident_fam;
	format cal_nai $12.; 
	retain cal_nai;

	if first.ident_fam then cal_nai='000000000000';
	age_en_mois=12*(&anref.-input(naia,4.))+12-input(naim,4.); /*Age en mois en d�cembre de anref., par exemple=10 si n� en f�vrier de anref*/
	if 0<=age_en_mois<12 then substr(cal_nai,input(naim,4.),1)='1';
	do i=1 to 12;
		if 1<=age_en_mois+i-12<6 and substr(cal_nai,i,1) ne '1'  then substr(cal_nai,i,1)='2';
		if 6<=age_en_mois+i-12<36 and substr(cal_nai,i,1)='0'  then substr(cal_nai,i,1)='3';
		end;
	if last.ident_fam & cal_nai ne '000000000000'; /* On construit un cal_nai par ident_fam */
	label cal_nai='Calendrier naissance';

	/* on cr�e une variable pour un �ge plus d�taill� afin de prendre en compte les r�formes
	ne concernant que les enfants n�s � compter du 1er Avril 2014*/
	naissance_apres_avril=0;
	if 0<=age_en_mois<=8 then naissance_apres_avril=1; /* enfant n� apr�s Avril 2014 en 2014 */
	if 8<age_en_mois<=20 then naissance_apres_avril=2; /* enfant n� apr�s Avril 2014 en 2015  */
	if 20<age_en_mois<=32 then naissance_apres_avril=3; /* enfant n� apr�s Avril 2014 en 2016  */
	if 20<age_en_mois<=23 then naissance_apres_avril=4; /* enfant n� apr�s Avril 2014 en 2017  */
	label naissance_apres_avril='Enfant de moins de trois ans n� apr�s avril 2014 par ann�e';
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
/*  III. Recoupement des infos, s�lection des �ligibles au CLCA */
/****************************************************************/
data clca(keep=ident noi cal_nai ident_fam wpela&anr2.); 
	merge 	indiv_ac_naissance(in=b)
			info(in=c); 
	by ident noi;
	if (b & c);
	run;

************************************************************************************************************;
/* IV. R�partition des b�n�ficiaires en fonction de leur quotit� de travail et enregistrement dans baseind */ 
**********************************************************************************************************;
data clca_tp(drop=i); 
	merge 	clca(in=cl)
			travail.cal_indiv; 
	by ident noi; 
	if cl & cal_tp&anref. ne '353535353535353535353535'; /* Exclusion des personnes � temps plein toute l'ann�e */
	/* Calcul de la quotit� moyenne de temps travaill� sur la p�riode pendant laquelle il y a un enfant de moins de 3 ans*/
	somme=0; mois=0;
	do i=1 to 12; 
		if substr(cal_nai,i,1) ne '0' then do ; 
			somme=somme+sum(input(substr(cal_tp&anref.,2*i-1,2),2.),0);
			mois=mois+1;
		end;
	end; 
	temps=(somme/mois)/35;
	clca_tp=1; /* CLCA � temps plein: temps <=0.3 pour inclure artificiellement plus de gens dans le temps plein
	car il en mq vraiment trop. Vus les cal_tp concern�s, on choisit de faire cette approximation */ 
	if temps>0.3 then clca_tp=2; /* CLCA jusqu'au mi-temps: 0.3<temps<=0.5 */
	if temps>0.5 then clca_tp=3; /* CLCA temps partiel sup: 0.6<temps<=0.8 */
	if temps>0.8 then delete; /* travail quasi � temps plein sur la p�riode d'�ligibilit� => non �ligibles */
	run;

proc sort data=base.baseind; by ident noi; run;
data base.baseind;
	merge	base.baseind(in=b) 
			clca_tp(in=a keep=ident noi clca_tp);
	by ident noi; 
	if b;
	if clca_tp=. or not a then clca_tp=0;
	label clca_tp='Taux de CLCA (�ligible)';
	run; 


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

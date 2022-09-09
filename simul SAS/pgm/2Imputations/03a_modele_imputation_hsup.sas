/****************************************************************************************/
/*               				modele_imputation_hsup								    */		
/*																						*/
/*						- Modele d'imputation des heures supplémentaires -				*/
/*																						*/
/****************************************************************************************/
/* Programme d'imputation des heures supplémentaires en deux temps :                    */
/* Modèlisation de l'exercice d'heures supplémentaires, puis de la rémunération liée à  */ 
/* cet exercice (à partir des tables de l'ERFS 2011).                                     */
/* Les tables en entrée sont toutes relatives au librairie de anref=2011 				*/
/* Les tables en sortie contiennent les coefficients de ces estimations.	    		*/
/****************************************************************************************/
/* En entrée : 	travail.indivi&anr.														*/
/* 				travail.irf&anr.e&anr.													*/
/* 				imput.effectif															*/
/* 																						*/
/* En sortie : 	dossier.model1_hsup à imput.model4_hsup                             	*/
/*				dossier.outest_hsup														*/
/*				dossier.distrib_hsup													*/
/****************************************************************************************/


/* Macros utiles aux étapes du modèle d'imputation */


%macro prepa_tables; 

/* Préparation des tables pour le modèle de participation aux heures supplémentaires */

proc sort data=travail.indivi&anr; by ident noi; run;
proc sort data=travail.irf&anr.e&anr.; by ident noi; run;

data travail.indivi&anr.;
	merge travail.indivi&anr.(in=a) 
	 	  travail.irf&anr.e&anr.(keep=ident noi naia);
	by ident noi;
	if a;
run;

%macro recupere_hsup(anr);
	proc sql;
		create table hsup_ind&anr. as
			select a.*, _hsupVous, _hsupConj, _hsupPac1, _hsupPac2, _hsupVous2, _hsupConj2
			from travail.indivi&anr.(keep=declar1 declar2 persfip persfipd ident noi naia) as a
			inner join travail.foyer&anr.(keep=declar _hsupVous _hsupConj _hsupPac1 _hsupPac2 rename=(declar=declar1)) as b
			on a.declar1=b.declar1
			left join travail.foyer&anr.(keep=declar _hsupVous _hsupConj _hsupPac1 _hsupPac2 rename=(declar=declar2 _hsupVous=_hsupVous2 _hsupConj=_hsupConj2 _hsupPac1=_hsupPac12 _hsupPac2=_hsupPac22)) as c
			on a.declar2=c.declar2
			order by declar1,ident,naia;
		quit;
	data hsup_ind&anr. (keep=ident noi hsup&anr.);
		set hsup_ind&anr.;
		by declar1 ident naia;
		retain pac;
		if first.declar1 then pac=0;
		if persfip='vous' then hsup&anr.=_hsupVous;
		if persfip='conj' then hsup&anr.=_hsupConj;
		if persfip='pac' & pac=0 then do; hsup&anr.=_hsupPac1; pac=1;end;
		else if persfip='pac' & pac=1 then do; hsup&anr.=_hsupPac2; pac=2;end;
		else if persfip='pac' & pac=2 then hsup&anr.=0;
		if declar2 ne '' then do; 
			if persfipd='mon' then hsup&anr.=sum(hsup&anr.,_hsupVous2);
			if persfipd='mad' then hsup&anr.=sum(hsup&anr.,_hsupConj2);
			end;
		label hsup&anr.="Revenus d'heures supplémentaires pour &anref., exonérés si effectués avant août 2012";
		run;
	proc sort data=hsup_ind&anr.; by ident noi; run;
	%mend recupere_hsup;
%recupere_hsup(&anr.);


/* Rajout d'informations et de variables pour préparer les imputations à venir */

data hsup_ind&anr.; 
	merge hsup_ind&anr.(in=a)
		  travail.indivi&anr.(keep=ident noi wprm zsali persfip declar: rename=(zsali=zsali&anr.))
	  	  travail.irf&anr.e&anr.(keep=ident noi naia SEXE AG NAFG017N DDIPL cser cstot tppred PUB3FP ADFDAP STAT2)
	  	  imput.effectif ;
	by ident noi;
	if a;

	det_hsup=(hsup&anr.>0); /* indicatrice de participation aux heures supplémentaires */
	champ_revact=(zsali&anr.>0); /* indicatrice de revenus d'activité */
	AG_n=&anref.-input(naia,4.); /* age au 31/12 */
	classe_age=1*(AG_n>=18 and AG_n<=29)+2*(AG_n>=30 and AG_n<=39)+3*(AG_n>=40 and AG_n<=49)+4*(AG_n>=50 and AG_n<=59)+5*(AG_n>=60);
	taille_entrep=1*(effi<10)+2*(10<=effi<19)+3*(20<=effi<49)+4*(50<=effi<99)+5*(100<=effi<249)+6*(250<=effi<499)+7*(500<=effi);
	if pub3fp in ('1','2','3') then prive=0; if pub3fp='4' then prive=1; /* secteur privé/public */

	champ=0; 
	if champ_revact=1 and ag_n>17 and cser ne '0' AND stat2='2' then champ=1; /* champ global du modèle */

	/* On crée 4 sous-population : sexe croisé avec (privé/public) */
	champ1=0;champ2=0;champ3=0;champ4=0; 
	if champ=1 and sexe='1' and prive=1 then champ1=1;   /* Hommes travaillant dans le privé  */
	if champ=1 and sexe='1' and prive=0 then champ2=1;   /* Hommes travaillant dans le public */
	if champ=1 and sexe='2' and prive=1 then champ3=1;   /* Femmes travaillant dans le privé  */
	if champ=1 and sexe='2' and prive=0 then champ4=1;   /* Femmes travaillant dans le public */
	run; 

/* Les estimations seront faites sur chacune des 4 sous-population (sexe X (prive/public)) */

%macro champ;
	%do i=1 %to 4; 

data montants_hsup&i.; 
	set hsup_ind&anr.; 
	if champ&i.=1; 
	run;

proc univariate data=montants_hsup&i. noprint; var zsali&anr.; output out=quantile_zsali&anr. pctlpts=0 to 100 by 10 pctlpre=P; run;

data montants_hsup&i.;
	set montants_hsup&i.; 
	if _n_=1 then set quantile_zsali&anr.;
	decile=1*(zsali&anr.<P10)+2*(P10<=zsali&anr.<P20)+3*(P20<=zsali&anr.<P30)+4*(P30<=zsali&anr.<P40)+5*(P40<=zsali&anr.<P50)+6*(P50<=zsali&anr.<P60)+
	7*(P60<=zsali&anr.<P70)+8*(P70<=zsali&anr.<P80)+9*(P80<=zsali&anr.<P90)+10*(zsali&anr.>=P90);
	run;

	%end;
%mend champ; 
%champ;

%mend prepa_tables;



%macro participation;

/* L'exercice ou non d'heures supplémentaires sera renseignée dans la variable estim (indicatrice 0/1) */
/* Les seuils ont été calibrées de sorte à retrouver le bon taux de participation aux heures supplémentaires sur chacune des sous-populations pour 2011 */
/* Les valeurs seuils sont entrées dans le code directement */

%let seuil1=0.5331398752 ; %let seuil2=0.4101950668 ; %let seuil3=0.3924764775 ; %let seuil4=0.2952576585 ; 

%do j=1 %to 4; 
data pred_hsup&j.; 
	set pred_hsup&j.; 
	estim=0; 
	if phat > &&seuil&j. then estim=1; /* l'individu a effectué des heures supplémentaires selon la modélisation */
	run;
%end;

%mend participation;



%macro prepa_regression;

/* Définition d'indicatrices pour le modèle de regression de la rémunération liée à l'exercice d'heures supplémentaires */

data pred_hsup&anr.; 
	set pred_hsup&anr.;

	sexe_n=(sexe='1');

	age1=(AG_n>=18 and AG_n<=29);
	age2=(AG_n>=30 and AG_n<=39);
	age3=(AG_n>=40 and AG_n<=49);
	age4=(AG_n>=50 and AG_n<=59);
	age5=(AG_n>=60);

	cser3=(cser="3");
	cser4=(cser="4");
	cser5=(cser="5");
	cser6=(cser="6");

	DDIPL1=(DDIPL="1");
	DDIPL2=(DDIPL="3");
	DDIPL3=(DDIPL="4");
	DDIPL4=(DDIPL="5");
	DDIPL5=(DDIPL="6");
	DDIPL6=(DDIPL="7");

	NAFG017N0=(NAFG017N="00");
	NAFG017N1=(NAFG017N="AZ");
	NAFG017N2=(NAFG017N="C1");
	NAFG017N3=(NAFG017N="C2");
	NAFG017N4=(NAFG017N="C3");
	NAFG017N5=(NAFG017N="C4");
	NAFG017N6=(NAFG017N="C5");
	NAFG017N7=(NAFG017N="DE");
	NAFG017N8=(NAFG017N="FZ");
	NAFG017N9=(NAFG017N="GZ");
	NAFG017N10=(NAFG017N="HZ");
	NAFG017N11=(NAFG017N="IZ");
	NAFG017N12=(NAFG017N="JZ");
	NAFG017N13=(NAFG017N="KZ");
	NAFG017N14=(NAFG017N="LZ");
	NAFG017N15=(NAFG017N="MN");
	NAFG017N16=(NAFG017N="OQ");
	NAFG017N17=(NAFG017N="RU");

	TPPRED_n=(TPPRED='1');

	taille_entrep1=(taille_entrep=1);
	taille_entrep2=(taille_entrep=2);
	taille_entrep3=(taille_entrep=3);
	taille_entrep4=(taille_entrep=4);
	taille_entrep5=(taille_entrep=5);
	taille_entrep6=(taille_entrep=6);
	taille_entrep7=(taille_entrep=7);

	decile1=(decile=1);
	decile2=(decile=2);
	decile3=(decile=3);
	decile4=(decile=4);
	decile5=(decile=5);
	decile6=(decile=6);
	decile7=(decile=7);
	decile8=(decile=8);
	decile9=(decile=9);
	decile10=(decile=10);

	run;

%mend prepa_regression;



/*** Modélisation en deux temps : 1) Participation aux heures supplémentaires
								  2) Rémunération des heures supplémentaires conditionnellement à la participation aux heures supplémentaires ***/

%macro ModeleImputationHsup;

		%if &imputHsup_prem.=oui %then %do;


		/*** 1ere étape : Modèle de participation aux heures supplémentaires ***/

/* On charge les librairies utiles relatives à 2011 */
/* Faire tourner l'enchainement jusqu'à ce programme si ines n'a pas encore tourné sur anref=2011 */

%let anr=11;  
libname travail	    "&chemin_bases.\Base 2011\travaillées";
libname imput	    "&chemin_bases.\Base 2011\imputées";

%prepa_tables;


/* Modèle de participation aux heures supplémentaires sur chacune des 4 sous-population */

%macro det_hsup(champ) ;

proc logistic data=montants_hsup&champ.
	descending outest=betas outmodel=model&champ.;
	class &liste_var_class.;
	model det_hsup= &liste_var. / rsquare /*outroc=roc&champ. */  ;
	output out=pred_hsup&champ.  p=phat xbeta=xbeta stdxbeta=stdxbeta lower=lcl upper=ucl;
	run; 
%mend;


/* champ1 : hommes*prive  */
%let liste_var_class=cstot decile NAFG017N persfip classe_age ddipl taille_entrep TPPRED;
%let liste_var=cstot decile NAFG017N persfip classe_age ddipl taille_entrep TPPRED;
%det_hsup(1);
/* champ2 : hommes*public  */
%let liste_var_class=cstot decile NAFG017N classe_age ddipl;
%let liste_var=cstot decile NAFG017N classe_age ddipl;
%det_hsup(2);
/* champ3 : femmes*prive   */
%let liste_var_class=cstot decile NAFG017N persfip classe_age ddipl taille_entrep TPPRED;
%let liste_var=cstot decile NAFG017N persfip classe_age ddipl taille_entrep TPPRED;
%det_hsup(3);
/* champ4 : femmes*public  */
%let liste_var_class=cstot decile classe_age ddipl taille_entrep   ;
%let liste_var=cstot decile classe_age ddipl taille_entrep   ;
%det_hsup(4);


/* L'exercice ou non d'heures supplémentaires sera renseignée dans la variable estim (indicatrice 0/1) */
/* Les seuils ont été calibrées de sorte à retrouver le bon taux de participation aux heures supplémentaires sur chacune des sous-populations pour 2011 */
/* Les valeurs seuils sont entrées dans le code directement */

%participation;


/* On rassemble toutes les estimations de l'exercice d'heures supplémentaires dans la table pred_hsup&anr. */

data pred_hsup&anr.; 
	set pred_hsup1 pred_hsup2 pred_hsup3 pred_hsup4;
	run;


		/*** 2eme étape : Régression de la rémunération liée à l'exercice d'heures supplémentaires ***/

%prepa_regression;


/* Création d'une table montant_hsup_det pour estimer les paramètres du modèle sur les individus qui font effectivement des heures supplémentaires (observé) */

data montant_hsup_det&anr.;
	set pred_hsup&anr.; 
	if det_hsup=1; 
	log_hsup=log(hsup&anr.); /* log-montant de la rémunération d'hsup */
	run;

/* Modèle de regression du log-montant d'heures supplémentaires (en supposant une distribution lognormale) */

proc reg data= montant_hsup_det&anr. outest=OUTEST_hsup; 
			model log_hsup = zsali&anr. sexe_n age1 age2 age3 taille_entrep1-taille_entrep5 TPPRED_n nafg017n1 nafg017n5 nafg017n8 nafg017n11 nafg017n13;
			title "log montant hsup";
			output out=out p=xbeta2 r=residu;
			run;quit;	
	
/* Application du modèle à l'ensemble de la population : la variable model1 de la table Pred contient alors l'estimation du log-montant d'hsup */

proc score data=pred_hsup&anr. score=OUTEST_hsup type=parms predict out=Pred;
   var zsali&anr. sexe_n age1 age2 age3 taille_entrep1-taille_entrep5 TPPRED_n nafg017n1 nafg017n5 nafg017n8 nafg017n11 nafg017n13;
run;

data pred; 
	set pred; 
	hsup_estim=exp(model1)*estim; /* à voir : ajout éventuel d'un résidu simulé ? */
	run;

/* On va utiliser cette variable hsup_estim pour associer une classe à chaque individu qui effectue des heures supplémentaires
  (Les classes sont formées à partir de quantiles de hsup_estim)
   On donnera alors à chaque individu d'une classe estimée &k., la valeur centrale hsup&k. de la classe observée &k. 
  (Ces dernières classes sont formées à partir de quantiles de hsup11 observés) */


/* Distribution et valeurs centrales des classes observées d'hsup */
proc univariate data=montant_hsup_det&anr. noprint; var hsup&anr.; output out=distrib_hsup&anr. pctlpts=10 to 90 by 10 95 99 pctlpre=Cl; run;

data distrib_hsup&anr.(drop=cl:); 
	set distrib_hsup&anr.; 
	hsup1=0.5*Cl10; hsup2=0.5*(Cl10+Cl20);hsup3=0.5*(Cl20+Cl30);hsup4=0.5*(Cl30+Cl40); hsup5=0.5*(Cl40+Cl50);hsup6=0.5*(Cl50+Cl60);
	hsup7=0.5*(Cl60+Cl70);hsup8=0.5*(Cl70+Cl80);hsup9=0.5*(Cl80+Cl90);hsup10=0.5*(Cl90+Cl95); hsup11=0.5*(Cl95+Cl99);hsup12=Cl99; 
	run;

/* Distribution et classes estimées d'hsup */
data pred_hsup_estim&anr.; 
	set pred; 
	if estim=1; 
	run;
proc univariate data=pred_hsup_estim&anr. noprint; var hsup_estim; output out=distrib_hsup_estim&anr. pctlpts=10 to 90 by 10 95 99 pctlpre=Cle; run;

data pred_hsup_estim&anr.; 
	set pred_hsup_estim&anr.; 
	if _n_=1 then set distrib_hsup_estim&anr.;
	Classe_estim=1*(hsup_estim<Cle10)+ 2*(Cle10<=hsup_estim<Cle20)+3*(Cle20<=hsup_estim<Cle30)+4*(Cle30<=hsup_estim<Cle40)+5*(Cle40<=hsup_estim<Cle50)+
	6*(Cle50<=hsup_estim<Cle60)+7*(Cle60<=hsup_estim<Cle70)+8*(Cle70<=hsup_estim<Cle80)+9*(Cle80<=hsup_estim<Cle90)+10*(Cle90<=hsup_estim<Cle95)
	+11*(Cle95<=hsup_estim<Cle99)+12*(Cle99<=hsup_estim);
	run;

/* Estimation de la rémunération liée à l'exercice d'heures supplémentaire */
data pred_hsup_estim&anr.; 
	set pred_hsup_estim&anr.; 
	if _n_=1 then set distrib_hsup&anr.; 

	hsup_classe=(classe_estim=1)*hsup1+(classe_estim=2)*hsup2+(classe_estim=3)*hsup3+(classe_estim=4)*hsup4+(classe_estim=5)*hsup5+(classe_estim=6)*hsup6+
	(classe_estim=7)*hsup7+(classe_estim=8)*hsup8+(classe_estim=9)*hsup9+(classe_estim=10)*hsup10+(classe_estim=11)*hsup11+(classe_estim=12)*hsup12;

	hsup_final=1/classe_estim*hsup_estim+(1-1/classe_estim)*hsup_classe ; 
	/* Critère ici empirique : hsup_estim sous-estime les rémunérations observées, et d'autant plus que la classe est haute. 
	   Cette pondération permet ainsi de rapprocher nettement les deux distributions observées et estimées pour ceux qui font des heures supplémentaires */
	run;


/* On met dans la table pred les estimations de rémunérations d'heures supplémentaires (variable hsup_final) */

proc sort data=pred; by ident noi; run;
proc sort data=pred_hsup_estim&anr.; by ident noi; run;
data pred&anr.; 
	merge pred(in=a)
		  pred_hsup_estim&anr.(keep=ident noi hsup_classe hsup_final);
	by ident noi; 
	if a; 
	run;
data pred&anr.;
	set pred&anr.; 
	if hsup_final=. then hsup_final=0;
	run;


/* Nettoyage et sauvegarde des tables utiles*/

data dossier.model1_hsup; set model1 ; run;
data dossier.model2_hsup; set model2 ; run;
data dossier.model3_hsup; set model3 ; run;
data dossier.model4_hsup; set model4 ; run;
data dossier.outest_hsup; set outest_hsup; run;
data dossier.distrib_hsup; set distrib_hsup&anr.; run;

proc datasets mt=data library=work kill;run;quit;  

/* Retour sur l'anref initial de l'enchainement */

%let anr=%substr(&anref.,3,2);
libname travail	    "&chemin_bases.\Base &anref.\travaillées";
libname imput	    "&chemin_bases.\Base &anref.\imputées";

		%end;

%mend ModeleImputationHsup;

%ModeleImputationHsup;



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

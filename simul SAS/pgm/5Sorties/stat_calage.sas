/********************************************************************/
/*                         stat_calage			                    */
/********************************************************************/

/********************************************************************/
/* Calcul de statistiques sur les effets du calage					*/
/*																	*/
/* Tables en entr�e : var_calage									*/
/*					  travail.foyer&anr.							*/
/*																	*/	
/* Fichiers en sortie :	effet calage sur marge.xls					*/
/*																	*/
/********************************************************************/
/* Plan du programme												*/
/* I - Evolution des variables apr�s les diff�rents calages			*/
/* II - D�formation des poids 										*/
/* III - Evolutions d'agr�gats utiles pour la d�rive des revenus	*/
/********************************************************************/

/* La table var_calage est cr��e par le programme 8_ponderations */
data var_calage;
	label tymen1='Pers seules/m�n complexes moins 60'
		  tymen2='Couples sans enfant moins 60'
		  tymen3='couples avec 1 enfant'
		  tymen4='couples avec 2 enfants'
		  tymen5='couples avec au moins 3 enfants'
		  tymen6='parents isol�s'
		  tymen7='Pers seules/m�n complexes plus 60'
		  tymen8='Couples sans enfant plus 60'

		  locat='nombre de m�nages locataires'

		  agenf1='0-2 ans'
		  agenf2='3-5 ans'
		  agenf3='6-9 ans'
		  agenf4='10-14 ans'
		  agenf5='15-19 ans'
		  agenf6='20-24 ans'

		  aghom1='homme, 25-34 ans'
		  aghom2='homme, 35-49 ans'
		  aghom3='homme, 50-59 ans'

		  agfem1='femme, 25-34 ans'
		  agfem2='femme, 35-49 ans'
		  agfem3='femme, 50-59 ans'

		  agvieux1='60-64 ans'
		  agvieux2='65-69 ans'
		  agvieux3='70-74 ans'
		  agvieux4='75-79 ans'
		  agvieux5='80 ans et +'

		  act1='Ch�meurs'
		  act2='Actifs occup�s � temps plein'
		  act3='Actifs occup�s � temps partiel'
		  act4='Femmes inactives avec enfant'
		  act5='Autres inactifs 20-24 ans'
		  act6='Autres inactifs 25-59 ans'

		  cs1='cadres'
		  cs2='professions interm�diaires'
		  cs3='employ�s et ouvriers qualifi�s'
		  cs4='employ�s et ouvriers non qualifi�s'
			
		  nbagr='nombre d agriculteurs'
		  nbindep='nombre d ind�pendants'
		  nbindep2='agriculteurs + ind�pendants'
		  nbsal='nombre de salari�s'
		  nbret='nombre de retrait�s'

		  /*ztsam='traitements et salaires dont ch�mage'*/
		  zsalm='traitements et salaires'
		  zchom='traitements et salaires'

		  zpensm='pensions retraites et rentes'

		  nbdecsal='nombre d�clarations avec ztsaf>0'
		  nbdecpens='nombre de d�clarations avec zpensf>0'
		  nbdecbag='nombre de d�clarations avec zragf !=0'
		  nbdecbic='nombre de d�clarations avec zricf !=0'
		  nbdecbnc='nombre de d�clarations avec zrncf !=0';

	set var_calage;
	array typo tymen1-tymen8;
	do i=1 to 8;
		typo(i)=(tymen=i);
		end;
	drop i;
	%macro pond;
		%if &noyau_uniquement.=oui %then %do;
			wpela=wprm;
			%end;
		%mend;
	%pond;
	run;

%global var_calage; 

%macro def_var_calage;
%if &anref.<=2009 %then %do; /*2009 et non 2011 car on prend les variables de calage de anref+2*/
	%let var_calage=tymen1-tymen8 locat agenf1-agenf6 aghom1-aghom3 agfem1-agfem3 agvieux1-agvieux5 act1-act6
	                cs1-cs4 nbagr nbindep nbindep2 nbsal nbret 
					ztsam zpensm zragm zricm zrncm 
					nbdecsal nbdecpens nbdecbag nbdecbic nbdecbnc;
	%end; 
%else %do;
	%let var_calage=tymen1-tymen8 locat agenf1-agenf6 aghom1-aghom3 agfem1-agfem3 agvieux1-agvieux5 act1-act6
	                cs1-cs4 nbagr nbindep nbindep2 nbsal nbret 
					zsalm zchom zpensm zragm zricm zrncm 
					nbdecsal nbdeccho nbdecpens nbdecbag nbdecbic nbdecbnc;
	%end; 
%mend;
%def_var_calage;

/************************************************************/
/* I - Evolution des variables apr�s les diff�rents calages */
/************************************************************/

proc means data=var_calage noprint;
	var &var_calage.;
	weight wpela;
	output out=effet_calage (drop= _type_ _freq_) sum=;
	run;

proc means data=var_calage noprint;
	var &var_calage.;
	weight wpela&anr.;
	output out=effet_calage1 (drop= _type_ _freq_) sum=;
	run;
proc means data=var_calage noprint;
	var &var_calage.;
	weight wpela&anr1.;
	output out=effet_calage2 (drop= _type_ _freq_) sum=;
	run;
proc means data=var_calage noprint;
	var &var_calage.;
	weight wpela&anr2.;
	output out=effet_calage3 (drop= _type_ _freq_) sum=;
	run;

data effet_calage ;
	set effet_calage effet_calage1 effet_calage2 effet_calage3;
	run;

proc transpose data=effet_calage out=effet_calage (rename=(col1=reference col2=calage1 col3=calage2 col4=calage3)); run;

data effet_calage;
	set effet_calage;
	effet_calage1=(calage1/reference-1)*100;
	effet_calage2=(calage2/calage1-1)*100;
	effet_calage3=(calage3/calage2-1)*100;
	effet_calage_tot=(calage3/reference-1)*100;
	run;
proc export data=effet_calage outfile="&sortie_cible./effet calage sur marge" dbms=&excel_exp. replace;
	run;

/************************************************************/
/* II - D�formation des poids 								*/
/************************************************************/

data var_calage;
	set var_calage;
 	label wpela&anr.='poids apr�s le 1er calage'
		  wpela&anr1.='poids apr�s le 2�me calage'
		  wpela&anr2.='poids apr�s le 3�me calage'
		  deform_calage1='deformation des poids apr�s le 1er calage en %'
		  deform_calage2='deformation des poids apr�s le 2�me calage en %'
		  deform_calage3='deformation des poids apr�s le 3�me calage en %'
		  deform_calage='deformation entre les poids apr�s les 3 calages et les poids de r�f�rence en %';

	deform_calage1=(wpela&anr./wpela-1)*100;
	deform_calage2=(wpela&anr1./wpela&anr.-1)*100;
	deform_calage3=(wpela&anr2./wpela&anr1.-1)*100;
	deform_calage=(wpela&anr2./wpela-1)*100;
	run;
proc means data=var_calage noprint;
	var wpela: deform:;
	output out=deformation (drop= _type_ _freq_);
	run;
proc means data=var_calage noprint;
	var wpela: deform:;
	output out=deform1 (drop= _type_ _freq_) median=;
	run;
proc means data=var_calage noprint;
	var wpela: deform:;
	output out=deform2 (drop= _type_ _freq_) P5=;
	run;
proc means data=var_calage noprint;
	var wpela: deform:;
	output out=deform3 (drop= _type_ _freq_) P10=;
	run;
proc means data=var_calage noprint;
	var wpela: deform:;
	output out=deform4 (drop= _type_ _freq_) P90=;
	run;
proc means data=var_calage noprint;
	var wpela: deform:;
	output out=deform5 (drop= _type_ _freq_) P99=;
	run;
data deformation;
	set deformation deform1 deform2 deform3 deform4 deform5;
	run;

proc transpose data=deformation out=deformation (drop=col1 col5 rename=(col2=min col3=max col4=moyenne col6=mediane
												 col7=P5 col8=P10 col9=P90 col10=P99)); run;
proc export data=deformation outfile="&sortie_cible./effet calage sur marge" dbms=&excel_exp. replace;
	sheet='deformation';
	run;

/*****************************************************************/
/* III - Evolutions d'agr�gats utiles pour la d�rive des revenus */
/*****************************************************************/
data foyer (keep=ident zracf zvamf zrff_hd zdff nbdeczrac nbdeczrcm nbdeczrf nbdeczdf);
	set travail.foyer&anr.;
	%CalculAgregatsERFS;
	zrff_hd=sum(zfonf,_4bb,_4bc); 
	zdff=sum(_4bb,_4bc); 
	nbdeczrac=(zracf>0);
	nbdeczrcm=(zvamf>0); 
	nbdeczrf=(zrff_hd>0);
	nbdeczdf=(zdff>0);
	run;

proc means noprint nway data=foyer noprint;
	class ident;
	var zracf zvamf zrff_hd zdff nbdeczrac nbdeczrcm nbdeczrf nbdeczdf;
	output out=agregats(drop=_type_ _freq_) 
			sum=zracm zvamm zrfm_hd zdfm nbdeczrac nbdeczrcm nbdeczrcf nbdeczdf;
	run;

proc sort data=var_calage; by ident; run;
data agregats;
	merge 	agregats (in=a) 
			var_calage (keep=ident wpela&anr. wpela&anr1.);
	if a;
	label zracm='revenus accessoires du m�nage (BIC/BNC non prof)'
		  zvamm='revenus de capitaux mobilier du m�nage'
		  zrfm_hd='revenus fonciers hors d�ficits du m�nage'
		  zdfm='d�ficits fonciers du m�nage'
		  nbdeczrac='nombre de d�clarations avec revenus accessoires'
		  nbdeczrcm='nombre de d�clarations avec RCM'
		  nbdeczrcf='nombre de d�clarations avec revenus fonciers hors d�ficits'
	      nbdeczdf='nombre de d�clarations avec d�ficits fonciers'; 
	run;

proc means data=agregats noprint;
	var zracm zvamm zrfm_hd zdfm nbdeczrac nbdeczrcm nbdeczrcf nbdeczdf;
	weight wpela&anr.;
	output out=agregats&anr. (drop= _type_ _freq_) sum=;
	run;
proc means data=agregats noprint;
	var zracm zvamm zrfm_hd zdfm nbdeczrac nbdeczrcm nbdeczrcf nbdeczdf;
	weight wpela&anr1.;
	output out=agregats&anr1. (drop= _type_ _freq_) sum=;
	run;
data agregats_cale;
	set agregats&anr. agregats&anr1.;
	run;
proc transpose data=agregats_cale out=agregats_cale (rename=(col1=somme_&anr. col2=somme_&anr1.)); run;
proc export data=agregats_cale outfile="&sortie_cible./effet calage sur marge" dbms=&excel_exp. replace;
	sheet='agregats pour derive';
	run;

/* Histogrammes pour repr�senter la distribution des rapports de poids avant / apr�s calage
	V�rifier que l'on n'assiste pas � une accumulation des rapports des poids trop importante autour des bornes entr�es pour le calage. 
	Si c'est le cas, c'est le signe de bornes trop serr�es : rel�cher un peu la contrainte. */

/* ATTENTION SI L'ON TRAVAILLE SUR L'ELARGIE ENTRER A LA MAIN WPELA AU LIEU DE WPRPM */
/*
data z;
	set travail.menage&anr.;
	r&anr.=wpela&anr./wprm; 
	r&anr1.=wpela&anr1./wpela&anr.;
	r&anr2.=wpela&anr2./wpela&anr1.;
	run;
proc univariate data=z;
	var r&anr. r&anr1. r&anr2.;
	histogram;
	run;
proc delete data=z; run;
*/


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

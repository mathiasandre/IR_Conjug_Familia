/********************************************************************/
/*                   		8_pond�rations	                        */
/********************************************************************/

/********************************************************************/
/* Calcul des pond�rations pour anr1. et anr2.						*/
/* Tables en entr�e :												*/
/*	travail.irf&anr.e&anr.											*/
/*	travail.indivi&anr.												*/
/*	travail.foyer&anr.												*/
/*	travail.mrf&anr.e&anr.											*/
/*	travail.menage&anr.												*/	
/*																	*/
/* Tables en sortie :												*/
/*	travail.menage&anr.												*/
/*																	*/
/* Plan du programme												*/
/* I 	- construction des variables de calage						*/
/* II 	- calage sur marge											*/
/********************************************************************/

/****************************************/
/* I: Cr�ation des variables de calage  */
/****************************************/

proc sql;
	create table ind as
	select sexe,ag,naia,naim,lprm,officc,acteu,titc,tppred,cstot,stc,b.*,logt,xyz,ag5,
		case when ag<'15' then '1' else matri end as matri
	from travail.irf&anr.e&anr.(keep=ident noi sexe matri ag naia naim ag5 lprm officc acteu titc tppred cstot stc) as a
	right join travail.indivi&anr.(keep=ident wp: noi quelfic declar2 &RevIndividuels. zrago) as b
	on (a.ident=b.ident and a.noi=b.noi)
	inner join travail.mrf&anr.e&anr.(keep=ident logt) as c on a.ident=c.ident
	left join (select distinct xyz, ident from travail.foyer&anr.(keep=ident xyz) group by ident having xyz=max(xyz)) as d on a.ident=d.ident
	where naia ne '20&anr1.' /* on �limine les enfants � na�tre */
	order by ident,noi;
	quit;

data men(keep=ident tymen locat propm60 adult enf nb: wp:);
	/* ATTENTION : n'importe quelle modification de cette �tape doit �tre transmise aux personnes nous fournissant les marges EEC */
	set ind(keep=ident noi lprm matri sexe ag logt cstot stc wp:);
	by ident;
	if input(ag,3.)<18 & matri='' then matri='1';

 	retain adult enf attrib1 attrib2 menplus60 cat1-cat4; 
	if first.ident then do; 
		adult=0; enf=0;	attrib1=0; attrib2=0; menplus60=0; cat1=0; cat2=0; cat3=0; cat4=0; 
		end;

	/* Nombre d'adultes et d'enfants */
	if lprm='3' & input(ag,3.)<=20 & matri='1' then enf=enf+1;
	else adult=adult+1;

	attrib1=attrib1+(lprm='1');
	attrib2=attrib2+(lprm='2');
	menplus60=menplus60+(input(ag,3.)>=60);

	/* Nombre d'agriculteurs, ind�pendants, salari�s et retrait�s */
	if '10'<=cstot<='13' then cat1=cat1+1; 											/* Agriculteurs */
	else if cstot in ('21','22','31') & stc='1' then cat2=cat2+1;					/* Ind�pendants */
	else if '21'<=cstot<='69' then cat3=cat3+1; 									/* Salari�s */
	else if (('71'<=cstot<='78' & input(ag,3.)>=53) ! input(ag,3.)>=67) then cat4=cat4+1;/* Retrait�s */

	/* Typologie des m�nages */
	if last.ident then do;
		if enf>0 then menplus60=0; /* pour les menages avec un enfant, on ne distingue pas plus et moins de 60 ans */
		coup=(attrib1=1 & attrib2=1);

		if not menplus60 & not coup & not enf then tymen=1;	/* personnes seules et menages complexes moins 60 ans sans couple et sans enfant */
		else if not menplus60 & coup & not enf then tymen=2;/* couples sans enfant */
		else if coup & enf=1 then tymen=3;					/* couples avec 1 enfant */
		else if coup & enf=2 then tymen=4;					/* couples avec 2 enfants */
		else if coup & enf>=3 then tymen=5;					/* couples avec au moins 3 enfants */
		else if enf then tymen=6;							/* parents isoles */
		else if menplus60 & not coup then tymen=7;			/* personnes seules et menages complexes comprenant un individu + 60 ans */
		else if menplus60 & coup then tymen=8;				/* couples (sans enfant) dont un individu + 60 ans */

		/* statut d'ocupation du logement */
		locat=(logt in ('3','4','5'));
		propm60=(not menplus60 & not locat); /*menages 'proprietaires' sans indiv plus de 60 ans */

		/* M�nage avec au moins 1 salari�, 1 retrait�, etc... */
		nbagr=(cat1>0); 
		nbindep=(cat2>0); 
		nbsal=(cat3>0); 
		nbret=(cat4>0);
		nbindep2=(cat1+cat2>0); 
		output;
		end;
	run;

/*On utilise en suite les variables de l'enqu�te emploi au niveau individuel */
data ind;
	/* ATTENTION : n'importe quelle modification de cette �tape doit �tre transmise aux personnes nous fournissant les marges EEC */
	merge ind men(keep=ident enf); by ident;

	/* Personnes �g�es par tranches d'�ge */
	agvieux1=(60<=input(ag,3.)<65);
	agvieux2=(65<=input(ag,3.)<70);
	agvieux3=(70<=input(ag,3.)<75);
	agvieux4=(75<=input(ag,3.)<80);
	agvieux5=(80<=input(ag,3.));

	/* Enfants par tranches d'�ge*/
	agenf1=(0<=input(ag,3.)<3);
	agenf2=(3<=input(ag,3.)<6);
	agenf3=(6<=input(ag,3.)<10);
	agenf4=(10<=input(ag,3.)<15);
	agenf5=(15<=input(ag,3.)<20);
	agenf6=(20<=input(ag,3.)<25);

	/* sexe*age adultes d'age intermediaire */
	aghom1=(sexe='1')*(25<=input(ag,3.)<35);
	aghom2=(sexe='1')*(35<=input(ag,3.)<50);
	aghom3=(sexe='1')*(50<=input(ag,3.)<60);

	agfem1=(sexe='2')*(25<=input(ag,3.)<35);
	agfem2=(sexe='2')*(35<=input(ag,3.)<50);
	agfem3=(sexe='2')*(50<=input(ag,3.)<60);

	/* activite-chomage parmi les 'ages actifs' 20-59 ans */
	act1=(20<=input(ag,3.)<60)*(officc='1');						/* Inscrit comme demandeur d'emploi */
	act2=(20<=input(ag,3.)<60)*((acteu='1' or titc='1')&(tppred ne '2')&(act1 ne 1)); /* Titc=1 : les eleves fonctionnaires sont rajout�s car r�mun�r�s */
	act3=(20<=input(ag,3.)<60)*((acteu='1' or titc='1')&(tppred='2')&(act1+act2 ne 1));
	act4=(20<=input(ag,3.)<60)*((sexe='2' & lprm in ('1','2') & enf>0)&(act1+act2+act3 ne 1)); /* Femmes inactives avec enfant */
	act5=(20<=input(ag,3.)<60)*((input(ag,3.)<25) and (sum(of act1-act4)=0)); /* Inactifs de moins 24 ans : approximativement les etudiants */
	act6=(20<=input(ag,3.)<60)*(sum(of act1-act5)=0);

	/* cat�gorie socio parmi les actifs occupes et chomeurs 20-59 ans */
	cs1=(act1+act2+act3)*(substr(cstot,1,1)='3' ! cstot in ('23','74'));		/* Cadres et chefs d'entreprise */
	cs2=(act1+act2+act3)*(substr(cstot,1,1)='4' ! cstot in ('22','75'));	/* Professions interm�diaires et commercants */
	cs3=(act1+act2+act3)*(('52'<=cstot<='54') ! cstot in ('21','62','64','65','77'));
	/* Employes qualifies, artisans, ouvriers qualifies sauf ouv qualifies de l'artisanat, anciens employes*/
	cs4=(act1+act2+act3)*(sum(of cs1-cs3)=0); /* Ouvriers et employes non qualifies, ouv qualifies type artisanal, ouv agricoles, agriculteurs, divers autres */

	quelfic1=(quelfic='EE&FIP');
	quelfic2=(quelfic='EE_CAF');
	quelfic3=(quelfic='EE');
	quelfic4=(quelfic='EE_NRT');

	hina1=(act6=1)*(aghom1=1);
	hina2=(act6=1)*(aghom2=1);
	hina3=(act6=1)*(aghom3=1);
	run;


%let VarCalInd=agvieux1-agvieux5 agenf1-agenf6 aghom1-aghom3 agfem1-agfem3 act1-act6 cs1-cs4 quelfic1-quelfic4  hina1-hina3;
proc means data=ind noprint; 
	var &VarCalInd.; 
	by ident; 
	output out=MenVarCalInd(drop=_type_ _freq_) sum=&VarCalInd.;
	run;
data MenVarCal;
	merge 	MenVarCalInd
			Men (keep=ident wp: tymen locat propm60 adult enf nbagr nbindep nbindep2 nbsal nbret);
	by ident;
	run;

/* Calcul des marges fiscales (nombre de d�clarations fiscales comportant un type de revenus particulier
   et les masses de revenus cat�goriels) */
%macro calcul_marges (annee);
	proc sql;
		create table FiscVarCal as
		select ident,
			%if &annee.<=2011 %then %do; /*avant 2012, les marges de salaire et chomage ne sont pas s�par�es donc on a un seul agr�gat*/
				count(case when ztsaf ne 0 then 1 else . end) as nbdecsal,/*nb de d�clarations salaires et assimil�s*/
				%end;
			%else %do; /*� partir de 2012, on prend en compte s�paremment l'agr�gat zsalf et zchof car les marges sont disponibles */
				count(case when zsalf ne 0 then 1 else . end) as nbdecsal,/*nb de d�clarations salaires */
				count(case when zchof ne 0 then 1 else . end) as nbdeccho,/*nb de d�clarations chomage et pr�retraite */ 
				%end;
			case when &annee.>2010 then count(case when zperf ne 0 then 1 else . end) 
				else count(case when (zrstf+zpif) ne 0 then 1 else . end) end as nbdecpens,
		/*nb de d�clarations retraites, pensions et rentes. Avant 2011 on ne prenait que l'agr�gat retraite strictement.
		  A partir de 2011 on prend l'agr�gat retraites, pensions et rentes qui est en est tr�s proche. 
			Depuis l'ERFS de 2014 les pensions d'invalidit� (zpif) sont d�clar�es � part des retraites 
			TO DO : V�rifier que la cible correspond bien � l'agr�gat �largi avec pensions d'invalidit�
			pour les ann�es o� les pensions d'invalidit� sont d�clar�es � part */
			count(case when zragf ne 0 then 1 else . end) as nbdecbag,/*nb de d�clarations b�n�fices agricoles*/
			count(case when zricf ne 0 then 1 else . end) as nbdecbic,/*nb de d�clarations b�n�ficis industriels et commerciaux*/
			count(case when zrncf ne 0 then 1 else . end) as nbdecbnc /*nb de d�clarations b�n�fices non commerciaux*/
		from travail.foyer&anr.(keep=ident %if &annee.<=2011 %then ztsaf; %else zsalf zchof;
		zperf zrstf zpif zragf zricf zrncf)  
		group by ident
		order by ident;
		quit;

	/* Correction du nombre de d�clarations � cause du d�faut d'appariement par une prise en compte 
		des revenus dans le cas de d�clarations non retrouv�es : declar2 vide alors qu'il y a un 
		�v�vement dans l'ann�e. A partir de l'ERFS 2011, ce cas ne se pr�sente plus que pour les d�c�s 
		(pour �tre exact il reste quelques rares cas pour des pacs ou des mariages en 2011)*/
	data decManquante(keep=ident z: decmqsal %if &annee.>2011 %then decmqcho; decmqpens decmqbag decmqbic decmqbnc);
		set ind(keep=ident noi quelfic declar2 xyz z:);
		%if &annee.<=2011 %then %do;
		decmqsal=(declar2='' & xyz in ('X','Y','Z'))*(zsali+zchoi>0);
			%end;
		%else %do; 
		decmqsal=(declar2='' & xyz in ('X','Y','Z'))*(zsali>0);
		decmqcho=(declar2='' & xyz in ('X','Y','Z'))*(zchoi>0); 
			%end;
		decmqbag=(declar2='' & xyz in ('X','Y','Z'))*(zragi ne 0);
		decmqbic=(declar2='' & xyz in ('X','Y','Z'))*(zrici ne 0);
		decmqbnc=(declar2='' & xyz in ('X','Y','Z'))*(zrnci ne 0);
		decmqpens=(declar2='' & xyz in ('X','Y','Z'))*((zrsti+zpii+zalri+zrtoi>0)*(&annee.>2010)+(zrsti+zpii>0)*(&annee.<=2010));
		ztsai=zsali+zchoi;
		zpens=(zrsti+zpii+zalri+zrtoi)*(&annee.>2011)+(zrsti+zpii)*(&annee.<=2011);
		run;
	proc means noprint nway data=decManquante;
		class ident;
		var %if &annee.<=2011 %then ztsai; %else zsali zchoi decmqcho; zpens zragi zrici zrnci decmqsal decmqpens decmqbag decmqbic decmqbnc; 
		output out=decManquanteCal(drop=_type_ _freq_) sum=%if &annee.<=2011 %then ztsam; %else zsalm zchom nbmqcho ; 
		zpensm zragm zricm zrncm nbmqsal nbmqpens nbmqbag nbmqbic nbmqbnc;
		run;

	/*regroupement des variables de calage issus de la macro %calcul_marges*/
	data var_calage(drop=nbmqsal nbmqpens nbmqbag nbmqbic nbmqbnc %if &annee.>2011 %then nbmqcho;);
		merge 	MenVarCal(in=a) 
				decManquanteCal 
				FiscVarCal;
		by ident; if a;
		nbdecsal=sum(0,nbdecsal,nbmqsal);  
		%if &annee.>2011 %then nbdeccho=sum(0,nbdeccho,nbmqcho);;
		nbdecpens=sum(0,nbdecpens,nbmqpens);
		nbdecbag=sum(0,nbdecbag,nbmqbag);
		nbdecbic=sum(0,nbdecbic,nbmqbic);
		nbdecbnc=sum(0,nbdecbnc,nbmqbnc);
		run;

%mend;

/*************************/
/* II: calage sur marge  */
/*************************/

%macro calage(FILENAME,ANNEE,LO,UP,POIDS,POIDSFIN);
	/* Cette macro calage permet de faire la repond�ration des pseudo-ERFS en utilisant les marges contenues
	dans le fichier excel FILENAME, � l'onglet correspondant � la bonne ann�e.
	Les param�tres Lo et UP sont ceux de la macro CALMAR (ie les ratios minimal et maximal entre 
	le poids de sortie et le poids initial.
	POIDS correspond au nom de la variable de pond�ration en entr�e,
	POIDSFIN correspond au nom de la variable de pond�ration modifi�e.*/
	/* Comme la macro CALMAR �crase la macrovariable &anr, on la sauvegarde dans &anbis pour la reprendre 
	� la fin de la macro CALMAR */ 
	%local anbis;
	%let anbis=&anr.; 
	%if &noyau_uniquement.=non /* �largie */ and &ANNEE.=&anref. /* 1er calage */ %then %do; %let POIDS=wpela; %end;
	proc import OUT= WORK.MARGE
	            DATAFILE=&FILENAME.
	            dbms=&excel_imp. REPLACE;
		sheet="base%eval(&ANNEE.)";
		RUN;
	data marge; 
		set marge;
		if var=%if &ANNEE.<=2011 %then 'ztsam'; %else 'zsalm'; then mar1=mar1+exp(39*log(2));
		%if &ANNEE. ne &anref. %then %do; if substr(var,1,1) ne 'z'; %end; 
		%if &ANNEE.=&anref.+2 %then %do; if substr(var,1,5) ne 'nbdec'; %end;
		run;

	%calcul_marges(annee=&ANNEE.);
	%if &ANNEE. ne &anref. %then %do; 
		proc sort data=poi; by ident; run; 
		data var_calage;
			merge 	var_calage 
					poi;
			by ident;
		%if &ANNEE.=&anref.+1 %then %do; poiinit=wpela&anr.*%sysevalf(&pop_an1./&pop_an.); %end; /* evolution du nombre d'individus */
		%if &ANNEE.=&anref.+2 %then %do; poiinit=wpela&anr1.*%sysevalf(&pop_an2./&pop_an1.); %end;
			run;
		%end;
	%CALMAR(DATA=var_calage,DATAMAR=marge,M=3,Lo=&Lo.,UP=&UP.,IDENT=ident,POIDS=&POIDS.,POIDSFIN=&POIDSFIN.,DATAPOI=poi,PCT=NON,OBSELI=oui);
	%let anr=&anbis.;
	%if &ANNEE.=&anref.+2 %then %do; 
		proc sort data=poi; by ident; run; 
		data var_calage;
			merge 	var_calage 
					poi;
			by ident;
			run;
		%end;
	%mend;


%Macro DefinitBornesCalage;
	%global borne_inf_cal0 borne_sup_cal0 borne_inf_cal1 borne_sup_cal1 borne_inf_cal2 borne_sup_cal2;
	%if &noyau_uniquement.=oui %then %do;
		/* Bornes = celles trouv�es en t�tonnant sur l'ERFS noyau */
		%let borne_inf_cal0=&borne_inf_cal0_noy.;
		%let borne_sup_cal0=&borne_sup_cal0_noy.;
		%let borne_inf_cal1=&borne_inf_cal1_noy.;
		%let borne_sup_cal1=&borne_sup_cal1_noy.;
		%let borne_inf_cal2=&borne_inf_cal2_noy.;
		%let borne_sup_cal2=&borne_sup_cal2_noy.;
		%end;
	%else %if &noyau_uniquement.=non %then %do;
		/* Bornes = celles trouv�es en t�tonnant sur l'ERFS �largie */
		%let borne_inf_cal0=&borne_inf_cal0_ela.;
		%let borne_sup_cal0=&borne_sup_cal0_ela.;
		%let borne_inf_cal1=&borne_inf_cal1_ela.;
		%let borne_sup_cal1=&borne_sup_cal1_ela.;
		%let borne_inf_cal2=&borne_inf_cal2_ela.;
		%let borne_sup_cal2=&borne_sup_cal2_ela.;
		%end;
	%put LES BORNES DE CALAGE SONT : &borne_inf_cal0. &borne_sup_cal0. &borne_inf_cal1. &borne_sup_cal1. &borne_inf_cal2. &borne_sup_cal2.;
	%Mend DefinitBornesCalage;
%DefinitBornesCalage;


*******************************************;
* II.a calage sur marge sur le T4 de l'EE *;
*******************************************;
%calage(FILENAME="&dossier./Marges_Calage.xls",
		ANNEE=&anref.,
		Lo=&borne_inf_cal0.,
		UP=&borne_sup_cal0.,
		POIDS=wprm,         /* sera remplac� par wpela si l'on travaille sur l'�largie (cf. ligne 227) */
		POIDSFIN=wpela&anr.);

*****************************************;
* II.b Calage sur marge sur le T4 anr1. *;
*****************************************;
%calage(FILENAME="&dossier./Marges_Calage.xls",
		ANNEE=&anref.+1,
		Lo=&borne_inf_cal1.,
		UP=&borne_sup_cal1.,
		POIDS=poiinit,
		POIDSFIN=wpela&anr1.);

****************************************;
* II.c Calage sur marge sur le T4 anr2. *;
****************************************;
%calage(FILENAME="&dossier./Marges_Calage.xls",
		ANNEE=&anref.+2,
		Lo=&borne_inf_cal2.,
		UP=&borne_sup_cal2.,
		POIDS=poiinit,
		POIDSFIN=wpela&anr2.);

/* On rassemble les poids dans la table travail.menage&anr.*/
data travail.menage&anr.;
	merge 	travail.menage&anr.
			var_calage(in=a keep=ident wp:);
	by ident;
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

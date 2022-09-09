/*****************************************************/
/*			programme eligibilité_CMUc_ACS			 */
/*****************************************************/

/****************************************************************************************************************/
/* Ce programme estime l'éligibilité à la CMUc ou à l'ACS en fonction des ressources des foyers CMUC.			*/
/* 																												*/
/* Tables en entrée : 	modele.baseind																			*/
/*						modele.cotis																			*/
/*						base.baserev																			*/
/*						base.foyer&anr2.																		*/
/*						base.menage&anr2.																		*/
/*						modele.baselog																			*/
/*						imput.accedant																			*/
/*						modele.basersa																			*/
/*						modele.basefam																			*/
/*						modele.rsa																				*/
/* Tables en sortie :	modele.baseind																			*/
/*																												*/
/* Plan																											*/
/* I  - définition du contour des foyers CMU																	*/
/* II -	calcul de la base ressource																				*/
/* 	II-a revenus individualisables de la déclaration															*/
/*	II-b revenus non individualisables de la déclaration														*/
/*	II-c revenus financiers imputés																				*/
/*	II-d intégration du forfait logement																		*/
/*	II-e autres prestations à ajouter dans la base ressource													*/
/*	II-f réunion de l'ensemble des ressources																	*/
/*	II-g ajout du RSA																							*/
/*III - calcul de l'éligibilité à la CMUc ou à l'ACS															*/
/****************************************************************************************************************/



/********************************************/
/* I - définition du contour des foyers CMU */
/********************************************/

/* Le contour du foyer CMU est le même que le foyer RSA à la différence que les enfants de moins de 25 ans ne peuvent
   pas faire d'optimisation. Ils n'ont pas le choix de déclarer ou non avec leurs parents. 
   S'ils ont un enfant ils peuvent faire une demander autonome. En revanche s'ils n'ont pas d'enfant et qu'ils habitent
   chez leurs parents ou qu'ils sont sur leur déclaration fiscale ou qu'ils perçoivent une pension alimentaire déclarée
   par leurs parents, ils doivent faire une demande avec leur parents. */
 
/* Pour construire les foyers CMU, on part donc du foyer RSA auquel on rattache les pac de moins de 25 ans qui font
   une demande de RSA autonome et qui ne peuvent pas le faire pour la CMU 
   Concrétement, si dans un ménage on a une personne de moins de 25 ans, sans enfants, qui vit avec ses parents et 
   qui fait une demande autonome de RSA, on la rattache avec le foyer CMU de ses parents.*/


proc sql;
	create table pac as
		select ident_rsa, sum(statut_rsa='pac') as nbpac from modele.baseind
		group by ident_rsa;
	create table baseind as
		select a.*, nbpac from modele.baseind(where=(enf_1^=1)) as a left join pac as b
		on a.ident_rsa=b.ident_rsa;
	quit;

data baseind;
	set baseind;
	ident_cmu=ident_rsa;
	statut_cmu=statut_rsa;
	age=int((12*&anref.-12*naia-naim+1)/12) + mod(12*&anref-12*naia-naim+1,12)/12;
	if nbpac=0 and age<&age_rsa_l. and (noiper^='' or noimer^='') and substr(ident_rsa,8,2) ne '01' then do;
		ident_cmu=substr(ident_rsa,1,8)!!'01';
		statut_cmu='pac';
		end;
	run;

data es; set baseind; if enf_1=1; run;

/*************************************/
/* II - calcul de la base ressources */
/*************************************/

/* Il s'agit pour chaque foyer CMU de réunir l'ensemble des ressources utilisée pour estimer l'éligibilité
   au dispositif */

		/***************************************************/	
		/* II-a revenus individualisables de la déclaration*/
     	/***************************************************/

/* On retire des revenus d'activités et de remplacement la CSG imposable puisque la base ressource est constituée
   des revenus perçus */

proc sort data=modele.cotis; by ident noi; run;
proc sort data=base.baserev; by ident noi; run;
proc sort data=baseind; by ident noi; run;
data revind ;
	merge base.baserev (keep=ident noi zsali&anr2. zchoi&anr2. zrsti&anr2. zpii&anr2. zalri&anr2. zrtoi&anr2.
						 zragi&anr2. zrici&anr2. zrnci&anr2.)
	  	  baseind(keep=ident noi ident_cmu acteu6 asi)
	  	  modele.cotis (keep=ident noi csgi crdsi csgtsi crdsts csgbni crdsbn csgbii crdsbi csgbai crdsba);
	by ident noi;

	
	revind_net=max(0,sum(zsali&anr2.,max(0,zragi&anr2.),max(0,zrici&anr2.),max(0,zrnci&anr2.),zchoi&anr2.,zrsti&anr2.,
					 zpii&anr2.,zalri&anr2.,zrtoi&anr2.,-csgi,-crdsi));

	zsali=max(0,sum(zsali&anr2.,-csgtsi,-crdsts));
	zragi=max(0,sum(zragi&anr2.,-csgbai,-crdsba));
	zrici=max(0,sum(zrici&anr2.,-csgbii,-crdsbi));
	zrnci=max(0,sum(zrnci&anr2.,-csgbni,-crdsbn));

/* Il existe plusieurs situations dans laquelle un abattement sur les revenus d'activité peut être appliqué.
   La législation indique:
   Un abattement de 30 % est appliqué sur les revenus d'activité perçus par toute personne membre du foyer
   durant les 12 mois précédant la demande de CMU-C si elle se trouve dans une des situations suivantes : 

   a) interruption de travail de plus de 6 mois pour longue maladie, => ne peut pas être pris en compte.
   b) sans emploi et percevant une rémunération de stage de formation professionnelle réglementaire,
	  légale ou conventionnelle => non pris en compte ici.
   c) chômage, total ou partiel, et recevant une allocation d'assurance chômage
   d) perception de l'allocation d'insertion ou de solidarité spécifique */
	if (acteu6 in ('3','4') & zchoi&anr2.>0) | asi>0 then 
		revind_net=max(0,sum(revind_net,-zsali&anr2.,-max(0,zragi&anr2.),-max(0,zrici&anr2.),-max(0,zrnci&anr2.),
				   	   0.7*zsali,0.7*zragi,0.7*zrici,0.7*zrnci));
	run;


/* on fait la somme des revenus individualisables par ident_cmu */
%Cumul(	basein=revind,
		baseout=revind_cmu,
		varin=revind_net zsali zragi zrici zrnci zchoi&anr2. zrsti&anr2. zpii&anr2.,
		varout=revind_net zsali zragi zrici zrnci zchoi zrsti zpii,
		varAgregation=ident_cmu);


		/********************************************************/
		/* II-b revenus non individualisables de la déclaration */
		/********************************************************/

/* les revenus primaires non individualisables sont dans la table foyer&anr2. */
/* Par hypothèse, je les ajoute au foyer CMU du déclarant */

proc sql;
	create table lien1 as
		select distinct ident, noi, ident_cmu, statut_cmu from baseind;
	create table foyer&anr2. as
		select 	zracf, zetrf, zfonf, zvamf, zvalf, zalvf, _2fu, _2ch, _2dh, zdivf, zglof, zquof, b.*, 
				max(0,sum(0,max(0,zracf),zetrf,max(0,zfonf),zvamf,zvalf,-zalvf,_2ch,_2fu,_2dh)) as revnind
		from base.foyer&anr2. as a left join lien1 as b
		on a.ident=b.ident and a.noi=b.noi;
	quit;

%Cumul(	basein=foyer&anr2.,
		baseout=revnind_cmu,
		varin=revnind,
		varout=revnind,
		varAgregation=ident_cmu);

		/************************************/
		/* II-c revenus financiers imputés */
		/************************************/

/* ils sont dans la table ménage, je les attribue à la personne de référence du ménage et donc à son foyer CMU */
proc sql;
	create table prodfin as
		select ident_cmu, produitfin_i*(lprm='1') as prodfin from
		baseind as a left join base.menage&anr2. as b
		on a.ident=b.ident;
	quit;

%Cumul(	basein=prodfin,
		baseout=prodfin_cmu,
		varin=prodfin,
		varout=prodfin_cmu,
		varAgregation=ident_cmu);


		/******************************************/
		/* II-d - intégration du forfait logement */
		/******************************************/

/* Les allocations logement ne sont pas directement intégrées dans le revenu_cmu mais elles le sont via l'application
d'un forfait logement. Il existe également un forfait logement lorsqu'au moins une des personnes du foyer_cmu est
logée à titre gratuit ou est propriétaire de son logement*/

/* ce forfait logement dépend du nombre de personnes dans le foyer. Le barème est identique au forfait logement intégré
dans la base ressource du RSA pour les personnes bénéficiant d'une aide au logement. Il est un peu moins élevé pour
les personnes hébergées à titre gratuit */

/* Le forfait logement ne peut dépasser le montant d'AL perçu donc pour les logements qui contiennent plusieurs 
foyer CMU, je proratise le montant d'AL par le nombre de personnes dans chaque foyer CMU */


/* 1ère étape : les allocations pour les locataires */

/*On a besoin du nombre personne dans chaque foyer_cmu*/
proc sql;
	create table nbp as
		select distinct (ident_cmu), count(distinct noi) as nbp_cmu
		from baseind
		group by ident_cmu;
	/* On repère les ident_log qui ont plusieurs identifiants cmu et on compte le nombre de personnes total dans le logement */
	create table NbCMU__ as
		select distinct(ident_log), ident_cmu, count(distinct ident_cmu) as nbcmu, count(distinct noi) as nbp_log
		from baseind
		where ident_cmu ne '' and ident_log ne ''
		group by ident_log;
	create table NbCMU_ as
		select nbp_cmu, b.* from NbP as a left join NbCMU__ as b
		on a.ident_cmu=b.ident_cmu;
	/* on y ajoute les AL */
	create table NbCMU as
		select a.*, b.AL as ALcmu
		from NbCMU_ as a left join modele.baselog as b
		on a.ident_log=b.ident_log;
	update NbCMU
		set ALcmu=ALcmu*nbp_cmu/nbp_log
		where NbCMU>1;
	drop table NbCMU_, NbCMU__;
	quit;

%Cumul(	basein=nbcmu,
		baseout=ALcmu,
		varin=ALcmu,
		varout=ALcmu,
		varAgregation=ident_cmu);


/* 2ème étape pour les AL accédant qui sont dans la table ménage. Cependant on a jamais plusieurs ménages dans 
un foyer CMU par construction donc on a pas à proratiser */
proc sql;
	create table ALacc as
	select ident_cmu, b.* from
	baseind as a left join imput.accedant as b
	on a.ident=b.ident;
	quit;

%Cumul(	basein=ALacc,
		baseout=ALacc_cmu,
		varin=alaccedant,
		varout=ALacc_cmu,
		varAgregation=ident_cmu);

/* Pour terminer on réunit les différentes AL, on récupère le statut d'occupation du logement (dans basersa) et
on calcule le forfait logement qu'on intégrera dans la base ressources */
proc sql;
	create table statut_occup_ as
		select distinct ident, logt
		from base.menage&anr2.;
	create table lien2 as
		select distinct ident, ident_cmu
		from baseind;
	create table statut_occup as
		select a.*, ident_cmu from statut_occup_ as a left join lien2 as b on a.ident=b.ident;
	drop table statut_occup_;
	quit;


proc sort data=statut_occup; by ident_cmu; run;
data forf_log (keep=ident_cmu forf_log);
	merge ALcmu (where=(ident_cmu^='')) ALacc_cmu (where=(ident_cmu^='')) 
	  	  statut_occup (where=(ident_cmu^='')) nbp (where=(ident_cmu^='') in=a);
	by ident_cmu;
	if a;

	if ALcmu>0 | ALacc_cmu>0 then forf_log= min(sum(ALcmu,ALacc_cmu),(&forf_log1.*&rsa.*(nbp_cmu=1)
								    	  + &forf_log2.*(1+&rsa2.)*&rsa.*(nbp_cmu=2)
								 		  + &forf_log3.*(1+&rsa2.+&rsa3.)*&rsa.*(nbp_cmu>2))*12);

	else if logt in ('2','6') then forf_log= (&forf_log1.*&rsa.*(nbp_cmu=1)
								 	 	 + &forf_log4.*(1+&rsa2.)*&rsa.*(nbp_cmu=2)
									 	 + &forf_log4.*(1+&rsa2.+&rsa3.)*&rsa.*(nbp_cmu>2))*12;
	else forf_log=0;
 	run;

		/************************************************************/
		/*II-e autres prestations à ajouter dans la base ressources */
		/************************************************************/

/* Peu de prestations ne sont pas comptabilisées dans la BR, parmi celles que l'on calcule, il s'agit
principalement de l'AEEH et du RSA */

/*on commence par les prestations de basefam*/
proc sort data=baseind(keep= ident_fam ident_cmu) out=lien4 nodupkey; by ident_fam; run; 
proc sort data=modele.basefam; by ident_fam; run;
data basefam;
	merge modele.basefam (in=a) lien4;
	by ident_fam;
	if a;
	run;

%Cumul(	basein=basefam,
		baseout=prest_fam,
		varin=afxx0 majafxx alocforxx comxx clca asf nbciv,
		varout=af0 majaf alocfor com clca asf nbciv,
		varAgregation=ident_cmu);

/*on poursuit avec les prestations individualisées */
%Cumul(	basein=baseind,
		baseout=prest_ind,
		varin=aah caah asi aspa,
		varout=aah caah asi aspa,
		varAgregation=ident_cmu);


		/********************************************/
		/*II-f réunion de l'ensemble des ressources */
		/********************************************/

data rev_cmu_;
	merge nbp (in=a) revind_cmu revnind_cmu prodfin_cmu forf_log prest_fam prest_ind;
	by ident_cmu;
	if a;
	where ident_cmu ^='';
	rev_cmu=sum(0,revind_net,revnind,prodfin_cmu,forf_log,af0,majaf,alocfor,com,clca,asf,aah,caah,asi,aspa);
	run;

		/*******************/
		/*II-g ajout du RSA*/
		/*******************/

/*Le RSA ne fait pas partie de la base ressource de la CMUc et de l'ACS mais le bénéfice du RSA socle entraine
l'éligibilité à la CMUc, c'est pour cette raison qu'on l'ajoute à la table rev_cmu
On ajoute égale le RSA activité pour les besoins des données de cadrage*/

/* Du fait du changement RSA socle/RSA activité en RSA/Prime d'activité, il faut prendre en compte les nouvelles variables de rsa 
	Avant 2016 le rsa socle était recensé dans rsasocle, depuis 2016 il l'est dans rsa */
proc sql;
	create table rsa as
		select distinct b.ident_rsa, ident_cmu, a.* from
		modele.rsa as a left join baseind as b on
		a.ident_rsa=b.ident_rsa;
	quit;
%Cumul(	basein=rsa,
		baseout=rsa_cmu,
		varin=rsasocle rsaact rsa,
		varout=rsas rsarec rsa_16,
		varAgregation=ident_cmu);

proc sql;
	create table rev_cmu as
		select a.*, rsas, rsarec, rsa_16 from
		rev_cmu_ as a left join rsa_cmu as b on
		a.ident_cmu=b.ident_cmu;
	drop table rev_cmu_;
	quit;

/* Pour que le code marche quelque soit l'année législative étudiée on somme rsas et rsa_16 sous le nom rsa que l'on utilise ensuite pour déterminer
	l'éligibilité à la CMU-C */
data rev_cmu;
	set rev_cmu;
	indic_rsa = 0;
	indic_rsa = rsas+rsa_16;
	run;

/**************************************************/
/*III Calcul de l'éligibilité à la CMUc ou à l'ACS*/
/**************************************************/

/* on ne donne pas l'éligibilité aux ménages dont la PR est étudiante */
data etud_pr (keep=ident_cmu etud_pr_cmu);
	set baseind (where=(lprm in ('1')) keep=ident_cmu acteu6 lprm);
	if acteu6 & acteu6='5' then etud_pr_cmu='oui';
	else etud_pr_cmu='non';
	run;

proc sort data=etud_pr; by ident_cmu;
proc sort data=rev_cmu; by ident_cmu; run;

data elig_cmu;
	merge rev_cmu (in=a) etud_pr;
	by ident_cmu;
	if a;

	plafond_cmuc=&cmuc.*(1+&cmuc2.*(nbp_cmu>1)+&cmuc3.*(nbp_cmu>2)+&cmuc3.*(nbp_cmu>3)+&cmuc4.*max(0,nbp_cmu-4));

	elig_cmuc=0;
	elig_acs=0;
	if rev_cmu<plafond_cmuc | indic_rsa>0 then elig_cmuc=1;
	else if rev_cmu<plafond_cmuc*(1+&acs.) then elig_acs=1;

	if etud_pr_cmu='oui' | substr(ident_cmu,9,2)='99' then do; /* On enlève les PR étudiants et les - 18 ans dont on n'a pas retrouvé les parents */
		elig_cmuc=0;
		elig_acs=0;
		end;
	run;

proc sort data=modele.baseind; by ident noi; run;
proc sort data=lien1; by ident noi; run;

data modele.baseind; 
	merge modele.baseind (in=a) lien1;
	by ident noi;
	if a;
	run;
proc sort data=modele.baseind; by ident_cmu; run;

/* on impute l'éligibilité */
%macro elig_cmuc_acs;
%varexist(lib=modele,table=baseind,var=elig_cmuc);
data modele.baseind;
	%if &varexist. %then %do;
	merge modele.baseind (in=a drop=elig_cmuc elig_acs nbp_cmu) elig_cmu (keep=ident_cmu elig_cmuc elig_acs nbp_cmu);
	%end;
	%else %do;
	merge modele.baseind (in=a) elig_cmu (keep=ident_cmu elig_cmuc elig_acs nbp_cmu);
	%end;
	by ident_cmu;
	if a;
	run;
%mend;
%elig_cmuc_acs;


proc datasets mt=data library=work kill;run;quit;


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

*************************************************************************************;
/*																										                                         */
/*					Création de la table de tirage des bénéficiaires de l'ASS											*/
/*																										                                        */
*************************************************************************************;


/* En entrée :         
/*                          rpm.icomprf&anr.e&anr.t1					*/
/*                          rpm.icomprf&anr.e&anr.t2					*/
/*                          rpm.icomprf&anr.e&anr.t3					*/
/*                          travail.irf&anr.e&anr.					*/
/* 				          base.baserev								*/
/* 				          base.baseind								*/

/* En sortie : 	      ass_anr&anref._anleg&anleg..csv */

/* Ce programme prépare la table sur laquelle va tourner l'algortihme de prédiction de la probabilité d'être
à l'ASS : c'est la table SAS imput_ass exportée sur csv avec les variables prédictives au sein des individus
susceptibles de toucher de l'ASS à un moment de l'année (repérés avec chômage déclaré et calendrier d'activité) */

/* Pour l'observé, on récupère les bénéficiaires de l'ASS selon la variable ALCT des 4 trimestres de l'EE dans l'année &anref. 
Cela nous permet de récupérer des répondants aux trois premiers trimestres non répondants au quatrième et de pas entraîner
notre modèle de prédiction sur la seule population des bénéficiaires en fin d'année (risque de biais) */

%macro table_tirage_ass;
%if &module_ASS.=oui %then %do;

	proc sql;
		create table ass_annuel as
		select a.alct as alct1, b.alct as alct2, c.alct as alct3, d.alct as alct4, d.ident, d.noi,
		((a.alct="2")+(b.alct="2")+(c.alct="2")+(d.alct="2")) as ass_unefois
		from ((rpm.icomprf&anr.e&anr.t1 as a right join rpm.icomprf&anr.e&anr.t2 as b
		on a.ident&anr.=b.ident&anr. and a.noi=b.noi) right join rpm.icomprf&anr.e&anr.t3 as c
		on b.ident&anr.=c.ident&anr. and b.noi=c.noi) right join travail.irf&anr.e&anr. as d
		on c.ident&anr.=d.ident and c.noi=d.noi;
		quit;

	/* On regroupe les informations dans la table imput_ass. On considère ici pour construire l'observé que
	les bénéficiaires de l'ASS sont ceux ayant déclaré avoir touché l'ASS dans un des 4 trimestres de l'enquête
	et que les "vrais" non-bénéficiaires de l'ASS sont ceux déclarant toucher une autre allocation chômage au T4 :
	il semble en effet peu probable de basculer de l'ASS à une allocation chômage au cours de la même année */
	proc sql;
		create table imput_ass as
		select a.ident, a.noi, c.wpela&anr2., (a.zchoi&anr2./c.nbmois_cho) as chom_mens, c.cal0,
		c.noicon ne '' or (substr(c.declar1,13,1) in ('M','O') and substr(c.declar1,19,4) not in ('9999','9998'))  as couple, 
		input(b.ag,3.) as age, input(b.ag,3.)*input(b.ag,3.) as age2, &anref.+1-case when adfdap='' then &anref.+1 else input(adfdap,4.) end as duree_ss_emploi,
		case when ddipl='7' then 1 else 0 end as pas_diplome, c.nbmois_cho, c.nbmois_sal, 
		case when ass_unefois>0 then 1 when alct in ('1','3','4','5') then 0 else . end as ass, 
		case when b.sexe='1' then 1 else 0 end as sexe, case when input(b.ag,3.)<30 & input(b.ag,3.)>=25 then 1 else 0 end as moins_30,
		case when input(b.ag,3.)<50 & input(b.ag,3.)>=30 then 1 else 0 end as entre_30_50,
		case when input(b.ag,3.)<66 & input(b.ag,3.)>=50 then 1 else 0 end as entre_50_65,
		ag, "&imputation.\imputation ASS" as chemin_ass, max(0,input(dchantm,3.),input(dremcm,2.)) as nbmoischo_ant 
		/* nbmoischo_ant=nb de mois de recherche d'emploi ou nb de mois de recherche d'emploi avant l'emploi actuel pour les salariés au T4 */
		from ((base.baserev as a left join travail.irf&anr.e&anr. as b on a.ident=b.ident and a.noi=b.noi)
		left join base.baseind as c
		on a.ident=c.ident and a.noi=c.noi) left join ass_annuel as d
		on a.ident=d.ident and a.noi=d.noi
		where zchoi&anr2. ne 0 and find(substr(cal0,1,12),"4") ne 0 and input(ag,3.)>=25 and input(ag,3.)<=65;
		quit;

	proc export data=imput_ass dbms=csv outfile="&imputation.\imputation ASS\ass_anr&anref._anleg&anleg..csv"  replace;
 		delimiter=";";
		run;
	%end ;
%mend ;

%table_tirage_ass;

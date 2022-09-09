/********************************************************************************************/
/*                   			5b_XYZ_foyer                         						*/
/********************************************************************************************/

/********************************************************************************************/
/* Table en entrée :																		*/
/*  travail.foyer&anr.																		*/
/*  travail.indivi&anr.																		*/
/*  travail.indfip&anr.																		*/
/*  dossier.FoyerVarList																	*/
/*  																						*/
/* Table en sortie : 																		*/
/*  travail.foyer&anr.																		*/
/*  travail.indivi&anr.																		*/
/*  travail.indfip&anr.																		*/
/*																							*/
/* 	Objectif : pour la période où il y avait une triple déclaration à faire pour les 		*/
/*  couples mariés dans l'année, on cherche à recréer une déclaration pour les couples 		*/
/*	dont on a retrouvé que 2 des trois déclarations de l'année.								*/
/*  Cela ne fonctionne que lorsque c'est la déclaration du conjoint qui manque (la majorité */
/* 	des cas)																				*/
/*  A partir de 2012 : suppression de la triple déclaration donc ce programme n'a plus lieu */
/*  d'être.																					*/
/*																							*/
/*  LIMITES du programme et précisions:														*/
/*  En toute rigueur, il faudrait reprendre ce programme (et les suivant a priori) en se 	*/
/*	servant de declar et jamais de ident, cela dit, on peut supposer qu'il n'y a qu'un 		*/
/*	évenement par ménage.																	*/
/*  Ne fonctionne que pour les conjoints manquants mais ils représentent la très grande 	*/
/*	majorité des cas. On pourrait toutefois adapter facilement aux déclarants.				*/ 
/*  Pour les revenus communs, on calcule au pro-rata le montant que l'on devrait obtenir 	*/
/*	et on impute la partie qu'on n'a pas retrouvée dans l'autre déclaration.                */ 
/*  On ne fait pas l'effort (pourtant peu couteux, d'ajouter les cases préremplies qui ne 	*/
/*	servent pas dans le calcul d'Ines).			    */
/*  Il faut réfléchir au cas des divorcés, le programme peut peut-être s'adapter facilement	*/
/*	en faisant attention que la durée est désormais celle après-mariage.					*/
/********************************************************************************************/


%macro CorrigeDeclarManq_evtX(anleg);
 	%if &anleg.<2012 %then %do;

	%local 	listVousSomme listVousCocher listConjSomme listConjCocher VarPac1 Pac1Cocher VarPac2 Pac2Cocher VarPac3 VarPac4 
			listvar listCocher VousSommeExpli VousCocherExpli ConjSommeExpli ConjCocherExpli VarPac1Expli Pac1CocherExpli 
			VarPac2Expli Pac2CocherExpli listvarExpli listCocherExpli VarPac6ans EtudesEnf varAns;
	proc sql noprint;
		select name into :listVousSomme separated by ' ' from dossier.FoyerVarList where TypeContenu="Montant concernant le déclarant (vous)";
		select name into :listVousCocher separated by ' ' from dossier.FoyerVarList where TypeContenu="Autre case concernant le déclarant (vous)";
		select name into :listConjSomme separated by ' ' from dossier.FoyerVarList where TypeContenu="Montant concernant le conjoint (conj)";
		select name into :listConjCocher separated by ' ' from dossier.FoyerVarList where TypeContenu="Autre case concernant le conjoint (conj)";
		select name into :VarPac1 separated by ' ' from dossier.FoyerVarList where TypeContenu="Montant concernant pac1";
		select name into :Pac1Cocher separated by ' ' from dossier.FoyerVarList where TypeContenu="Autre case concernant pac1";
		select name into :VarPac2 separated by ' ' from dossier.FoyerVarList where TypeContenu="Montant concernant pac2";
		select name into :Pac2Cocher separated by ' ' from dossier.FoyerVarList where TypeContenu="Autre case concernant pac2";
		select name into :VarPac3 separated by ' ' from dossier.FoyerVarList where TypeContenu="Montant concernant pac3";
		select name into :VarPac4 separated by ' ' from dossier.FoyerVarList where TypeContenu="Montant concernant pac4";
		select name into :listvar separated by ' ' from dossier.FoyerVarList where TypeContenu="Montant concernant le foyer";
		select name into :listCocher separated by ' ' from dossier.FoyerVarList where TypeContenu="Autre case concernant le foyer";
		quit;
	/* Listes complémentaires avec variables au nom explicite : à ajouter ici quand une case fiscale disparait et est changée de liste dans le programme macros_OrgaCase.sas */ 
	%let VousSommeExpli =_glovsup4ansvous _demenage_emploivous _hsupvous _impot_etr_dec1 _rachatretraite_vous ; 
	%let VousCocherExpli =_nbheur_ppe_dec1 _pro_act_jour_dec1 _tpsplein_ppe_dec1 _pro_act_annee_dec1 ;
	%let ConjSommeExpli =_glovsup4ansconj _demenage_emploiconj _hsupconj _impot_etr_dec2 _rachatretraite_conj;
	%let ConjCocherExpli =_nbheur_ppe_dec2 _pro_act_jour_dec2 _tpsplein_ppe_dec2 _pro_act_annee_dec2 ;
	%let VarPac1Expli =_demenage_emploipac1 _hsuppac1 _impot_etr_pac1 _rsa_compact_ppe_pac1; 
	%let Pac1CocherExpli =_nbheur_ppe_pac1 _pro_act_jour_pac _tpsplein_ppe_pac1 _pro_act_annee_pac ;
	%let VarPac2Expli =_demenage_emploipac2 _hsuppac2 _impot_etr_pac2 _rsa_compact_ppe_pac2; 
	%let Pac2CocherExpli =_nbheur_ppe_pac2 _tpsplein_ppe_pac2 ;
 	%let listvarExpli =_interet_pret_conso _credformation _relocalisation _perte_capital _perte_capital_passe _cirechant _cinouvtechn
					   _epargnecodev _revpea _ciformationsalaries _invdomaut1 _invdomaut2 _pvcessiondom _dep_devldura_loc1 _dep_devldura_loc2 
					   _dep_devldura_loc3 _dep_devldura_loc4 _souscsofipeche _revimpcrds _depinvloctour_2011_1 _depinvloctour_2011_2 
					   _depinvloctour_ap2011_1 _depinvloctour_ap2011_2 _depinvloctour_av2011_1 _depinvloctour_av2011_2 _dep_asc_traction 
					   _ci_debitant_tabac _pvcession_entrepreneur _glo_txfaible _glo_txmoyen _1annui_lgtneuf _1annui_lgtancien 
					   _protect_patnat _1annui_lgtneufnonbbc _abatt_moinsval _abatt_moinsval_renfor _abatt_moinsval_dirpme _rsa_compact_ppe_f 
					   _deduc_invest_loc2009 _cred_loc;
	%let listCocherExpli =_nb_vehicpropre_simple _nb_vehicpropre_destr _nb_convention _nb_convention_hand _bouquet_travaux _maison_indivi
						  _pro_act_annee_pac _report_ri_dom_entr;
	/* Listes de cases qui ne sont plus répertoriées dans TypeContenu mais dont on se sert dans ce programme */
	%let VarPac6ans =_7ga _7gb _7gc _7ge _7gf _7gg; /* variables aussi incluses dans listvar */
	%let EtudesEnf =_7ea _7ec _7ef _7eb _7ed _7eg; /* variables aussi incluses dans listCocher */
	%let varAns =_2aa _2al _2am _2an _2aq _2ar _4tq _5qf _5qg _5qn _5qo _5qp _5qq _5rn _5ro _5rp _5rq _5rr _5rw _5ht _5it _5jt _5kt _5lt _5mt
				 _6fa _6fb _6fc _6fd _6fe _6fl _7xs _7xt _7xu _7xw _7xy; /* variables aussi incluses dans listvar */

		/* On sélectionne les foyers fiscaux qui ont un mariage dans l'année */
		data mariage; 
			set travail.foyer&anr. (where=(index(sif,'X')>0 ));
			impute=(nbenf='');
			run;

		/* On selectionne dans mariage les foyers qui sont pacsés ou mariés 
		   Les déclarations dans a_separer correspondent aux déclarations jointes. 
		   C'est à partir de ces déclarations que l'on va recréer la déclaration du conjoint manquant. */
		data a_separer; set mariage(where=(substr(sif,5,1) in ('O','M') ));run; 

		proc sort data=mariage; by ident; run;
		proc sort data=a_separer; by ident; run;

		/* On veut avoir la liste des ident qui apparaissent exactement 2 fois dans la table mariage
		   - i.e. il manquent 1 déclaration */
		proc sql noprint;
			create table mariage_1dec_manq as
			select distinct ident
			from mariage
			group by ident having count(*)=2
			order by ident;
			quit;

		/* On ne conserve dans mariage_1dec_manq que les ménages de la table mariage pour lesquels il manque 
		une déclaration */
		data mariage_1dec_manq;
			merge mariage mariage_1dec_manq(in=a);
			by ident;
			if a;
			run;

		/* Idem pour a_separer_2 */
		data a_separer_2; set mariage_1dec_manq(where=(substr(sif,5,1) in ('O','M')));run; 

		/* Dans avantmariage_2 on met les foyers fiscaux de mariage_1dec_manq qui sont célibataire divorcé 
		ou veuf. */
		data avantmariage_2; set mariage_1dec_manq(where=(substr(sif,5,1) in ('C','D','V')));run; 
		data avantmariage_2;
			merge avantmariage_2 a_separer_2 (keep=ident in=a);
			by ident;
			if a;
			run;

		/* On crée les tables pour les déclarants et pour les conjoints (qui ne sont pas absents)
		   On veut simuler les tables manquantes */
		proc sort data=a_separer_2; by ident; run;
		proc sort data=avantmariage_2; by ident; run;
		/* On merge a_separer_2 et avantmariage_2. Si ident noi est présent dans a_separer_2 
		et qu'elle a un identifiant de déclaration, on met l'observation dans declarants_2, 
		sinon dans conjoints_2 */ 
		data declarants_2 (where=(declar ne ''))  conjoints_2;
			merge avantmariage_2 a_separer_2(in=a keep=ident noi);
			by ident noi;
			if a then output declarants_2;
			else output conjoints_2;
			run;

		/******************************************/
		/* Simulation des déclarations manquantes */
		/******************************************/

		/***********************************************************************/
		/* 1ère étape, on créée la variable anaisenf de la déclaration absente */
		/***********************************************************************/

		/* 1.a) Enfants de conjoint simulés */

		/* On merge les infos de la déclaration jointe et de la déclaration du déclarant retrouvée */
		data simul_conj;
			merge 	a_separer_2 (keep=ident anaisenf sif declar moisev) 
					declarants_2 (keep= ident anaisenf sif declar rename=(anaisenf=anaisenf_d sif=sif_d declar=declar_d) in=a) ;
			by ident;
			if a;
			run; 

		/* On créée la variable anaisenf_c qui est la variable anaisenf de la future déclaration 
		du conjoint en comparant les variables anaisenf de la déclaration jointe et de la déclaration 
		du déclarant. On définit les enfants-"bonus" (i.e. les enfants de conjoints) et les enfants 
		disparus ("old") */
		data simul_conj;
			set simul_conj;
			length  enfant $5 old $20;
			/* au départ anaisenf_c est égal à anaisenf de la déclaration jointe */
			anaisenf_c=anaisenf;
			old='';
			if length(anaisenf_d)>1 then do;
				do j=1 to (length(anaisenf_d)-4) by 5;
						enfant=substr(anaisenf_d,j,5);
						if index(anaisenf_c,enfant)^=0 then do; 
						/* ie si un enfant de la déclaration jointe est sur la déclaration du déclarant 
						   on le retire de anaisenf_c */
							i=index(anaisenf_c,enfant);
							p=length(anaisenf_c);
							if p>5 then do;
								if i=1 then anaisenf_c=substr(anaisenf_c,5+1,p-5);
								else if i=p-5+1 then anaisenf_c=substr(anaisenf_c,1,i-1);
								else do;
									anaisenf_c=substr(anaisenf_c,1,i-1)!!substr(anaisenf_c,i+5,p-i-5+1);
									end;
								end;
							else anaisenf_c=''; 
							end;
						/* si l'enfant n'est pas présent dans la déclaration du déclarant, on créée 
						une variable old qui est une concaténation des enfants non retrouvés.
						La fonction Cats permet de concaténer du texte en supprimant les blancs 
						aux extrémités */
						else do; old=cats(enfant,old); end;
					end;
				end;
			
			drop i j p enfant old;
			run;

		/* 1.b) Enfants de declarant simulés */
		/* On fait la même chose qu'au dessus dans le cas ou c'est la déclaration du déclarant 
		qui n'est pas retrouvée */

		data simul_decl;
			merge 	a_separer_2 (keep=ident anaisenf sif declar) 
					conjoints_2 (keep= ident anaisenf sif declar rename=(anaisenf=anaisenf_c sif=sif_c declar=declar_c) in=a) ;
			by ident;
			if a;
			run; 

		/* On définit les enfants-"bonus" (i.e. les enfants de déclarants) et les enfants 
		disparus ("old") */
		data simul_decl;
			set simul_decl;
			length  enfant $5 old $20;
			anaisenf_d=anaisenf;
			old='';
			if length(anaisenf_d)>1 then do;
				do j=1 to (length(anaisenf_d)-4) by 5;
						enfant=substr(anaisenf_d,j,5);
						if index(anaisenf_d,enfant)^=0 then do; 
							i=index(anaisenf_d,enfant);
							p=length(anaisenf_d);
							if p>5 then do;
								if i=1 then anaisenf_d=substr(anaisenf_d,5+1,p-5);
								else if i=p-5+1 then anaisenf_d=substr(anaisenf_d,1,i-1);
								else do;
									anaisenf_d=substr(anaisenf_d,1,i-1)!!substr(anaisenf_d,i+5,p-i-5+1);
									end;
								end;
							else anaisenf_d=''; 
							end;
						else do; old=cats(enfant,old); end;
					end;
				end;
			
			drop i j p enfant old;
			run;

		/*********************************************/
		/* 2ème étape : création de la variable SIF  */
		/*********************************************/

		data simul_conj;
			set simul_conj;
			length  f g r j n h $1;
			/* Changer les personnes à charge */
			f=put(COUNTC(anaisenf_c,'F'),1.);
			g=put(COUNTC(anaisenf_c,'G'),1.);
			r=put(COUNTC(anaisenf_c,'R'),1.);
			j=put(COUNTC(anaisenf_c,'J'),1.);
			n=put(COUNTC(anaisenf_c,'N'),1.);
			h=put(COUNTC(anaisenf_c,'H'),1.);
			sif_c=substr(sif,1,5)!!substr(sif,11,4)!!' 9999'!!substr(sif,15,51)!!'0'!!f!!'G'!!'0'!!g!!'R'!!'0'!!r!!'J'!!'0'!!j!!'N'!!'0'!!n!!'H'!!'0'!!h!!substr(sif,83,length(sif)-83+1);
			/* Changer M,O -> C dans sif*/
			sif_c=substr(sif_c,1,4)!!'C'!!substr(sif_c,6,length(sif_c)-6+1);
			/*Supprimer S*/
			if  substr(sif_c,22,1)='S' then 
				sif_c=substr(sif_c,1,21)!!'0'!!substr(sif_c,23,10)!!' '!!substr(sif_c,34,length(sif_c)-34+1);
			/*Changer F ->P pour les conjoints*/
			if substr(sif,21,1)='P' and substr(sif,33,1)='P' then 
					sif_c=substr(sif_c,1,20)!!'0'!!substr(sif_c,22,11)!!' '!!substr(sif_c,34,length(sif_c)-34+1);
			if substr(sif,17,1)='F' and substr(sif,33,1)='F' then do;
				sif_c=substr(sif_c,1,16)!!'0'!!substr(sif_c,18,3)!!'P'!!substr(sif_c,22,11)!!'P'!!substr(sif_c,34,length(sif_c)-34+1);
				if substr(sif,21,1)='P' and substr(sif,32,1)='P' then 
				sif_c=substr(sif_c,1,31)!!' '!!substr(sif_c,33,length(sif_c)-33+1);
				end;

			/*Changement de declar*/
			declar_c=substr(declar,1,12)!!substr(sif_c,5,5)!!'-'!!substr(sif_c,11,4)!!substr(declar,23,7)!!anaisenf_c;
			drop f g r j n h;
			run;

		data simul_decl;
			set simul_decl;
			length  f g r j n h $1;
			/* Changer les pacs*/
			f=put(COUNTC(anaisenf_d,'F'),1.);
			g=put(COUNTC(anaisenf_d,'G'),1.);
			r=put(COUNTC(anaisenf_d,'R'),1.);
			j=put(COUNTC(anaisenf_d,'J'),1.);
			n=put(COUNTC(anaisenf_d,'N'),1.);
			h=put(COUNTC(anaisenf_d,'H'),1.);
			sif_d=substr(sif,1,10)!!'9999'!!substr(sif,15,51)!!'0'!!f!!'G'!!'0'!!g!!'R'!!'0'!!r!!'J'!!'0'!!j!!'N'!!'0'!!n!!'H'!!'0'!!h!!substr(sif,83,length(sif)-83+1);
			/* Changer M,O -> C dans sif*/
			sif_d=substr(sif_d,1,4)!!'C'!!substr(sif_d,6,length(sif_d)-6+1);
			/*Supprimer S*/
			if  substr(sif_d,22,1)='S' then 
				sif_d=substr(sif_d,1,21)!!'0'!!substr(sif_d,23,10)!!' '!!substr(sif_d,34,length(sif_d)-34+1);
			/*Changer F ->P pour les conjoints*/
			if substr(sif,17,1)='F' and substr(sif,33,1)='F' then do;
				sif_d=substr(sif_d,1,16)!!'0'!!substr(sif_d,18,15)!!' '!!substr(sif_d,34,length(sif_d)-34+1);
				end;

			/* Changement de declar*/
			declar_d=substr(declar,1,12)!!substr(sif_d,5,5)!!'-'!!substr(sif_d,11,4)!!substr(declar,23,7)!!compress(anaisenf_d);
			drop f g r j n h;
			run;

		/*******************************************************/
		/* 3ème étape : définition des noi pour les conjoints  */
		/*******************************************************/

		proc sort data=travail.indivi&anr.; by declar1; run;
		proc sort data=a_separer_2; by declar; run;
		data noi1;
			merge 	a_separer_2 (keep=ident noi declar rename=(noi=noi_couple) in=a) 
					travail.indivi&anr.(keep=ident noi persfip declar1 rename=(declar1=declar));
			by declar;
			/* on merge la déclaration à séparer avec le déclarant ou le conjoint correspondant 
			dans travail.indivi&anr. */
			if a & persfip ne 'pac' & noi ne noi_couple;
			run; 
		/*remarque après test, il n'y a personne avec les declar2, c'est logique car par définition, 
		les gens qu'on cherche n'ont qu'un seul declar*/

		/* On fait la même chose avec la table des infividus FIP */
		proc sort data=travail.indfip&anr.; by declar1; run;
		data noi2;
			merge 	a_separer_2 (keep=ident noi declar rename=(noi=noi_couple) in=a) 
					travail.indfip&anr.(keep=ident noi persfip declar1 rename=(declar1=declar));
			by declar;
			if a & persfip ne 'pac' & noi ne noi_couple;
			run; 

		/* Changement de format de variable*/
		data noi; set noi1 noi2; if noi ne '' & persfip='conj';	noin=input(noi,2.);run;
		proc sort data=noi; by ident; run;
		proc sort data=a_separer_2 ; by ident; run;

		/* On intègre ce nouveau de conjoint dans le declar */
		data simul_conj;
			merge 	simul_conj (in=a) 
					noi (keep=ident noin in=b);
			by ident;
			if a & b;
			if noin<10 then declar_c=cats('0',noin,substr(declar_c,3,length(declar_c)-3+1));
			else declar_c=cats(noin,substr(declar_c,3,length(declar_c)-3+1));
			drop noin ;
			run;

		/*************************************************/
		/* 4ème étape : simulation des revenus des pacs  */
		/*************************************************/

		data simul_rev_pac;
		 	merge 	simul_conj (keep=ident anaisenf anaisenf_d anaisenf_c moisev in=a) 
					a_separer_2 (keep=ident &VarPac1. &VarPac2. &VarPac1Expli. &VarPac2Expli. &VarPac3. &VarPac4. &VarPac6ans. 
								&Pac1Cocher. &Pac2Cocher. &Pac1CocherExpli. &Pac2CocherExpli.);
			by ident;
			if a;
			run;

		data enf_sans_GetI;
			set simul_rev_pac;
		/*on supprime les G, I, etc parce qu'ils s'agit d'enfant qui sont déclarés aussi en F,H,etc, 
			on veut éviter les doubles comptes*/
		/*Anaisenf*/
			/*On supprime les enfants invalides marqués 'G' (1 enfant invalide)*/
			if count(anaisenf,'G')=1 then do;		/*On supprime le mot 'G****' de anaisenf1*/
				ix=index(anaisenf,'G'); 	k=length(anaisenf);
				if ix=1 then anaisenf=substr(anaisenf,5+1,k-5);
				else if ix=k-5+1 then anaisenf=substr(anaisenf,1,ix-1);
				else anaisenf=substr(anaisenf,1,ix-1)!!substr(anaisenf,ix+5,k-ix-5+1);
				end;
			
			/*On supprime les enfants invalides marqués 'G' (2 enfants invalides)*/
			else if count(anaisenf,'G')=2 then do;		/*On supprime le premiere mot inv='G****' de anaisenf1*/
				ix=index(anaisenf,'G');		k=length(anaisenf);
				if ix=1 then anaisenf=substr(anaisenf,5+1,k-5);
				else if ix=k-5+1 then anaisenf=substr(anaisenf,1,ix-1);
				else anaisenf=substr(anaisenf,1,ix-1)!!substr(anaisenf,ix+5,k-ix-5+1);
				/*On supprime le 2eme mot 'G****'*/
				ix=index(anaisenf,'G');		k=length(anaisenf);
				if ix=1 then anaisenf=substr(anaisenf,5+1,k-5);
				else if ix=k-5+1 then anaisenf=substr(anaisenf,1,ix-1);
				else anaisenf=substr(anaisenf,1,ix-1)!!substr(anaisenf,ix+5,k-ix-5+1);
				end;
			
			/*On supprime les enfants invalides marqués 'I' (1 enfant invalide)*/
			if count(anaisenf,'I')=1 then do;		/*On supprime le mot inv='G****' de anaisenf*/
				ix=index(anaisenf,'I');		k=length(anaisenf);
				if ix=1 then anaisenf=substr(anaisenf,5+1,k-5);
				else if ix=k-5+1 then anaisenf=substr(anaisenf,1,ix-1);
				else anaisenf=substr(anaisenf,1,ix-1)!!substr(anaisenf,ix+5,k-ix-5+1);
				end;

		/*Anaisenf_d*/
			if count(anaisenf_d,'G')=1 then do;		/*On supprime le mot 'G****' de anaisenf_d1*/ 
				ix=index(anaisenf_d,'G'); 	k=length(anaisenf_d);
				if ix=1 then anaisenf_d=substr(anaisenf_d,5+1,k-5);
				else if ix=k-5+1 then anaisenf_d=substr(anaisenf_d,1,ix-1);
				else anaisenf_d=substr(anaisenf_d,1,ix-1)!!substr(anaisenf_d,ix+5,k-ix-5+1);
				end;
			/*On supprime les enfants invalides marqués 'G' (2 enfants invalides)*/
			else if count(anaisenf_d,'G')=2 then do;		/*On supprime le premiere mot inv='G****' de anaisenf_d1; */
				ix=index(anaisenf_d,'G');		k=length(anaisenf_d);
				if ix=1 then anaisenf_d=substr(anaisenf_d,5+1,k-5);
				else if ix=k-5+1 then anaisenf_d=substr(anaisenf_d,1,ix-1);
				else anaisenf_d=substr(anaisenf_d,1,ix-1)!!substr(anaisenf_d,ix+5,k-ix-5+1);
				/*On supprime le 2eme mot 'G****'*/
				ix=index(anaisenf_d,'G');		k=length(anaisenf_d);
				if ix=1 then anaisenf_d=substr(anaisenf_d,5+1,k-5);
				else if ix=k-5+1 then anaisenf_d=substr(anaisenf_d,1,ix-1);
				else anaisenf_d=substr(anaisenf_d,1,ix-1)!!substr(anaisenf_d,ix+5,k-ix-5+1);
				end;
			/*On supprime les enfants invalides marqués 'I' (1 enfant invalide)*/
			if count(anaisenf_d,'I')=1 then do;		*On supprime le mot inv='G****' de anaisenf_d; 
				ix=index(anaisenf_d,'I');		k=length(anaisenf_d);
				if ix=1 then anaisenf_d=substr(anaisenf_d,5+1,k-5);
				else if ix=k-5+1 then anaisenf_d=substr(anaisenf_d,1,ix-1);
				else anaisenf_d=substr(anaisenf_d,1,ix-1)!!substr(anaisenf_d,ix+5,k-ix-5+1);
				end;

			/*Anaisenf_c*/
			if count(anaisenf_c,'G')=1 then do;		*On supprime le mot 'G****' de anaisenf_c1; 
				ix=index(anaisenf_c,'G'); 	k=length(anaisenf_c);
				if ix=1 then anaisenf_c=substr(anaisenf_c,5+1,k-5);
				else if ix=k-5+1 then anaisenf_c=substr(anaisenf_c,1,ix-1);
				else anaisenf_c=substr(anaisenf_c,1,ix-1)!!substr(anaisenf_c,ix+5,k-ix-5+1);
				end;
			/*On supprime les enfants invalides marqués 'G' (2 enfants invalides)*/
			else if count(anaisenf_c,'G')=2 then do;		/*On supprime le premiere mot inv='G****' de anaisenf_c1*/
				ix=index(anaisenf_c,'G');		k=length(anaisenf_c);
				if ix=1 then anaisenf_c=substr(anaisenf_c,5+1,k-5);
				else if ix=k-5+1 then anaisenf_c=substr(anaisenf_c,1,ix-1);
				else anaisenf_c=substr(anaisenf_c,1,ix-1)!!substr(anaisenf_c,ix+5,k-ix-5+1);
				/*On supprime le 2eme mot 'G****'*/
				ix=index(anaisenf_c,'G');		k=length(anaisenf_c);
				if ix=1 then anaisenf_c=substr(anaisenf_c,5+1,k-5);
				else if ix=k-5+1 then anaisenf_c=substr(anaisenf_c,1,ix-1);
				else anaisenf_c=substr(anaisenf_c,1,ix-1)!!substr(anaisenf_c,ix+5,k-ix-5+1);
				end;
			/*On supprime les enfants invalides marqués 'I' (1 enfant invalide)*/
			if count(anaisenf_c,'I')=1 then do;		*On supprime le mot inv='G****' de anaisenf_c; 
				ix=index(anaisenf_c,'I');		k=length(anaisenf_c);
				if ix=1 then anaisenf_c=substr(anaisenf_c,5+1,k-5);
				else if ix=k-5+1 then anaisenf_c=substr(anaisenf_c,1,ix-1);
				else anaisenf_c=substr(anaisenf_c,1,ix-1)!!substr(anaisenf_c,ix+5,k-ix-5+1);
				end;
			drop ix k;
			run;
		/* on sélectionne dans c la date de naissance de l'enfant à charge le plus âgé et dans d, le 
		second on fait l'hypothèse que le plus vieux est le pac1 et le deuxième le pac2*/
		data enf_sans_GetI(drop=i); 
			set enf_sans_GetI;
			length c d $4;
			c='9999'; d='9999';
			do i = 0 to 6;
				if input(substr(anaisenf,5*i+2,4),4.)<input(c,4.) & substr(anaisenf,5*i+2,4) ne ''  then do; 
					d=c;
					c=substr(anaisenf,5*i+2,4); 
					end; 
				else if input(substr(anaisenf,5*i+2,4),4.)<input(d,4.) & substr(anaisenf,5*i+2,4) ne '' then do; 
					d=substr(anaisenf,5*i+2,4); 
					end;
				end;
			run;

		/* On definit les pacs et les données pour déclarant et pour les conjoints*/
		data pac1_d(keep=&VarPac1. &Pac1Cocher. &VarPac1Expli. &Pac1CocherExpli. ident)  
			pac1_c (keep=&VarPac1. &Pac1Cocher. &VarPac1Expli. &Pac1CocherExpli. ident)  
			pac2_d (keep=&VarPac2. &Pac2Cocher. &VarPac2Expli. &Pac2CocherExpli. ident)  
			pac2_c (keep=&VarPac2. &Pac2Cocher. &VarPac2Expli. &Pac2CocherExpli. ident);  
			set enf_sans_GetI; 
			if index(anaisenf_d,c)>0 then output pac1_d; 
			if index(anaisenf_c,c)>0 then output pac1_c; 
			if index(anaisenf_d,d)>0 then output pac2_d; 
			if index(anaisenf_c,d)>0 then output pac2_c; 
			run;

		/*****************************************************************************************/
		/* 5ème étape : Simulation de frais de garde des enfants de moins de 6 ans de conjoints  */
		/*****************************************************************************************/


		/* Cas des Enfants à charge */
		/* n1 la date de naissance de l'enfant le plus jeune, puis n2 puis n3 */
		data enf_sans_GetI1(drop=i); set enf_sans_GetI;
			length n1 n2 n3 $4.;
			n1='9999'; n2='9999'; n3='9999';
			do i = 0 to 6;
				if input(substr(anaisenf,5*i+2,4),4.)<input(n1,4.) 
					& input(substr(anaisenf,5*i+2,4),4.)>=&anref.-6 
					& substr(anaisenf,5*i+2,4) ne '' 
					& substr(anaisenf,5*i+1,1) ne 'H' then do;
					n3=n2; 
					n2=n1;
					n1=substr(anaisenf,5*i+2,4); 
					end; 
				else if input(substr(anaisenf,5*i+2,4),4.)<input(n2,4.) 
						& input(substr(anaisenf,5*i+2,4),4.)>=input(&anref.,4.)-6 
						& substr(anaisenf,5*i+2,4) ne '' 
						& substr(anaisenf,5*i+1,1) ne 'H'  then do; 
					n3=n2;
					n2=substr(anaisenf,5*i+2,4); 
					end;
				else if input(substr(anaisenf,5*i+2,4),4.)<input(n3,4.) 
						& input(substr(anaisenf,5*i+2,4),4.)>=input(&anref.,4.)-6 
						& substr(anaisenf,5*i+2,4) ne '' 
						& substr(anaisenf,5*i+1,1) ne 'H' then do;
					n3=substr(anaisenf,5*i+2,4); 
					end;
				end;
			run;

		data enf1_d(keep=_7ga ident)  
			enf1_c (keep=_7ga ident)  
			enf2_d (keep=_7gb ident) 
			enf2_c (keep=_7gb ident)
			enf3_d (keep=_7gc ident)
			enf3_c (keep=_7gc ident);  
			set enf_sans_GetI1; 
			if index(anaisenf_d,n1)>0 then output enf1_d; 
			if index(anaisenf_c,n1)>0 and index(anaisenf_d,n1)=0 then output enf1_c; 
			if index(anaisenf_d,n2)>0 then output enf2_d; 
			if index(anaisenf_c,n2)>0 and index(anaisenf_d,n2)=0 then output enf2_c; 
			if index(anaisenf_d,n3)>0 then output enf3_d; 
			if index(anaisenf_c,n3)>0 and index(anaisenf_d,n3)=0 then output enf3_c; 
			run;

		/* Cas des enfants à charge en résidence alternée */
		/* n1 la date de naissance de l'enfant le plus jeune, puis n2 puis n3 */
		data enf_sans_GetI2(drop=i); 
			set enf_sans_GetI;
			length a1 a2 a3 $4;
			a1='9999'; a2='9999'; a3='9999';
			do i = 0 to 6;
				if input(substr(anaisenf,5*i+2,4),4.)<input(a1,4.) 
					& input(substr(anaisenf,5*i+2,4),4.)>=input(&anref.,4.)-6 
					& substr(anaisenf,5*i+2,4) ne '' 
					& substr(anaisenf,5*i+1,1)='H' then do;
						a3=a2; 
						a2=a1;
						a1=substr(anaisenf,5*i+2,4); 
					end; 
				else if input(substr(anaisenf,5*i+2,4),4.)<input(a2,4.) 
					& input(substr(anaisenf,5*i+2,4),4.)>=input(&anref.,4.)-6 
					& substr(anaisenf,5*i+2,4) ne '' 
					& substr(anaisenf,5*i+1,1)='H'  then do; 
						a3=a2;
						a2=substr(anaisenf,5*i+2,4); 
					end;
				else if input(substr(anaisenf,5*i+2,4),4.)<input(a3 ,4.)
					& input(substr(anaisenf,5*i+2,4),4.)>=input(&anref.,4.)-6 
					& substr(anaisenf,5*i+2,4) ne '' 
					& substr(anaisenf,5*i+1,1)='H' then do;
						a3=substr(anaisenf,5*i+2,4); 
					end;
				end;
			run;

		data enf1a_d(keep=_7ge ident)  
			enf1a_c (keep=_7ge ident)  
			enf2a_d (keep=_7gf ident) 
			enf2a_c (keep=_7gf ident)
			enf3a_d (keep=_7gg ident)
			enf3a_c (keep=_7gg ident);  
			set enf_sans_GetI2; 
			if index(anaisenf_d,a1)>0 then output enf1a_d; 
			if index(anaisenf_c,a1)>0 and index(anaisenf_d,a1)=0 then output enf1a_c; 
			if index(anaisenf_d,a2)>0 then output enf2a_d; 
			if index(anaisenf_c,a2)>0 and index(anaisenf_d,a2)=0 then output enf2a_c; 
			if index(anaisenf_d,a3)>0 then output enf3a_d; 
			if index(anaisenf_c,a3)>0 and index(anaisenf_d,a3)=0 then output enf3a_c; 
			run;

		/****************************************************************/
		/* 6ème étape : Simulation des revenus des personnes à charges  */
		/****************************************************************/

		/* 	On suppose que les revenus sont perçus uniformement pendant l'année.
		Pour calculer les revenus pré evenement on proratise les revenus déclarés post événement 
		en fonction du mois de l'événement */
		data simul_rev_pac;
			merge 	simul_rev_pac (keep=ident anaisenf anaisenf_d anaisenf_c moisev) 
					pac1_c 
					pac2_c 
					enf1_c 
					enf1a_c 
					enf2_c 
					enf2a_c;
			by ident;

			array varpacs &VarPac1. &VarPac2. &VarPac1Expli. &VarPac2Expli. &VarPac3. &VarPac4. &VarPac6ans.;
			array pacs &VarPac1. &VarPac2. &VarPac1Expli. &VarPac2Expli. &VarPac3. &VarPac4. &Pac1Cocher. &Pac2Cocher. 
						&Pac1CocherExpli. &Pac2CocherExpli. &VarPac6ans.;

			do i=1 to dim(varpacs);
				if moisev='1' then varpacs(i)=0;
				else if varpacs(i) ne . then 
					varpacs(i)=round(varpacs(i)*(input(moisev,4.)-1)/(12-input(moisev,4.)+1));
				else varpacs(i)=.;
				end;

			do over pacs;
				if pacs=. then pacs=0;
				end;
			/* et on laisse les cases cochées comme dans la déclaration commune*/
			drop i anaisenf anaisenf_d anaisenf_c moisev;
			run;


		/***********************************************************/
		/* 7ème étape : nombre d'enfants poursuivant leurs études  */
		/***********************************************************/
		data simulation_etudes;
		 	merge 	simul_conj (keep=ident in=a) 
					a_separer_2 (keep=ident &EtudesEnf.) 
					declarants_2 (keep=ident &EtudesEnf. 
						rename=(_7ea=_7ea_d _7ec=_7ec_d _7ef=_7ef_d _7eb=_7eb_d _7ed=_7ed_d _7eg=_7eg_d));
						/* Il faudrait corriger cet appel explicite aux variables fiscales et faire le renommage de manière implicite*/
			by ident;
			if a;
			run;

		%macro suffix(oldvarlist, suffix);
			%global newvarlist; /* macrovariable utilisable en sortie de la macro */
			%let newvarlist=;
			%let k=1;
			  %let old = %scan(&oldvarlist., &k.);
			     %do %while("&old." NE "");
			      	%let new = &old.&suffix;
					%let newvarlist=&newvarlist. &new.;
				  	%let k = %eval(&k. + 1);
			      	%let old = %scan(&oldvarlist., &k.);
			  	%end;
			%mend;

		/*On crée une nouvelle macrovariable listvar_coef pour determiner la liste des coefficients*/
		%suffix(&EtudesEnf.,_d);
		%let EtudesEnf_d=&newvarlist.;
		data simulation_etudes1;
			set simulation_etudes;
			array EtudesEnf &EtudesEnf.;
			array EtudesEnf_d &EtudesEnf_d.;

			do i=1 to dim(EtudesEnf);
				if EtudesEnf(i)>=EtudesEnf_d(i) then EtudesEnf(i)=EtudesEnf(i)-EtudesEnf_d(i);
				else EtudesEnf(i)=0;
			end;

			drop i &EtudesEnf_d.;
			run;

		/**************************************************/
		/* 8ème étape : simulation des revenus vous-conj  */
		/**************************************************/

		/* On veut simuler les variables "vous" de la déclaration de conjoint à partir des variables 
		"conj" dans la déclaration commune*/
		proc sort data=a_separer_2; by ident; run;
		data simul_rev_indiv;
			merge 	a_separer_2 (keep=ident moisev &listVousSomme. &VousSommeExpli. &listVousCocher. &VousCocherExpli. 
								&listConjSomme. &ConjSommeExpli. &listConjCocher. &ConjCocherExpli.)  
					simul_conj (keep=ident in=a); 
			by ident;
			if a;
			run;

		data simul_rev_indiv;
			set simul_rev_indiv;
			array Vectvous &listVousSomme. &VousSommeExpli.;
			array Vectconj &listConjSomme. &ConjSommeExpli.;
			array listVousCocher &listVousCocher. &VousCocherExpli.;
			array listConjCocher &listConjCocher. &ConjCocherExpli.;

			do i=1 to dim(Vectvous);
				if moisev='1' then Vectvous(i)=0;
				else if Vectvous(i) ne . then 
					Vectvous(i)=round(Vectconj(i)*(input(moisev,4.)-1)/(12-input(moisev,4.)+1)); 
					/* dépend de nombre de mois avant le mariage*/
				else Vectvous(i)=.;
				Vectconj(i)=0;
				end;
			
			do j=1 to dim(listVousCocher);
				listVousCocher(j)=listConjCocher(j);
				listConjCocher(j)=0;
				end;
			drop i j moisev;
			run;

		/************************************************/
		/* 9ème étape : simulation des revenus communs  */
		/************************************************/

		%macro rename(oldvarlist, suffix);
		  	%let k=1;
		  	%let old = %scan(&oldvarlist., &k.);
		    %do %while("&old." NE "");
		      	rename &old. = &old.&suffix;
			  	%let k = %eval(&k. + 1);
		      	%let old = %scan(&oldvarlist., &k.);
		  		%end;
			%mend;
		%macro suffix(oldvarlist, suffix);
			%global newvarlist;
			%let newvarlist=;
			%let k=1;
			%let old = %scan(&oldvarlist., &k.);
		    %do %while("&old." NE "");
		      	%let new = &old.&suffix;
				%let newvarlist=&newvarlist. &new.;
			  	%let k = %eval(&k. + 1);
		      	%let old = %scan(&oldvarlist., &k.);
		  		%end;
			%mend;

		data declarants_2s;
			set declarants_2;
			keep ident &listvar. &listvarExpli. &listCocher. &listCocherExpli. /*&varAns.*/;
			%rename(&listvar. &listvarExpli. &listCocher. &listCocherExpli. /*&varAns.*/,_d);
			run;
		%suffix(&listvar. &listvarExpli.,_d);
		%let listvar_d=&newvarlist.;

		data simul_rev_commune;
			merge 	simul_conj (keep=ident in=a) a_separer_2 (keep=ident moisev &listvar. &listvarExpli. &listCocher. &listCocherExpli. /*&varAns.*/) 
					declarants_2s (keep=ident &listvar_d.);
			by ident;
			if a;
			run;

		data simul_rev_commune;
			set simul_rev_commune;
			array listvar &listvar. &listvarExpli.;
			array listvar_d &listvar_d.;
			do i=1 to dim(listvar);
				if (input(moisev,4.)-1)/(12-input(moisev,4.)+1)*listvar(i)-listvar_d(i)<0 
				then listvar(i)=0;
				else listvar(i)=round((input(moisev,4.)-1)/(12-input(moisev,4.)+1)*listvar(i)-listvar_d(i));
				end;
			/* On suppose que les données pour les variables listCocher et varAns restent comme dans 
			la déclaration commune */
			/* &varans. et &varpac6ans. sont en fait déjà incluses dans &listvar ; et les variables de &EtudesEnf. sont dans &listCocher.  
			On ne souhaite pas que ce soit le cas donc on les supprime */
			drop i moisev &listvar_d. &VarPac6ans. &varAns. &EtudesEnf. ; 
			run;

		/*******************************************************************/
		/* 10ème étape : simulation de la table totale pour les conjoints  */
		/*******************************************************************/
		data simul_conj;
			set simul_conj;
			sif=sif_c;
			declar=declar_c;
			anaisenf=anaisenf_c;
			keep sif declar ident anaisenf;
			run;

		data conjoints_avantm_simules;
			merge  	simul_conj 
					simul_rev_indiv 
					simul_rev_pac 
					simulation_etudes1 
					simul_rev_commune;
			by ident;
			/*on refait les calculs à partir du sif ici*/
			%standard_foyer;
			%CalculAgregatsERFS;
			run; 

		/*sauvegarde dans foyer*/ 
		data travail.foyer&anr.;
			set travail.foyer&anr. 
				conjoints_avantm_simules(drop=augm_plaf caccf cbicf cbncf rename=(zvalf=zvalfo zvamf=zvamfo)); /*ces variables n'existent pas encore dans foyer*/
			run;

		data declar; 
			set simul_conj(keep=declar); 
			length noi $2. ident $8. ; 
			noi=substr(declar,1,2); 
			ident=substr(declar,4,8);
			rename declar=declar_c;
			run;

		proc sort data=travail.indivi&anr.; by ident noi; run;
		proc sort data=travail.indfip&anr.; by ident noi; run;
		proc sort data=declar; by ident noi; run;
		data travail.indivi&anr.; 
			merge 	travail.indivi&anr.(in=b) 
					declar(in=a);
			by ident noi;
			if b;
			if a then do; 
				if declar1='' then declar1=declar_c; 
				else if declar2='' then declar2=declar_c;
				persfip='conj'; persfipd='mad';
				end;
			run; 
		data travail.indfip&anr.; 
			merge 	travail.indfip&anr.(in=b) 
					declar(in=a);
			by ident noi;
			if b;
			if a then do; 
				if declar1='' then declar1=declar_c; 
				else if declar2='' then declar2=declar_c;
				persfip='conj'; persfipd='mad';
				end;
			run; 

		proc datasets mt=data library=work kill;run;quit;
		%end;

	%mend;

%CorrigeDeclarManq_evtX(&anleg.);

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

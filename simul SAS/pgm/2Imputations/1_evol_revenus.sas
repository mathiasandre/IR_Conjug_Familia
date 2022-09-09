/************************************************************************************/
/*																					*/
/*									EVOL_REVENUS									*/
/*																					*/
/************************************************************************************/

/* Dérive des revenus non-simulés individualisés et non individualisables 		*/
/* En entrée : 	&dossier.\derive_revenu.xls										*/
/*				dossier.FoyerVarType											*/
/* 				cd.irf&anr.e&anr.t1												*/
/* 				cd.irf&anr.e&anr.t2												*/
/* 				cd.irf&anr.e&anr.t3												*/
/* 				cd.irf&anr.e&anr.t4												*/
/* 				cd.irf&anr.e&anr1.t1											*/
/* 				cd.irf&anr.e&anr1.t2											*/
/* 				cd.irf&anr.e&anr1.t3											*/
/* 				cd.icompt1ela&anr.												*/
/* 				cd.icompt2ela&anr. 												*/
/* 				rpm.icomprf&anr.e&anr.t1										*/
/* 				rpm.icomprf&anr.e&anr.t2										*/
/* 				rpm.icomprf&anr.e&anr.t3										*/
/* 				rpm.icomprf&anr.e&anr1.t1										*/
/* 				rpm.icomprf&anr.e&anr1.t2										*/
/* 				rpm.icomprf&anr.e&anr1.t3										*/
/*				travail.indivi&anr.												*/
/*				travail.foyer&anr.												*/
/*				travail.menage&anr												*/
/*				travail.indfip&anr.												*/
/* 				travail.mrf&anr.e&anr.											*/
/* En sortie 	base.foyer&anr.         		                          		*/
/*  			base.foyer&anr1.                		                  	 	*/
/*				base.foyer&anr2.												*/
/*				base.baserev													*/
/*				base.menage&anr2.			                              	 	*/
/********************************************************************************/
/*	PLAN 																		*/
/********************************************************************************/
/* 	1	Préalable																*/
/* 		1.1	Configuration de la dérive											*/
/* 		1.2 Coefficients de dérive idoines										*/
/* 		1.3	Agrégats de cases selon le mode de vieillissement					*/
/* 		1.4	Macro %Derive														*/
/* 		1.5	Calcul de l'effet du calage socio-démo sur l'évolution des revenus	*/
/*		1.6	Rustine pour le changement d'assiette des retraites et salaires		*/
/*		entre les déclarations de 2013 et de 2014 (sur les revenus 2012 et 2013)*/
/* 2	Calcul des coefficients de dérive pour les 2 années (avec ajustements)	*/
/* 		2.1	Rapprochement entre les données ACEMO et les donnees EE 			*/
/*		2.2	Correction des évolutions des salaires et chomages avec les cibles  */
/*		2.3	Rapprochement entre infos EE avec ACEMO modifiés et tables fiscales */
/* 3	Dérive des revenus n°1 (appliquée aux revenus individuels)				*/
/*		3.1	Revalorisation des cases fiscales									*/
/*		3.2	Revalorisation des revenus dans la table indivi&anr					*/
/*		3.3	Revalorisation des revenus dans la table indfip&anr					*/
/* 4	Dérive des revenus individuels n°2 (anr1-anr2 dans le cas classique)	*/
/* 		4.1	Revalorisation des cases fiscales 									*/
/* 		4.2	Revalorisation des revenus dans la table indivi&anr1 				*/
/* 		4.3	Revalorisation des revenus dans la table indfip&anr1 				*/
/* 5	Empilement des années pour construire base.baserev						*/
/* 6	Dérive des revenus non individualisables						   		*/
/********************************************************************************/

/* Idée générale
	On dérive les revenus deux fois : derive_1 et derive_2.
	Pour les salaires, le chomage, les retraites et les revenus des indépendants, on fait la 1er dérive avec un coefficient en masse (car 
	on a calé sur les nombres dans l'étape de calage), qu'on corrige en introduisant de l'hétérogénéité à partir des résultats de l'enquête
	ACEMO pour les salaires. Il y a une correction en plus pour prendre en compte le calage sur le nombre de déclaration pour ces coeffs.
	Les autres coefficients de dérive sont en masse par tête.
	Pour la 2e dérive, on utilise des coefficients de dérive en masse par tête.

/* Remarques :
	- les plus-values : à défaut d'informations sur les PV valeurs mobilieres, 
	qui représentent 94% des PV, on dérive selon l'indice Bourse française SBF250 (cac-all-tradable).
	L'ERFS ne les inclut pas dans le rev initial/disponible 
	car c'est un revenu considéré comme exceptionnel. Le surplus d'impôt les concernant est retranché du niveau
	de vie, par cohérence interne mais contrairement à ce qui est fait en comptabilité nationale. 
	Il s'agit pourtant de montants importants et tres mouvants. Dans Ines, on ne les inclut pas non plus dans le RD,
	mais on les conserve dans le calcul de l'impôt.

	- CSG deductible sur revenus patrimoine (case _6de) : on applique de manière ponderee 
	les taux d'evolution des revenus fonciers, mobiliers, accessoires et rentes viageres, avant de 
	faire evoluer les ponderations (indice Laspeyres)

	- on ne dérive pas :
		- variables qualitatives
		- variables horaires
		- variables plus ou moins de stock :
			 * rentes viageres et rentes survie-handicap : zrtof _1aw _1bw _1cw _1dw
			 * les reports de deficits anterieurs

	/* A CORRIGER : 
	- 	il faudrait s'occuper de dériver les 4e et 5e PAC 1ep, 1fp 1ej 1fj
	- 	On ne fait évoluer les loyers sur qu'un an au lieu de deux. Les allocations logement dépendent 
		des loyers de l'année N et des revenus N-2. Si la méthode d'imputation des loyers dans l'ERFS évolue 
		et en particulier l'évolution des montants imputés d'une année sur l'autre et devient déclinée 
		en fonction de la tranche d'unité urbaine ou du statut d'occupation, on pourra affiner notre évolution. */


/********************************************************************************/
/* 1	PREALABLE																*/
/********************************************************************************/

/* 1.1	Configuration de la dérive												*/

/* Import de Config_Derive (onglet de derive_revenu qui n'a pas encore été importé) */
%importFichier(derive_revenu,config_derive,config_derive);
%Macro Config_Derive;
	/* On est dans l'un des trois cas : Ines classique, évaluation contemporaine du Nowcasting, ou évaluation décalée du Nowcasting */
	%global cas;
	%let cas=Ines_classique;
	%if &Nowcasting.=oui %then %do;
		%if &Contemp.=1 %then %do;
			%let cas=NC_contemp;
			%end;
		%if &Decal.=1 %then %do;
			%let cas=NC_decal;
			%end;
		%end;
	data _null_;
		set dossier.config_derive (keep=nom &cas.);
		if nom ne '';
		call symputx(nom,&cas.,'G');
		run;
	%Mend Config_Derive;
%Config_Derive;

/* Définition de toutes les 4 années envisageables dans les cas : 
		- Ines classique (découplé ou non)
		- évaluation contemporaine du Nowcasting
		- évaluation décalée du Nowcasting */
%let an_2=%substr(%eval(&anref.-2),3,2);
%let an_1=%substr(%eval(&anref.-1),3,2);
%let an0=%substr(%eval(&anref.),3,2);
%let an1=%substr(%eval(&anref.+1),3,2);
%let an2=%substr(%eval(&anref.+2),3,2);


/* Pour aider à la lecture par la suite */
/* Des variables qui se compilent en 10, 11, 12, 13 ... */
/* Pour Ines classique il y a équivalence parfaite entre : 
	d11 et anr
	d12, d21 et anr1
	d22 et anr2
Mais cette façon de voir la dérive est beaucoup plus modulable pour faire du nowcasting */
%let d11=&&&derive1_in.;
%let d12=&&&derive1_out.;
%let d21=&&&derive2_in.;
%let d22=&&&derive2_out.;
%put LA DERIVE DES REVENUS SERA EFFECTUEE DE LA FACON SUIVANTE : DERIVE 1 de &d11. VERS &d12. et DERIVE 2 de &d21. VERS &d22.;


/*	1.2	Calcul des coef de dérive idoines								*/

/* Renommage et ajustement éventuel des macrovariables : 
en sortie on a des paramètres nommés TXSAL_derive1, TXCHO_derive2 ...
Dans le cas d'Ines normal cela correspond aux valeurs an0_an1 et an1_an2, 
mais cette astuce est très commode pour le nowcasting 					*/

%Macro AjusteCoef_Derive;

	/*********************************************************************************************************/
	/* 1	On crée 2 listes (pour dérives n°1 et 2), contenant les débuts de noms de macrovariables à créer */
	data MVACreer1; set dossier.param_derive; find=find(nom,"_an0_an1"); if find>0; run;
	data MVACreer1; set MVACreer1; debut=substr(nom,1,find-1); run;
	proc transpose data=MVACreer1 out=temp (drop=_name_ _label_); id debut; run;
	%ListeVariablesDUneTable(table=temp,mv=MVACreer1,except=_name_ _label_, separateur=' ');
	
	data MVACreer2; set dossier.param_derive; find=find(nom,"_an1_an2"); if find>0; run;
	data MVACreer2; set MVACreer2; debut=substr(nom,1,find-1); run;
	proc transpose data=MVACreer2 out=temp (drop=_name_ _label_); id debut; run;
	%ListeVariablesDUneTable(table=temp,mv=MVACreer2,except=_name_ _label_, separateur=' ');

	/***************************************************************************************/
	/* 2	On va chercher les bonnes lignes et colonnes pour chaque macrovariable à créer */
	/* DERIVE N°1 */
	%do i=1 %to %sysfunc(countw(&MVACreer1.));
		%let MV=%scan(&MVACreer1.,&i.);
		data _null_;
			set dossier.param_derive;
			if upcase(nom)=upcase("&MV.&derive1_row."); /* on récupère la bonne ligne */
			nom="&MV._derive1";
			keep nom &derive1_col.;
			call symputx(nom,&derive1_col.,'G'); /* on récupère la bonne colonne */
			run;
		%end;
	/* DERIVE N°2 */
	%do i=1 %to %sysfunc(countw(&MVACreer2.));
		%let MV=%scan(&MVACreer2.,&i.);
		/* Cas normal : information disponible */
		data _null_;
			set dossier.param_derive;
			if upcase(nom)=upcase("&MV.&derive2_row."); /* on récupère la bonne ligne */
			nom="&MV._derive2";
			keep nom &derive2_col.;
			call symputx(nom,&derive2_col.,'G'); /* on récupère la bonne colonne */
			run;
		/* Cas du Nowcasting / évaluation décalée : 
			certaines des informations ne sont pas disponibles en octobre N+1 pour le Nowcasting N. 
			Même si l'on s'intéresse à une année antérieure, on veut pouvoir faire l'exercice "en conditions réelles", 
			c'est-à-dire sans disposer des informations qui n'ont été disponibles qu'après la date où on aurait
			effectué l'exercice. 
			Principe : si l'information pour N n'est pas disponible en octobre N+1, on fait la même hypothèse 
			que pour la dérive an1_an2 réalisée l'année précédente dans Ines classique */
		%if &Nowcasting.=oui %then %do;
			%if &Decal.=1 %then %do; /* Condition en deux temps sinon bug pour Ines classique car ne connaît pas &Decal. */
			%Macro Ecrit_Condition;
				%if &cond_reelle.=oui %then %do;
					/* 6 premiers cas : En attente d'information complémentaire sur an0_an1 on utilise une autre source */
					/* 2 cas suivants : En attente d'information complémentaire sur an0_an1 on fait une hypothèse tendancielle */
					/* 6 cas suivants : En attente d'information complémentaire sur an0_an1 on fait une hypothèse tendancielle */
					/* 2 derniers cas : Info bien disponible mais paramètre n'existe pas en tant que an0_an1 : il se trouve que la manip à effectuer est la même */
					%upcase(&MV.)=TXSAL or %upcase(&MV.)=TXRET or %upcase(&MV.)=TXalr or %upcase(&MV.)=TXrto or %upcase(&MV.)=TXpi or %upcase(&MV.)=TXAGR
						or %upcase(&MV.)=TXBIC or %upcase(&MV.)=TXBNC
						or %upcase(&MV.)=TXval or %upcase(&MV.)=TXrevvam or %upcase(&MV.)=TXdefvam or %upcase(&MV.)=TXREVFONC or %upcase(&MV.)=TXdefFONC or %upcase(&MV.)=TXACC
						or %upcase(&MV.)=TXCHO or %upcase(&MV.)=TXTH
					%end;
				%else %do;
				/* Uniquement les deux derniers cas : paramètres n'existent pas en tant que an0_an1 */
					%upcase(&MV.)=TXCHO or %upcase(&MV.)=TXTH
					%end;
				%Mend Ecrit_Condition;

				%if	%Ecrit_Condition %then %do;
					data _null_;
						set dossier.param_derive;
						if upcase(nom)=upcase(compress("&MV."||"&derive2_row_dispoct0.")); /* on récupère la bonne ligne */
						nom="&MV._derive2";
						keep nom &derive2_col_dispoct0.;
						call symputx(nom,&derive2_col_dispoct0.,'G'); /* on récupère la bonne colonne */
						run;
					%end;
				%end;
			%if &Contemp.=1 %then %do;
				%if %upcase(&MV.)=TXCHO or %upcase(&MV.)=TXTH %then %do;
				/* 2 cas où l'info bien disponible mais paramètre n'existe pas en tant que an0_an1 : il faut aller chercher le an1_an2 de l'année d'avant */
					data _null_;
						set dossier.param_derive;
						if upcase(nom)=upcase(compress("&MV."||"_an1_an2")); /* on récupère la bonne ligne */
						nom="&MV._derive2";
						keep nom valeur_ERFS_%eval(&anref.-3);
						call symputx(nom,valeur_ERFS_%eval(&anref.-3),'G'); /* on récupère la bonne colonne */
						run;
					%end;
				%end;
			%end;
		%end;

	/***************************************************************************************************************/
	/* 3	Création des tables MVCreees1 et MVCreees2 dans la Work : vérif intermédiaire + servent dans l'étape 4 */
	%do k=1 %to 2; /* Dérive n°k (1 ou 2) */
		data MVCreees&k. (drop=debut);
			set MVACreer&k. (keep=debut);
			nom=compress(debut||"_derive&k.");
			valeur=symgetn(nom);
			run;
		%end;

	/***********************************************/
	/* 4	Dérive inverse éventuelle (nowcasting) */
	%do k=1 %to 2; /* Dérive n°k (1 ou 2) */
		data MVCreees&k.;
			set MVCreees&k.;
			%if &&&derive&k._inverse.=1 %then %do;
				valeur=1/(1+valeur)-1;
				%end;
			call symputx(nom,valeur,'G');
			run;
		%end;
	proc delete data=MVACreer1 MVACreer2; run;
	%Mend AjusteCoef_Derive;

%AjusteCoef_Derive;


/******************************************************************************************/
/*	1.3 Définition des groupes de cases fiscales selon la façon dont on les fera vieillir */

/* Correspond : 
	1\ au contour des agrégats + distinction par individu uniquement dans le cadre des salaires (car on fait quelque chose de plus fin)
	2\ pour les cases n'appartenant pas aux agrégats, on isole celles qui sont des montants, et on les vieillit de manière ad hoc
		- soit selon l'évolution des salaires (COMME_SAL)
		- soit selon l'évolution du Smic (COMME_SMIC)
		- soit selon l'évolution des revenus de valeurs mobilieres (COMME_VAM)
		- autres cas particuliers (RSA activité, plus-values)
		- soit, pour tous les autres montants, selon l'inflation (COMME_INFL)
*/


/****************************/
/* 1.3.1\ Salaires et chômage : 
		cases qui composent l'agrégat 
		+ ajout d'autres cases ou grandeurs calculées par Ines, que l'on souhaite vieillir comme les salaires, 
		en gardant la finesse CSP*secteur */

	/*a/salaires*/
%CreeListeCases(zsalf,vous,ajout=part_employ_vous part_salar_vous _1ak _7ac _6rs _rachatretraite_vous _6qs _1ac _hsupVous);
%CreeListeCases(zsalf,conj,ajout=part_employ_conj part_salar_conj _1bk  _7ae _6rt _rachatretraite_conj _6qt _1ey _1bc _hsupConj);
%CreeListeCases(zsalf,pac1,ajout=part_employ_pac1 part_salar_pac1 _1ck _7ag _6ru _6qu _1cc _hsupPac1);
%CreeListeCases(zsalf,pac2,ajout=part_employ_pac2 part_salar_pac2 _1dk _1dc _hsupPac2);
%CreeListeCases(zsalf,pac3,ajout=part_employ_pac3 part_salar_pac3 _1ek);
	/*b/chomage*/
%CreeListeCases(zchof,vous);
%CreeListeCases(zchof,conj);
%CreeListeCases(zchof,pac1);
%CreeListeCases(zchof,pac2);
%CreeListeCases(zchof,pac3);

/* En sortie &liste_cas_part. contient toutes les variables qui ont été ajoutés aux agrégats par défaut dans des "ajout="*/

/****************************************************************************************************/
/* 1.3.2\ Autres agrégats : plus de distinction individuelle, vieillissement homogène pour tout le monde
	Du coup on n'a rien à faire, les listes de cases associées aux agrégats ont déjà été définies dans le programme macros_OrgaCases */

/**************************************************************************************************/
/* 1.3.3\ Cases qui ne font pas partie d'un agrégat de l'ERFS (typiquement, montants de dépenses) */

/* 1.3.3.1 - RSA activité */
%let RSAACT=_rsa_compact_ppe_f _rsa_compact_ppe_pac1 _rsa_compact_ppe_pac2;
/* 1.3.3.2 - Plus-values */
%let COMME_PV=_3vn _3wa _3wb _abatt_moinsval _abatt_moinsval_renfor _abatt_moinsval_dirpme ;
/* 1.3.3.3 - Comme le Smic */
%let COMME_SMIC=_7df _7ga _7gb _7gc _7ge _7gf _7gg _7db; /* frais de garde et emplois familiaux */
/* 1.3.3.4 - Commes les salaires (sans le détail CSP*secteur d'Acemo) : certaines cases de zetr ou zavv + autres */
%let COMME_SAL=	_8ti _8tm _8tn _8ta _8vl _8vm _8wm _8um _8th _8tk _8tr _8sc _8tq _8tv _8tw _8sw _8tx _8sx /* idée générale : les revenus à l'étranger */
				_7ud _7uf _7xs _7xt _7xu _7xw _7uh _7xy _7va _7vc; /* idée générale : les dons */
/* 1.3.3.5 - Commes les revenus de capitaux mobiliers */
%let COMME_VAM=_8sa _8sb;

%let liste_cas_part=&liste_cas_part. &RSAACT. &COMME_PV. &COMME_SMIC. &COMME_SAL. &COMME_VAM.;
%AjouteUpcaseGuillemetsAListe(&liste_cas_part.); /* Crée une liste appelée ListeOut */
%put &ListeOut.;

/* 1.3.3.6 : résiduel de tout ce qui précède : toutes les autres cases contenant des montants seront vieillies comme l'inflation */
data x; /* contiendra toutes les variables résiduelles, ie pas déjà vieillies autrement */
	set dossier.FoyerVarList;
	if agregatERFS="" and index(typeContenu,"Montant")>0; /* on garde les cases indiquant des montants et n'appartenant à aucun agrégat */
	if upcase(name) in (&ListeOut.) then delete; /* les cases vieillies en 1.3.2 ou en 1.2.1 dans des "ajout=" sont déjà vieillies */
	run;
proc transpose data=x out=x_ (drop=_name_ _label_); id name; run;
%ListeVariablesDUneTable(table=x_,mv=COMME_INFL,separateur=' ');
proc delete data=x x_; run;



/*************************************/
/* 1.4	Ecriture de la macro %Derive */
/* Definition de macros de revalorisation*/
%macro Derive(montant,taux);
	/*Cette macro remplace les elements de montant par montant*(1+taux) 
	Le paramètre montant peut être une variable ou une liste de variables 
	Le paramètre taux peut être une macrovariable ou une variable*/
	%do count =1 %to %sysfunc(countw(&montant.,' '));
		%let var= %scan(&montant.,&count.,' ');
		%let condition=&var. ne .;
		%if &condition %then %do;
			%let valeur=round(&var.*(1+&taux.))%str(;);
			%scan(&montant.,&count.,' ')=&valeur.;
			%end;
		%end;
	%mend Derive;


/**********************************************************************************************/
/* 	1.5	Calcul de l'effet du calage socio-démo sur l'évolution des revenus */
/*	Principe de cette étape : purger le coefficient de dérive initial de ce qu'on a déjà obtenu rien qu'avec le calage
	L'effet résultant du calage est obtenu en faisant le rapport des masses pondérées par les poids avant et après calage */
/* Attention, cette opération n'est effectuée que sur la première dérive et non la deuxième. 
	Car seuls les coefficients de la première dérive sont relatifs à des masses et non à des évolutions par tête */
/* On gère les cas (très rares) où la variable serait égale à 0 pour toutes les observations (par exemple zpii avant son arrivée dans l'ERFS)
	en mettant dans ce cas l'effet du calage socio démo à 0 (sinon la variable n'a que des points dans la suite du traitement et cela est source de bugs */
proc sql noprint;
	select	case  when sum(zsalm) ne 0 then sum((zsalm)*wpela&d12.)/sum((zsalm)*wpela&d11.)-1 else 0 end,
				 	case  when sum(zchom) ne 0 then sum((zchom)*wpela&d12.)/sum((zchom)*wpela&d11.)-1 else 0 end,
					case  when sum(zrstm) ne 0 then sum((zrstm)*wpela&d12.)/sum((zrstm)*wpela&d11.)-1 else 0 end,
					case  when sum(zpim) ne 0 then sum((zpim)*wpela&d12.)/sum((zpim)*wpela&d11.)-1 else 0 end, /*attention les ERFS avant 2013 ne contiennent pas de zpi*/
					case  when sum(zalrm) ne 0 then sum((zalrm)*wpela&d12.)/sum((zalrm)*wpela&d11.)-1 else 0 end,
					case  when sum(zrtom) ne 0 then sum((zrtom)*wpela&d12.)/sum((zrtom)*wpela&d11.)-1 else 0 end,
					case  when sum(zragm) ne 0 then sum((zragm)*wpela&d12.)/sum((zragm)*wpela&d11.)-1 else 0 end,
					case  when sum(zricm) ne 0 then sum((zricm)*wpela&d12.)/sum((zricm)*wpela&d11.)-1 else 0 end,
					case  when sum(zrncm) ne 0 then sum((zrncm)*wpela&d12.)/sum((zrncm)*wpela&d11.)-1 else 0 end

		into:txsal_derive1_calage,
			:txcho_derive1_calage,
			:txrst_derive1_calage,
			:txpi_derive1_calage, 
			:txalr_derive1_calage, 
			:txrto_derive1_calage,
			:txagr_derive1_calage,
			:txbic_derive1_calage,
			:txbnc_derive1_calage
		from travail.menage&d11.;
	quit;

/**********************************************************************************************/
/* 1.6	Rustine pour tenir compte du changement d'assiette des retraites et salaires
		entre la déclaration de 2013 et celle de 2014 (sur les revenus 2012 et 2013) */
/* Problème : 
	- dans le calage sur marges de anref, on a comme marge les déclarations en montants qui sont avant ruptures de série
	- dans le calage sur marges de anref+1, on a comme marge les déclarations en montants qui sont après ruptures de série
Le coefficient de dérive n°1 relatif aux salaires et aux retraites (importé de l'Excel) est obtenu avec la même information, 
il est donc lui aussi est trop élevé du fait de ces ruptures de série. 
Principe de ces rustines : se remettre dans les contours des cases fiscales initiales et calculer l'évolution avant/après calage des masses ainsi définies. 
De la même manière que sur un revenu non concerné par une rupture de série, il faut alors mettre en miroir 
le coefficient de l'Excel et le ratio des masses pondérées avant/après calage (et "déduire" l'un de l'autre). */
/* NB : pas d'autre rustine à faire sur d'autres années car : 
	- pour la dérive n°2 les coefficients d'évolution ne sont pas issus de la même source
	- pour le calage de l'année anref+2 les marges des déclarations en nombres ne sont pas utilisées (indisponibles). */
proc sql noprint;
	%macro RustineMajo;
		%if &Nowcasting.=non and &anref.=2012 %then %do; /* Le problème 2012-2013 porte alors sur la première dérive */
			select	sum((zrstm)*wpela&d12.)/sum((zrstm-majo)*wpela&d11.)-1
				into:txrst_derive1_calage
				from travail.menage&anr.;
			%end;
		%mend;
	%RustineMajo;
	%macro RustineParticipationEmployeur;
		%if &Nowcasting.=non and &anref.=2012 %then %do; /* Le problème 2012-2013 porte alors sur la première dérive */
			select	sum((zsalm)*wpela&d12.)/sum((zsalm-part_employ)*wpela&d11.)-1
				into:txsal_derive1_calage
				from travail.menage&anr.;
			%end;
		%mend;
	%RustineParticipationEmployeur;
	quit;




/************************************************************************************************/
/* 2	Calcul des coefficients de dérive pour les deux années (avec ajustements)				*/
/************************************************************************************************/
/* 2.1	Rapprochement entre les données ACEMO et les donnees EE : on donne à chaque individu le taux d'évolution de son CSP*secteur */

%Macro Acemo(variables=,table_sortie=,inverse=0);
	/*
	On importe la table d'évolution des salaires par CSP et secteur d'activité provenant des résultats de l'enquête ACEMO.
	Le secteur est codé par la variable NAF2 et NAF2B ventilée en 88 postes avec la nomenclature rev 2 (révision intervenue en 2008). 
	Lorsque la valeur est manquante pour le croisement CSP*NAF2, on met l'évolution du salaire moyen du secteur. 
	Lorsque cette évolution pour l'ensemble du secteur est manquante, on met l'évolution du croisement CSP*NAF2B avec NAF2B un secteur proche.
	Le paramètre inverse permet d'indiquer si l'on souhaite inverse l'évolution, dans le cas, où l'on souhaite revenir dans le temps */
	%if &inverse.=1 %then %do;
		/* 	En cas de dérive inverse le nom entré dans "variables" ne correspond pas aux noms des colonnes de l'Excel : 
			il faut inverser dans les noms puis on réinversera les valeurs plus loin */
		%let variables=%sysfunc(tranwrd(&variables.,20&d11._20&d12.,20&d12._20&d11.)); /* Inversion éventuelle pour la dérive n°1 */
		%let variables=%sysfunc(tranwrd(&variables.,20&d21._20&d22.,20&d22._20&d21.)); /* Inversion éventuelle pour la dérive n°2 */
		%end;

	data acemo(drop=%scan(&variables.,1));
		set dossier.acemo(firstobs=2);
		%do i=2 %to 5;
			if %scan(&variables.,&i.)=. then %scan(&variables.,&i.)=%scan(&variables.,1);
			%end;
		run;
	proc sort data=acemo; by naf2 naf2b; run;
	proc transpose data=acemo out=acemo(rename=(_name_=csp_acemo col1=taux_evol) drop=_label_);
		var %scan(&variables.,2) %scan(&variables.,3) %scan(&variables.,4) %scan(&variables.,5);
		by naf2 naf2b; 
		run;
	data acemo(drop=csp_acemo);
		set acemo;
		format csp $1.;
		if csp_acemo="%scan(&variables,2)" then csp='6';
		else if csp_acemo="%scan(&variables,3)" then csp='5';
		else if csp_acemo="%scan(&variables,4)" then csp='4';
		else if csp_acemo="%scan(&variables,5)" then csp='3';
		%if &inverse.=1 %then %do;
			if taux_evol ne . then taux_evol=1/(1+taux_evol)-1;
			%end;
		run;
	proc sort data=acemo out=acemo_complement; by naf2b csp; run;
	proc sort data=acemo(drop=naf2b rename=(naf2=naf2b taux_evol=taux_evol2)); by naf2b csp; run;
	data acemo_complete;
		merge acemo_complement(in=a) acemo;
		by naf2b csp;
		if a;
		run;
	proc sort data=acemo_complete nodupkey out=&table_sortie.(keep=naf2 csp taux_evol2 
		rename=(taux_evol2=tx_sal naf2=secteur)); 
		by naf2 csp;
		run;
	%mend Acemo;

%Acemo(	variables=Ens_20&d11._20&d12.
				Ouv_20&d11._20&d12.
				Emp_20&d11._20&d12.
				Pin_20&d11._20&d12.
				Cad_20&d11._20&d12.,
		table_sortie=Acemo_derive1,
		inverse=&derive1_inverse.);

%Acemo(	variables=Ens_20&d21._20&d22.
				Ouv_20&d21._20&d22.
				Emp_20&d21._20&d22.
				Pin_20&d21._20&d22.
				Cad_20&d21._20&d22.,
		table_sortie=Acemo_derive2,
		inverse=&derive2_inverse.);


/* Récupération du secteur d'activité et de la CSP des diverses tables de l'enquête Emploi.
TODO : récupérer un des calendriers qui contiendrait ces informations pour ne pas une nouvelle fois faire appel aux tables de l'EE. 
On gagnerait ainsi du temps. */

%macro ListeVarEE(year);
	/* Liste les variables EEC pertinentes, en fonction de l'année. En particulier, la variable 
	nafapn disparait en 2013 et nafan change de nom */
	ident&anr. noi noindiv &NAF. cser csar naia
	%if &year.<2013 %then %do;
		nafapn nafan rename=(nafan=nafant)
		%end;
	%else %do; nafant %end;
	%mend;
%macro EE;
	data ee(rename=(ident&anr.=ident));
		%if &noyau_uniquement.=non %then %do;
			set cd.irf&anr.e&anr.t1 		(in=a keep=%ListeVarEE(&anref.))
				cd.icompt1ela&anr. 			(in=b keep=%ListeVarEE(&anref.))
				rpm.icomprf&anr.e&anr.t1 	(in=c keep=%ListeVarEE(&anref.))
				cd.irf&anr.e&anr.t2 		(in=d keep=%ListeVarEE(&anref.))
				cd.icompt2ela&anr. 			(in=e keep=%ListeVarEE(&anref.))
				rpm.icomprf&anr.e&anr.t2 	(in=f keep=%ListeVarEE(&anref.)) 
				cd.irf&anr.e&anr.t3 		(in=g keep=%ListeVarEE(&anref.))
				rpm.icomprf&anr.e&anr.t3 	(in=h keep=%ListeVarEE(&anref.))
				cd.irf&anr.e&anr.t4			(in=i keep=%ListeVarEE(&anref.))
				cd.irf&anr.e&anr1.t1 		(in=j keep=%ListeVarEE(%eval(&anref.+1)))
				rpm.icomprf&anr.e&anr1.t1 	(in=k keep=%ListeVarEE(%eval(&anref.+1)))
				cd.irf&anr.e&anr1.t2 		(in=l keep=%ListeVarEE(%eval(&anref.+1)))
				rpm.icomprf&anr.e&anr1.t2	(in=m keep=%ListeVarEE(%eval(&anref.+1)))
				cd.irf&anr.e&anr1.t3 		(in=n keep=%ListeVarEE(%eval(&anref.+1)))
				rpm.icomprf&anr.e&anr1.t3	(in=o keep=%ListeVarEE(%eval(&anref.+1)));
			if a or b or c then rang=7;
			if d or e or f then rang=6;
			if g or h then rang=5;
			if i then rang=1;
			if j or k then rang=2;
			if l or m then rang=3;
			if n or o then rang=4;
			%end;
		%else %do;
			set	rpm.icomprf&anr.e&anr.t1 	(in=c keep=%ListeVarEE(&anref.))
				rpm.icomprf&anr.e&anr.t2 	(in=f keep=%ListeVarEE(&anref.))
				rpm.icomprf&anr.e&anr.t3 	(in=h keep=%ListeVarEE(&anref.))
				rpm.irf&anr.e&anr.t4 		(in=i keep=%ListeVarEE(&anref.))
				rpm.icomprf&anr.e&anr1.t1 	(in=k keep=%ListeVarEE(%eval(&anref.+1)))
				rpm.icomprf&anr.e&anr1.t2	(in=m keep=%ListeVarEE(%eval(&anref.+1)))
				rpm.icomprf&anr.e&anr1.t3	(in=o keep=%ListeVarEE(%eval(&anref.+1)));

			if c then rang=7;
			if f then rang=6;
			if h then rang=5;
			if i then rang=1;
			if k then rang=2;
			if m then rang=3;
			if o then rang=4;
			%end;
		run;
	%mend;
%EE;

/*on applique les évolutions des salaires mensuels de bases par secteur d'activité (88 postes) des ouvriers, employés, professions intermédiaires 
et cadres; lorsque le croisement secteur/catégorie sociale n'est pas renseigné, on fait évoluer le salaire comme l'évolution moyenne du secteur, 
et à défaut, l'évolution moyenne de la même catégorie sociale, pour un secteur proche, et encore à défaut, l'évolution moyenne des salaires)*/
data ee(drop=&NAF. nafant csar);
	format naf_ $2.;
	set ee;
	naf_=substr(&NAF.,1,2); /*&NAF. renvoie à la variable décrivant le secteur (NAFN ou NAF selon l'année de l'ERFS)*/
	/*lorsque le secteur actuel est manquant (NAF), on remplace par le secteur de l'ancien emploi (nafant)*/
	if naf_='' then do;
		if nafant ne '' then naf_=nafant;
		end;
	/*lorsque la CSP actuelle est manquante (CSER), on remplace par la CSP du dernier emploi occupé (CSAR)*/
	if cser='' then do; 
		if csar ne '' then cser=csar;
		end;
	run;

/* On choisit l'information la plus pertinente pour chaque individu : d'abord l'information du noyau (rang=1) 
	puis celle du T1 de l'année suivante (rang=2) etc*/
proc sort data=ee; by ident noi rang;run;
data csp_secteur(keep=secteur csp ident noi) AnneeNaissance(keep=ident noi naia);
	format secteur $2.;
	retain CSP secteur;
	set ee;
	by ident noi;
	if first.noi then do;
		csp='';
		secteur='';
		end;
	if csp='' then csp=cser;
	if secteur='' then secteur=naf_;
	if last.noi and csp in ('3','4','5','6') and secteur not in ('','00') then output csp_secteur;
	if last.noi then output AnneeNaissance;
	run;

/* On intègre les revenus de travail.indivi&anr. dans la table CSP_SECTEUR*/
proc sort data=travail.indivi&d11.(keep=ident noi ident &RevIndividuels. declar1 declar2) out=travindivi; by ident noi; run;
data csp_secteur;
	merge 	csp_secteur 
			travindivi(in=a);
	if a;
	by ident noi;
	run;
proc sort data=csp_secteur;by secteur csp;run;


data Acemo_derive1;
	merge csp_secteur(in=a) Acemo_derive1(in=b);
	by secteur csp;
	if a and b;
	run;
data Acemo_derive2;
	merge csp_secteur(in=a) Acemo_derive2(in=b);
	by secteur csp;
	if a and b;
	run; 
proc sort data=Acemo_derive1; by ident noi; run;
proc sort data=Acemo_derive2; by ident noi; run;

data Acemo;
	merge 	travindivi(in=a) AnneeNaissance
			Acemo_derive1(rename=(tx_sal=txsal&d11._&d12.)) 
			Acemo_derive2(rename=(tx_sal=txsal&d21._&d22.));
	txcho&d11._&d12.=txsal&d11._&d12.;
	txcho&d21._&d22.=txsal&d21._&d22.;
	/* Ajustement de l'évolution induite par le calage sur marges (on a le détail Ztsa pour l'évolution mais pas pour le calage d'où une légère incohérence lors de la prise en compte du calage)*/
	if txsal&d11._&d12.=. then do;
		txsal&d11._&d12.=((&txsal_derive1.+1)/(&txsal_derive1_calage.+1)-1);
		txcho&d11._&d12.=((&txcho_derive1.+1)/(&txcho_derive1_calage.+1)-1); /* ou utiliser txsal_derive1 qui est plus homogène?*/
		end;
	if txsal&d21._&d22.=. then do;
		txsal&d21._&d22.=&txsal_derive2.;
		txcho&d21._&d22.=&txcho_derive2.;
		end;
	by ident noi;
	if a;
	run;


/* 2.2	Ajustement des taux d'évolutions cibles pour les salaires et les revenus du chômage. En sortie : 
	-> variables txsal&d11._&d12., txsal&d21._&d22., txcho&d11._&d12. et txcho&d21._&d22. dans la table ACEMO
	-> variables txsal&d21._&d22., txsal&d11._&d12., txcho&d11._&d12. et txcho&d21._&d22. dans la table indivi&d11.
	-> macrovariables txsal_derive2_aj et txcho_derive2_aj */

proc sql noprint;
	/********************/
	/* 2.2.1 Dérive n°1 */
	/* Principe : 	- il faut purger le coefficient cible (txsal_derive1) de ce qui est déjà induit par le calage
					- il faut tenir compte de l'effet moyen + d'un effet individuel */
	create table indivi&d11.bis as
		/* 2.2.1.1	Création de ztsai en d12 avec l'évolution Acemo INDIVIDUELLE -> ztsai_derive1 */
		select a.*,b.wpela&d12., 
				/*(a.zsali+a.zchoi) as ztsai,*/
				(a.zsali)*(1+a.txsal&d11._&d12.) as zsali_derive1,
				(a.zchoi)*(1+a.txcho&d11._&d12.) as zchoi_derive1
		from acemo as a left join travail.menage&d11. as b
		on a.ident=b.ident;
		/* 2.2.1.2	Effet MOYEN salaire seul d'ACEMO (effet calage anihilé en utilisant deux fois le même poids) -> txsal_derive1_Acemo */
	select	sum(zsali_derive1*wpela&d12.)/sum(zsali*wpela&d12.)-1, 
			sum(zchoi_derive1*wpela&d12.)/sum(zchoi*wpela&d12.)-1
		into:txsal_derive1_acemo, :txcho_derive1_acemo
		from indivi&d11.bis;
		/* 2.2.1.3	Taux d'évolution final à appliquer = 
						celui de derive_revenu + prise en compte calage + ajustement avec les données Acemo (rapport entre evol par CS*secteur et evol moyenne d'ACEMO)
						donc homogéne à un coef en masse*/
	update acemo
		set txsal&d11._&d12.=((&txsal_derive1.+1)/(&txsal_derive1_calage.+1)-1)*(txsal&d11._&d12./&txsal_derive1_acemo.),
			txcho&d11._&d12.=((&txcho_derive1.+1)/(&txcho_derive1_calage.+1)-1)*(txcho&d11._&d12./&txcho_derive1_acemo.);
		/* Si txsal_d11_d12=txsal_derive1_acemo (tout le monde a le taux moyen),
		alors in fine le taux est celui de derive_revenu simplement purgé de l'effet moyen du calage */

	/********************/
	/* 2.2.2 Dérive n°2 */
	/* 2.2.2.1	Création de zsali et zchoi en d12 et d22 avec l'évolution Acemo INDIVIDUELLE -> zsali_derive2, zchoi_derive2 */
	create table indivi&d11.bis as
		select a.*,b.wpela&d22., 
				zsali*(1+txsal&d11._&d12.) as zsali_derive1,
				zchoi*(1+txcho&d11._&d12.) as zchoi_derive1,
				zsali*(1+txsal&d11._&d12.)*(1+txsal&d21._&d22.) as zsali_derive2,
				zchoi*(1+txcho&d11._&d12.)*(1+txcho&d21._&d22.) as zchoi_derive2
		from acemo as a left join travail.menage&d11. as b
		on a.ident=b.ident
		order by ident,noi;
		/* 2.2.2.2	Effet MOYEN Acemo seul (effet calage anihilé en utilisant deux fois le même poids) -> txsal_derive2_Acemo (= coef txsal_an1_an2 dans fichier excel), txcho_derive2_Acemo */
		select 	sum(zsali_derive2*wpela&d22.)/sum(zsali_derive1*wpela&d22.)-1,
				sum(zchoi_derive2*wpela&d22.)/sum(zchoi_derive1*wpela&d22.)-1
				into :txsal_derive2_acemo, :txcho_derive2_acemo
			from indivi&d11.bis;
		/* 2.2.2.3	Taux d'évolution final à appliquer = 
						salaire : évolution Acemo (_derive2) + prise en compte calage + ajustement avec les données Acemo
						chômage : évolution Unédic (_derive2) + prise en compte calage + ajustement avec les données Acemo */
	update acemo
		set txsal&d21._&d22.=&txsal_derive2.*(txsal&d21._&d22./&txsal_derive2_acemo.),
			txcho&d21._&d22.=&txcho_derive2.*(txcho&d21._&d22./&txcho_derive2_acemo.);
	/* 2.2.2.4	Taux d'évolution ajustés (pour plus tard) -> txsal_derive2_aj et txcho_derive2_aj */
	%let txsal_derive2_aj=%sysevalf(&txsal_derive2.*&txsal_derive2./&txsal_derive2_acemo.);
	%let txcho_derive2_aj=%sysevalf(&txcho_derive2.*&txcho_derive2./&txcho_derive2_acemo.);

	/**************************************************************************/
	/* 2.2.3	On met les 3 taux intéressants dans la table indivi de départ */
	create table indivi&d11. as
		select a.*, txsal&d21._&d22., txsal&d11._&d12., txcho&d11._&d12., txcho&d21._&d22.
		from travail.indivi&d11. as a
		left join acemo as b
		on a.ident=b.ident and a.noi=b.noi
		order by ident, noi;
	quit;


/* 	2.3	Rapprochement entre les informations EE avec les taux ACEMO modifiés et les tables fiscales */

/* il faut rapprocher chaque case de la déclaration fiscale à un individu de la table acemo 
pour connaître son secteur d'activité et sa CSP afin d'identifier l'évolution de revenu à 
appliquer. On fait ce rapprochement en utilisant les dates de naissances et les declar*/
data liste_declar(keep=declar) base.foyer&d11.;
	set travail.foyer&d11.; 
	%CalculAgregatsERFS;
	run;

proc sql;
	create table declar1 as
		select a.declar, b.naia, b.noi, b.txsal&d11._&d12.,b.txsal&d21._&d22.,b.txcho&d11._&d12.,b.txcho&d21._&d22.
		from liste_declar as a inner join acemo as b
		on a.declar=b.declar1
		order by a.declar;

	create table declar2 as
		select a.declar, b.naia, b.noi, b.txsal&d11._&d12.,b.txsal&d21._&d22.,b.txcho&d11._&d12.,b.txcho&d21._&d22.
		from liste_declar as a inner join acemo as b
		on a.declar=b.declar2
		order by a.declar;
	quit;


data declar_et_tx (drop=i txsal&d11._&d12. txsal&d21._&d22. txcho&d21._&d22. txcho&d11._&d12. naia noi);
	/* Gestion du cas général : on met les coefficients issus de l'étape 2.2 */
	set declar1 declar2;
	by declar;
	array txsal txsal&d11._&d12._vous txsal&d11._&d12._conj txsal&d11._&d12._pac1 txsal&d11._&d12._pac2 txsal&d11._&d12._pac3
				txsal&d21._&d22._vous txsal&d21._&d22._conj txsal&d21._&d22._pac1 txsal&d21._&d22._pac2 txsal&d21._&d22._pac3
				txcho&d11._&d12._vous txcho&d11._&d12._conj txcho&d11._&d12._pac1 txcho&d11._&d12._pac2 txcho&d11._&d12._pac3
				txcho&d21._&d22._vous txcho&d21._&d22._conj txcho&d21._&d22._pac1 txcho&d21._&d22._pac2 txcho&d21._&d22._pac3;
	retain txsal;
	if first.declar then do i=1 to dim(txsal);
		txsal(i)=0; /* Initialisation de tous les taux à 0 */
		end; 
	if substr(declar,14,4)=naia and substr(declar,1,2)=noi then do; /* L'individu est le déclarant */
		txsal&d11._&d12._vous	=txsal&d11._&d12.;
		txsal&d21._&d22._vous	=txsal&d21._&d22.;
		txcho&d11._&d12._vous	=txcho&d11._&d12.;
		txcho&d21._&d22._vous	=txcho&d21._&d22.;
		end;
	else if substr(declar,19,4)=naia then do; /* L'individu est le conjoint */
		txsal&d11._&d12._conj	=txsal&d11._&d12.;
		txsal&d21._&d22._conj	=txsal&d21._&d22.;
		txcho&d11._&d12._vous	=txcho&d11._&d12.;
		txcho&d21._&d22._conj	=txcho&d21._&d22.;
		end;
	else if naia=substr(declar,31,4) or naia=substr(declar,30,4) then do; /* L'individu est la pac1 */
		txsal&d11._&d12._pac1	=txsal&d11._&d12.;
		txsal&d21._&d22._pac1	=txsal&d21._&d22.;
		txcho&d11._&d12._vous	=txcho&d11._&d12.;
		txcho&d21._&d22._pac1	=txcho&d21._&d22.;
		end;
	else if naia=substr(declar,36,4) or naia=substr(declar,35,4) then do; /* L'individu est la pac2 */
		txsal&d11._&d12._pac2	=txsal&d11._&d12.;
		txsal&d21._&d22._pac2	=txsal&d21._&d22.;
		txcho&d11._&d12._vous	=txcho&d11._&d12.;
		txcho&d21._&d22._pac2	=txcho&d21._&d22.;
		end;
	else if naia=substr(declar,41,4) or naia=substr(declar,40,4) then do; /* L'individu est la pac3 */
		txsal&d11._&d12._pac3	=txsal&d11._&d12.;
		txsal&d21._&d22._pac3	=txsal&d21._&d22.;
		txcho&d11._&d12._vous	=txcho&d11._&d12.;
		txcho&d21._&d22._pac3	=txcho&d21._&d22.;
		end;
	if last.declar;
	run;
proc sort data=declar_et_tx; by declar; run;
proc sort data=travail.indfip&d11.(where=(zsali>0 or zchoi>0) 
			keep=naia persfip zsali zchoi declar1
			rename=(declar1=declar)) out=indfip_revdeclar1; by declar; run;
proc sort data=travail.indfip&d11.(where=((zsali>0 or zchoi>0) & declar ne '')
			keep=naia persfip zsali zchoi declar2
			rename=(declar2=declar)) out=indfip_revdeclar2; by declar; run;

data declar_et_tx_avec_FIP;
	/* Gestion des cas où il y a présence d'individus FIP : 
		pour la dérive 1 on refait un calcul ad hoc
		pour la dérive 2 on prend les coefficients ajustés calculés en 2.2.2.4 */
	merge 	declar_et_tx(in=a)
			indfip_revdeclar1 (in=b)
			indfip_revdeclar2 (in=c);
	by declar;
	if b or c then do; /* Il y a des FIP */
		if substr(declar,14,4)=naia and txsal&d11._&d12._vous=0 then do;
			txsal&d11._&d12._vous	=((&txsal_derive1.+1)/(&txsal_derive1_calage.+1)-1);
			txcho&d11._&d12._vous	=((&txcho_derive1.+1)/(&txcho_derive1_calage.+1)-1);
			txsal&d21._&d22._vous	=&txsal_derive2_aj.;
			txcho&d21._&d22._vous	=&txcho_derive2_aj.;
			end;
		else if substr(declar,19,4)=naia and txsal&d11._&d12._conj=0  then do;
			txsal&d11._&d12._conj	=((&txsal_derive1.+1)/(&txsal_derive1_calage.+1)-1);
			txcho&d11._&d12._conj	=((&txcho_derive1.+1)/(&txcho_derive1_calage.+1)-1);
			txsal&d21._&d22._conj	=&txsal_derive2_aj.;
			txcho&d21._&d22._conj	=&txcho_derive2_aj.;
			end;
		else if naia=substr(declar,31,4) or naia=substr(declar,30,4) then do;
			txsal&d11._&d12._pac1	=((&txsal_derive1.+1)/(&txsal_derive1_calage.+1)-1);
			txcho&d11._&d12._pac1	=((&txcho_derive1.+1)/(&txcho_derive1_calage.+1)-1);
			txsal&d21._&d22._pac1	=&txsal_derive2_aj.;
			txcho&d21._&d22._pac1	=&txcho_derive2_aj.;
			end;
		else if naia=substr(declar,36,4) or naia=substr(declar,35,4) then do;
			txsal&d11._&d12._pac2	=((&txsal_derive1.+1)/(&txsal_derive1_calage.+1)-1);
			txcho&d11._&d12._pac2	=((&txcho_derive1.+1)/(&txcho_derive1_calage.+1)-1);
			txsal&d21._&d22._pac2	=&txsal_derive2_aj.;
			txcho&d21._&d22._pac2	=&txcho_derive2_aj.;
			end;
		else if naia=substr(declar,41,4) or naia=substr(declar,40,4) then do;
			txsal&d11._&d12._pac3	=((&txsal_derive1.+1)/(&txsal_derive1_calage.+1)-1);
			txcho&d11._&d12._pac3	=((&txcho_derive1.+1)/(&txcho_derive1_calage.+1)-1);
			txsal&d21._&d22._pac3	=&txsal_derive2_aj.;
			txcho&d21._&d22._pac3	=&txcho_derive2_aj.;
			end;
		end;
	if last.declar;
	drop zsali zchoi persfip naia;
	run;
proc sort data=base.foyer&d11. out=foyer&d11.; by declar; run;

data TxSalCho_Pour_2Derives (keep=declar: tx:);
	/* Gestion des derniers cas où l'on n'a pas mis de valeurs pour les évolutions de salaire et chomage */
	/* De même, calcul ad hoc pour dérive 1 et taux ajustés issus de 2.2.2.4 pour dérive 2 */
	merge 	declar_et_tx_avec_FIP (in=a)
			foyer&d11.(in=b);
	by declar;
	array txsal txsal&d11._&d12._vous txsal&d11._&d12._conj txsal&d11._&d12._pac1 txsal&d11._&d12._pac2 txsal&d11._&d12._pac3
			txsal&d21._&d22._vous txsal&d21._&d22._conj txsal&d21._&d22._pac1 txsal&d21._&d22._pac2 txsal&d21._&d22._pac3
			txcho&d11._&d12._vous txcho&d11._&d12._conj txcho&d11._&d12._pac1 txcho&d11._&d12._pac2 txcho&d11._&d12._pac3
			txcho&d21._&d22._vous txcho&d21._&d22._conj txcho&d21._&d22._pac1 txcho&d21._&d22._pac2 txcho&d21._&d22._pac3;
	do i=1 to dim(txsal);
		if txsal(i)=. then txsal(i)=0;
		end;
	if b and not a then do; /* Cas non encore traités */
		txsal&d11._&d12._vous	=((&txsal_derive1.+1)/(&txsal_derive1_calage.+1)-1);
		txcho&d11._&d12._vous	=((&txcho_derive1.+1)/(&txcho_derive1_calage.+1)-1);
		txsal&d21._&d22._vous	=&txsal_derive2_aj.;
		txcho&d21._&d22._vous	=&txcho_derive2_aj.;
		txsal&d11._&d12._conj	=&txsal_derive1.-&txsal_derive1_calage.;
		txcho&d11._&d12._conj	=&txcho_derive1.-&txcho_derive1_calage.;
		txsal&d21._&d22._conj	=&txsal_derive2_aj.;
		txcho&d21._&d22._conj	=&txcho_derive2_aj.;
		end;
	if b;
	run;

/* Au terme de cette étape, la table TxSalCho_Pour_2Derives contient tous les coefficients nécessaires pour dériver les revenus salaire et chômage */

/****************************************************************************************************/
/* 3	Dérive des revenus n°1 (anr-anr1 pour Ines classique) appliquée aux revenus individuels		*/
/****************************************************************************************************/

/* 3.1	Revalorisation des cases fiscales */
data base.foyer&d12.; /* Va se compiler en foyer&anr1. pour Ines classique */
	merge foyer&d11. (in=a) TxSalCho_Pour_2Derives;
	by declar;
	if a;

	if sum(zfonf*(zfonf>0),zrtof*(zrtof>0),zvamf*(zvamf>0),zracf*(zracf>0))>0 then 
	_6de=round(_6de*	sum(zfonf*(zfonf>0)*(1+&txrevfonc_derive1.),
							zrtof*(zrtof>0),
							zvamf*(zvamf>0)*(1+&TXrevvam_derive1.),
							zracf*(zracf>0)*(1+&txacc_derive1.))
						/sum(zfonf*(zfonf>0),
							zrtof*(zrtof>0),
							zvamf*(zvamf>0),
							zracf*(zracf>0)));

	%Derive(&_liste_zsalf_vous. ,taux=txsal&d11._&d12._vous);
	%Derive(&_liste_zsalf_conj. ,taux=txsal&d11._&d12._conj);
	%Derive(&_liste_zsalf_pac1. ,taux=txsal&d11._&d12._pac1);
	%Derive(&_liste_zsalf_pac2. ,taux=txsal&d11._&d12._pac2);
	%Derive(&_liste_zsalf_pac3. ,taux=txsal&d11._&d12._pac3);
	%Derive(&_liste_zchof_vous. ,taux=txcho&d11._&d12._vous);
	%Derive(&_liste_zchof_conj. ,taux=txcho&d11._&d12._conj);
	%Derive(&_liste_zchof_pac1. ,taux=txcho&d11._&d12._pac1);
	%Derive(&_liste_zchof_pac2. ,taux=txcho&d11._&d12._pac2);
	%Derive(&_liste_zchof_pac3. ,taux=txcho&d11._&d12._pac3);
	%Derive(&zquofP. &COMME_SAL.,taux=(&txsal_derive1.+1)/(&txsal_derive1_calage.+1)-1);
	%Derive(&zrstfP. majo_vous majo_conj majo_pac1,taux=(&txret_derive1.+1)/(&txrst_derive1_calage.+1)-1);
	%Derive(&zpifP. ,taux=(&txpi_derive1.+1)/(&txpi_derive1_calage.+1)-1);
	%Derive(&zragfP. &zragfN.,taux=(&txagr_derive1.+1)/(&txagr_derive1_calage.+1)-1);
	%Derive(&zricfP. &zricfN.,taux=(&txbic_derive1.+1)/(&txbic_derive1_calage.+1)-1);
	%Derive(&zrncfP. &zrncfN.,taux=(&txbnc_derive1.+1)/(&txbnc_derive1_calage.+1)-1);
	%Derive(&zfonfP.,taux=&txrevfonc_derive1.);
	%Derive(&zfonfN.,taux=&txdeffonc_derive1.);
	%Derive(&zracfP. &zracfN.,taux=&txacc_derive1.);
	%Derive(&zvalfP. ,taux=&TXval_derive1.);
	%Derive(&zvamfP. &COMME_VAM.,taux=&TXrevvam_derive1.);
	%Derive(&zvamfN. ,taux=&TXdefvam_derive1.);
	%Derive(&COMME_PV. &zdivfP. &zdivfN. &zglofP.,taux=&txpv_derive1.);
	%Derive(&COMME_SMIC.,taux=&txsmic_derive1.);
	%Derive(&COMME_INFL.,taux=&inf_derive1.);
	array palim &zalrfP. &zalvfP.;
	do over palim;
		/* Principe : si pension était plafonnée alors on la plafonne également l'année suivante (mais la valeur du plafond a changé) */
		if abs(palim/&&&plaf_pa1_&derive1_in.-1)<=0.01 then palim=&&&plaf_pa1_&derive1_out.;
		else if abs(palim/&&&plaf_pa2_&derive1_in.-1)<=0.01 then palim=&&&plaf_pa2_&derive1_out.;
		/* Si elle n'était pas plafonnée, alors on la revalorise de l'inflation */
		else palim=round(palim*(1+&inf_derive1.));
		end;
	%Derive(&RSAACT.,taux=&txcasersa_derive1.); /* revenus de l'année précédente, le paramètre est décalé d'un an */
	%CalculAgregatsERFS;
	run;


/* 3.2	Revalorisation des revenus dans la table indivi&anr. */
data indivi&d12.; /* Va se compiler en indivi&anr1. pour Ines classique */
	set indivi&d11.;

	if frais=. then frais=0;
	if majo=. then majo=0;
	%Derive(zsali frais part_employ part_salar, taux=txsal&d11._&d12.);
	%Derive(zchoi, taux=txcho&d11._&d12.);
	%Derive(zragi,taux=(&txagr_derive1.+1)/(&txagr_derive1_calage.+1)-1);
	%Derive(zrici,taux=(&txbic_derive1.+1)/(&txbic_derive1_calage.+1)-1);
	%Derive(zrnci,taux=(&txbnc_derive1.+1)/(&txbnc_derive1_calage.+1)-1);
	%Derive(zrsti majo,taux=(&txret_derive1.+1)/(&txrst_derive1_calage.+1)-1);
	%Derive(zpii ,taux=(&txpi_derive1.+1)/(&txpi_derive1_calage.+1)-1);
	array palim zalri;
	do over palim;
		if abs(palim/&&&plaf_pa1_&derive1_in.-1)<=0.01 then palim=&&&plaf_pa1_&derive1_out.;
		else if abs(palim/&&&plaf_pa2_&derive1_in.-1)<=0.01 then palim=&&&plaf_pa2_&derive1_out.;
		else palim=round(palim*(1+&inf_derive1.));
		end;
	run;

/* 3.3	Revalorisation des revenus dans la table indfip&anr. */

data travail.indfip&d12.; /* Va se compiler en indfip&anr1. pour Ines classique */
	set travail.indfip&d11.;

	if frais=. then frais=0;
	if majo=. then majo=0;
	%Derive(zsali frais,taux=((&txsal_derive1.+1)/(&txsal_derive1_calage.+1)-1));
	%Derive(zchoi,taux=((&txcho_derive1.+1)/(&txcho_derive1_calage.+1)-1));
	%Derive(zragi,taux=(&txagr_derive1.+1)/(&txagr_derive1_calage.+1)-1);
	%Derive(zrici,taux=(&txbic_derive1.+1)/(&txbic_derive1_calage.+1)-1);
	%Derive(zrnci,taux=(&txbnc_derive1.+1)/(&txbnc_derive1_calage.+1)-1);
	%Derive(zrsti,taux=(&txret_derive1.+1)/(&txrst_derive1_calage.+1)-1);
	%Derive(zpii,taux=(&txpi_derive1.+1)/(&txpi_derive1_calage.+1)-1);
	array palim zalri;
	do over palim;
		if abs(palim/&&&plaf_pa1_&derive1_in.-1)<=0.01 then palim=&&&plaf_pa1_&derive1_out.;
		else if abs(palim/&&&plaf_pa2_&derive1_in.-1)<=0.01 then palim=&&&plaf_pa2_&derive1_out.;
		else palim=round(palim*(1+&inf_derive1.));
		end;
	run;


/****************************************************************************************************/
/* 4	Dérive des revenus n°2 (anr1-anr2 pour Ines classique) appliquée aux revenus individuels	*/
/****************************************************************************************************/

/* 	4.1	Revalorisation des cases fiscales */
data base.foyer&d22.	/* Va se compiler en foyer&anr2. pour Ines classique */
		(drop=txsal&d11._&d12._vous txsal&d11._&d12._conj txsal&d11._&d12._pac1 txsal&d11._&d12._pac2 txsal&d11._&d12._pac3
		txsal&d21._&d22._vous txsal&d21._&d22._conj txsal&d21._&d22._pac1 txsal&d21._&d22._pac2 txsal&d21._&d22._pac3
		txcho&d11._&d12._vous txcho&d11._&d12._conj txcho&d11._&d12._pac1 txcho&d11._&d12._pac2 txcho&d11._&d12._pac3
		txcho&d21._&d22._vous txcho&d21._&d22._conj txcho&d21._&d22._pac1 txcho&d21._&d22._pac2 txcho&d21._&d22._pac3);
	merge base.foyer&d21. (in=a) TxSalCho_Pour_2Derives;
	by declar;
	if a;
	if sum(zfonf*(zfonf>0),zrtof*(zrtof>0),zvamf*(zvamf>0),zracf*(zracf>0))>0 then 
	_6de=round(_6de*	sum(zfonf*(zfonf>0)*(1+&txrevfonc_derive2.),
							zrtof*(zrtof>0),
							zvamf*(zvamf>0)*(1+&TXrevvam_derive2.),
							zracf*(zracf>0)*(1+&txacc_derive2.))
						/sum(zfonf*(zfonf>0),
							zrtof*(zrtof>0),
							zvamf*(zvamf>0),
							zracf*(zracf>0)));
	%Derive(&_liste_zsalf_vous.,taux=txsal&d21._&d22._vous);
	%Derive(&_liste_zsalf_conj.,taux=txsal&d21._&d22._conj);
	%Derive(&_liste_zsalf_pac1.,taux=txsal&d21._&d22._pac1);
	%Derive(&_liste_zsalf_pac2.,taux=txsal&d21._&d22._pac2);
	%Derive(&_liste_zsalf_pac3.,taux=txsal&d21._&d22._pac3);
	%Derive(&_liste_zchof_vous.,taux=txcho&d21._&d22._vous);
	%Derive(&_liste_zchof_conj.,taux=txcho&d21._&d22._conj);
	%Derive(&_liste_zchof_pac1.,taux=txcho&d21._&d22._pac1);
	%Derive(&_liste_zchof_pac2.,taux=txcho&d21._&d22._pac2);
	%Derive(&_liste_zchof_pac3.,taux=txcho&d21._&d22._pac3);
	%Derive(&zfonfP. &zfonfN.,taux=&txrevfonc_derive2.);
	%Derive(&zquofP. &COMME_SAL.,taux=&txsal_derive2_aj.);
	%Derive(&zrstfP. &zpifP. majo_vous majo_conj majo_pac1,taux=&txret_derive2.);
	%Derive(&zragfP. &zragfN.,taux=&txagr_derive2.);
	%Derive(&zricfP. &zricfN.,taux=&txbic_derive2.);
	%Derive(&zrncfP. &zrncfN.,taux=&txbnc_derive2.);
	%Derive(&zracfP. &zracfN.,taux=&txacc_derive2.);
	%Derive(&zvalfP. ,taux=&TXval_derive2.);
	%Derive(&zvamfP. &COMME_VAM.,taux=&TXrevvam_derive2.);
	%Derive(&zvamfN. ,taux=&TXdefvam_derive2.);
	%Derive(&COMME_SMIC.,taux=&txsmic_derive2.);
	%Derive(&COMME_INFL.,taux=&inf_derive2.);
	%Derive(&COMME_PV. &zdivfP. &zdivfN. &zglofP.,taux=&txpv_derive2.);
	array palim &zalrfP. &zalvfP.;
	do over palim;
		if abs(palim/&&&plaf_pa1_&derive2_in.-1)<=0.01 then palim=&&&plaf_pa1_&derive2_out.;
		else if abs(palim/&&&plaf_pa2_&derive2_in.-1)<=0.01 then palim=&&&plaf_pa2_&derive2_out.;
		else palim=round(palim*(1+&inf_derive2.));
		end;
	%Derive(&RSAACT.,taux=&txcasersa_derive2.); /* revenus de l'année précédente, le paramètre est décalé d'un an */
	%CalculAgregatsERFS;
	run;

/* 4.2	Revalorisation des revenus dans la table indivi&anr1 */
data indivi&d22.;
	set indivi&d21.(keep=ident noi &RevIndividuels. txcho&d21._&d22. txsal&d21._&d22. frais majo part_salar part_employ);

	if frais=. then frais=0;
	if majo=. then majo=0;
	%Derive(zsali frais part_employ part_salar,taux=txsal&d21._&d22.);
	%Derive(zchoi,taux=txcho&d21._&d22.);
	%Derive(zragi,taux=&txagr_derive2.);
	%Derive(zrici,taux=&txbic_derive2.);
	%Derive(zrnci,taux=&txbnc_derive2.);
	%Derive(zrsti zpii majo,taux=&txret_derive2.);
	array palim zalri;
	do over palim;
		if abs(palim/&&&plaf_pa1_&derive2_in.-1)<=0.01 then palim=&&&plaf_pa1_&derive2_out.;
		else if abs(palim/&&&plaf_pa2_&derive2_in.-1)<=0.01 then palim=&&&plaf_pa2_&derive2_out.;
		else palim=round(palim*(1+&inf_derive2.));
		end;
	run;

/* 4.3	Revalorisation des revenus dans la table indfip&anr1. */
data travail.indfip&d22.;
	set travail.indfip&d21.;

	if frais=. then frais=0;
	if majo=. then majo=0;
	%Derive(zsali frais,taux=&txsal_derive2_aj.);
	%Derive(zchoi,taux=&txcho_derive2_aj.);
	%Derive(zragi,taux=&txagr_derive2.);
	%Derive(zrici,taux=&txbic_derive2.);
	%Derive(zrnci,taux=&txbnc_derive2.);
	%Derive(zrsti zpii,taux=&txret_derive2.);
	array palim zalri;
	do over palim;
		if abs(palim/&&&plaf_pa1_&derive2_in.-1)<=0.01 then palim=&&&plaf_pa1_&derive2_out.;
		else if abs(palim/&&&plaf_pa2_&derive2_in.-1)<=0.01 then palim=&&&plaf_pa2_&derive2_out.;
		else palim=round(palim*(1+&inf_derive2.));
		end;
	run;


/************************************************************************************/
/* 5	Empilement des années pour construire base.baserev			                */
/************************************************************************************/
proc sort data=travail.indivi&d11.; by ident noi; run;
proc sort data=indivi&d12.; by ident noi; run;
proc sort data=indivi&d22.; by ident noi; run;
proc sort data=travail.indfip&d11.; by ident noi; run;
proc sort data=travail.indfip&d12.; by ident noi; run;
proc sort data=travail.indfip&d22.; by ident noi; run;
data base.baserev(keep=ident noi zsali: zrsti: zpii: zchoi: zalri: zrtoi: zragi: zrici: zrnci: frais: &RevObserves. majo: part_employ: part_salar:) ; 
	merge 	travail.indivi&d11.(keep=ident noi &RevIndividuels. &RevObserves. majo part_employ part_salar
				rename = (zsali=zsali&d11. zrsti=zrsti&d11. zpii=zpii&d11. zchoi=zchoi&d11. zalri=zalri&d11. 
				zrtoi=zrtoi&d11. zragi=zragi&d11. zrici=zrici&d11. zrnci=zrnci&d11. 
				frais=frais&d11. majo=majo&d11. part_employ=part_employ&d11. part_salar=part_salar&d11.) )   
			indivi&d12.(keep = ident noi &RevIndividuels. majo part_employ part_salar
				rename = (zsali=zsali&d12. zrsti=zrsti&d12. zpii=zpii&d12. zchoi=zchoi&d12. 
				zalri=zalri&d12. zrtoi=zrtoi&d12. zragi=zragi&d12. zrici=zrici&d12. 
				zrnci=zrnci&d12. frais=frais&d12. majo=majo&d12. part_employ=part_employ&d12. part_salar=part_salar&d12.))
			indivi&d22.(keep = ident noi &RevIndividuels. majo part_employ part_salar
				rename = (zsali=zsali&d22. zrsti=zrsti&d22. zpii=zpii&d22. zchoi=zchoi&d22. 
				zalri=zalri&d22. zrtoi=zrtoi&d22. zragi=zragi&d22. zrici=zrici&d22. 
				zrnci=zrnci&d22. frais=frais&d22. majo=majo&d22. part_employ=part_employ&d22. part_salar=part_salar&d22.))
			travail.indfip&d11.(keep=ident noi &RevIndividuels. &RevObserves.
				rename=(zsali=zsali&d11. zrsti=zrsti&d11. zpii=zpii&d11. zchoi=zchoi&d11. zalri=zalri&d11. 
				zrtoi=zrtoi&d11. zragi=zragi&d11. zrici=zrici&d11. zrnci=zrnci&d11. frais=frais&d11.))
			travail.indfip&d12.(keep = ident noi &RevIndividuels.
				rename=(zsali=zsali&d12. zrsti=zrsti&d12. zpii=zpii&d12. zchoi=zchoi&d12. zalri=zalri&d12.
				zrtoi=zrtoi&d12. zragi=zragi&d12. zrici=zrici&d12. zrnci=zrnci&d12. frais=frais&d12.))
			travail.indfip&d22.(keep = ident noi &RevIndividuels.
				rename=(zsali=zsali&d22. zrsti=zrsti&d22. zpii=zpii&d22. zchoi=zchoi&d22. zalri=zalri&d22.
				zrtoi=zrtoi&d22. zragi=zragi&d22. zrici=zrici&d22. zrnci=zrnci&d22. frais=frais&d22.));
	by ident noi; 
	if frais&d11.=. then frais&d11.=0;
	if majo&d11.=. then majo&d11.=0;
	if part_employ&d11.=. then part_employ&d11.=0;
	if part_salar&d11.=. then part_salar&d11.=0;
	run; 

/************************************************************************************/
/* 6	Dérive des revenus non individualisables					                */
/************************************************************************************/

/* à partir de l'ERFS 2013 c'est la TH de anr (changement de millésime) donc on crée txth_derive1 pour la suite */
%CreeParametreRetarde(txth_derive1,dossier.param_derive,txth_an1_an2,ERFS,&anref.,1);

/* Pour ce type de revenus, on n'a besoin que de la dernière année chronologique, qui correspond à anr2 pour Ines classique */
%Macro Derive_Menage;
	proc sort data=travail.menage&d11.
				(keep=ident nb_uci dep zthabm livm jeunm pelm peam lepm celm assviem wpela&d22. loyer loyerfict typmen_Insee) 
				out=menage&d11.;
		by ident;
		run; 
	proc sort data=travail.mrf&d11.e&d11.(keep=ident reg logt TUU2010 nbind) out=infos_supplem; by ident; run;
	data base.menage&d22.; /* On va faire la dérive des deux années en un seul calcul */
		merge 	menage&d11.
				infos_supplem;
		by ident;

		/* Mise à 0 des variables manquantes */
		array variab livm jeunm pelm peam lepm celm assviem;
		do over variab; if missing(variab) then variab=0; end;
		/* Evolution sur 2 années de ces revenus */
		%if &anref.<2013 %then %do;/* dans les ERFS 2012 et antérieures c'est déjà la TH de anr+1 */
			zthabm      =round(zthabm*  (1+&txth_derive2.));
			%end;
		%else %do; /* à partir de l'ERFS 2013 c'est la TH de anr (changement de millésime) */
			zthabm      =round(zthabm*  (1+&txth_derive1.)*(1+&txth_derive2.));
			%end;
		livm		=round(livm*	(&txsal_derive1.+1)/(&txsal_derive1_calage.+1)*	(1+&txsal_derive2.));
		jeunm		=round(jeunm*	(&txsal_derive1.+1)/(&txsal_derive1_calage.+1)*	(1+&txsal_derive2.));
		pelm		=round(pelm*	(&txsal_derive1.+1)/(&txsal_derive1_calage.+1)*	(1+&txsal_derive2.));
		lepm		=round(lepm*	(&txsal_derive1.+1)/(&txsal_derive1_calage.+1)*	(1+&txsal_derive2.));
		celm		=round(celm*	(&txsal_derive1.+1)/(&txsal_derive1_calage.+1)*	(1+&txsal_derive2.));
		assviem		=round(assviem*	(1+&txpv_derive1.)	*(1+&&txpv_derive2.));
		peam		=round(peam*	(1+&txpv_derive1.)	*(1+&&txpv_derive2.));

		/* Calcul de l'agrégat ERFS produitfin_i */
		produitfin_i=sum(livm,jeunm,pelm,peam,lepm,celm,assviem);
		if produitfin_i=. then produitfin_i=0; /*ce n'est pas parfait de faire ça, mais il s'agit d'une erreur
		dans l'ERFS d'indiquer une valeur manquante pour ces revenus. La division RPM dit qu'il s'agit tout de 
		même de revenus nuls, bien qu'il aurait fallu qu'ils soient directement noté à 0 */
		label produitfin_i="Revenus financiers imputés";

		/* Evolution des loyers réels et fictifs */
		if logt='3' then loyer=loyer*(1+&txloyhlm_derive1.);
		else if logt in ('4','5') then loyer=loyer*(1+&txloylib_derive1.);
		else if loyerfict^=. then loyerfict=loyerfict*(1+&txloylib_derive1.);

		run;
	%Mend Derive_Menage;
%Derive_Menage;

proc datasets mt=data library=work kill; run; quit;

/*les missing values sont dues aux frais et autres cases non remplies des EE de la table indivi*/


/************************************************************************/
/* 	Bonus : Vérifications 												*/
/************************************************************************/

/**Vérification cohérence des tables ménages et individuelles pour les masses agrégées sur toute la population;
proc sql; create table t as select a.*, b.wpela&anr2. from base.foyer&anr2. as a left join base.menage&anr2. as b on a.ident=b.ident; quit;
proc means sum data=t;
	var ztsaf zsalf zchof zrstf zragf zricf zrncf zalrf 
		zalvf zracf zfonf zquof zetrf zdivf zvalf zvamf;
	weight wpela&anr2;
	run;
proc means sum data=base.menage&anr2;
	var zvalm zvamm;
	weight wpela&anr2;
	run;
proc sql;
	create table rev_indivi as
	select a.*, wpela&anr2 from base.baserev as a,  base.menage&anr2 as b  
	where a.ident=b.ident;	
	quit;
proc means sum data=rev_indivi;
	var zsali&anr2 zchoi&anr2 zrsti&anr2 zragi&anr2 zrici&anr2 zrnci&anr2 zalri&anr2 zrtoi&anr2;
	weight wpela&anr2;
	run;

*Vérification cohérence des tables ménages et individuelles au niveau des montants des agrégats ERFS par ménage;
data foyer&anr2._sans_XYZ; 
	set base.foyer&anr2(keep=ident z: XYZ);
	if XYZ ne '0' then exclu=1; else exclu=0;
	run;
proc means data=foyer&anr2._sans_XYZ noprint nway;
	class ident;
	var zsalf zchof zrstf zragf zricf zrncf exclu;
	output out=rev_foy(drop=_type_ _freq_) sum=;
	run;
proc means data=base.baserev noprint nway;
	class ident;
	var zsali&anr2 zchoi&anr2 zrsti&anr2 zragi&anr2 zrici&anr2 zrnci&anr2;
	output out=rev_baserev(drop=_type_ _freq_) sum=;
	run;

* Identification des problèmes;
data pb_sal(keep=ident zsali&anr2 zsalf)
     pb_cho(keep=ident zchoi&anr2 zchof)
     pb_ret(keep=ident zrsti&anr2 zrstf)
     pb_bag(keep=ident zragi&anr2 zragf)
     pb_bic(keep=ident zrici&anr2 zricf)
     pb_bnc(keep=ident zrnci&anr2 zrncf);
	merge 	rev_foy(in=a) 
			rev_baserev(in=b);
	by ident; 
	if a & b and exclu=0;
	if abs(zsalf-zsali&anr2)>10 then output pb_sal;
	if abs(zchof-zchoi&anr2)>10 then output pb_cho;
	if abs(zrstf-zrsti&anr2)>10 then output pb_ret;
	if abs(zragf-zragi&anr2)>10 then output pb_bag;
	if abs(zricf-zrici&anr2)>10 then output pb_bic;
	if abs(zrncf-zrnci&anr2)>10 then output pb_bnc;
	run;
*les différences sont dues aux imputations non répercutées dans foyer pour les individus
avec un événement dans l'année dont toutes les déclarations n'ont pas été retrouvées;
*/



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

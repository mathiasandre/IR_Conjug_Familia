/************************************************************************************/
/*																					*/
/*									AL												*/
/*																					*/
/************************************************************************************/

/************************************************************************/
/* Simulation des aides au logement locatif								*/
/* En entrée : modele.baselog 											*/
/*			   travail.irf&anr.e&anr.									*/
/*			   modele.basersa											*/
/*			   modele.baseind											*/
/* En sortie : modele.baselog                                     		*/
/************************************************************************/
/* PLAN : 																*/
/* A. Loyer plafonné													*/
/* B. Charges (montant forfaitaire défini dans la législation)			*/
/* C. Participation personnelle (P0 et Tp = TF + TL) 					*/
/*	C.1 Participation personnelle										*/
/*	C.2 Législation avant 2001											*/
/*		C.2.a Avant 1996												*/
/*		C.2.b De 1996 à 2000											*/
/*		C.2.c Synthèse des AL pour les législations antérieures à 2001	*/
/************************************************************************/

/* Note 1: écarts par rapport à la législation
- Pas de prise en compte de la colocation (montants d'allocations plus faibles via un 
plafonnement plus strict des loyers);
- Prise en compte du zonage imparfaite;
- AL sont annualisées et non mensualisées */

/* Note 2: explication de certaines variables clées
- pac_log: nb de personnes à charge dans le logement 
- nbciv_log=1: isolé 
- nbciv_log=2: ménage */ 

/* Note 3: évolution dans le temps avec
	K: coefficient de prise en charge de la différence entre le loyer réel plafonné et 
	le loyer minimum, fonction du revenu et de la structure de la famille
	loyapl: loyer réel dans la limite d'un plafond variable en fonction de la zone et de la 
	taille de la famille
	L0: loyer minimum
	PP(participation personnelle)=P0+Tp*(Ressources-R0)
	P0: participation minimale
	Tp: taux de participation personnalisée
	R0: abattement forfaitaire qui augmente avec la taille de la famille

	- jusqu'en 1996: AL  =K*(loyapl+Ch-L0)
	   				 APL =K*(loyapl+Ch-L0)
	- de 1997 à 2001: AL  =K*(loyal+Ch-L0)
					 APL =Loyer plafonné+Ch-PP 
	- depuis 2001:   AL  =Loyer plafonné+Charges forfaitaires-PP
	pour les locataires APL, ALF et ALS partagent le même barème et sont donc traitées ensemble 
	dans Ines, sous la dénomination "AL". La situation est différente pour les accédants*/


%macro PlafondAPL (aide=,zon=);
	/* Construit pour chaque logement le plafond de loyer @plafal ou @plafapl pris en compte 
	pour une aide au logement (AL ou APL) @aide, en fonction de la zone d'habitation (@zon) :
	à l'intérieur de chaque zone, les plafonds de loyers diffèrent en fonction du statut 
	isolé/en couple et du nombre de personnes à charge */
	%if &aide.='APL' %then %do;
		if      pac_log=0 & nbciv_log=1  	then plafapl=&&aplz&zon.0i;
		else if pac_log=0 & nbciv_log=2  	then plafapl=&&aplz&zon.00;
		else if pac_log=1            		then plafapl=&&aplz&zon.01;
		else if pac_log>1            		then plafapl=&&aplz&zon.01+&&aplz&zon.11*(pac_log-1);
		%end; 
	%if &aide.='AL' %then %do; /* ne sert que pour anleg<2001*/
		if 		nal=1.2 then plafal=&&alz&zon.0i;
		else if nal=1.5 then plafal=&&alz&zon.00;
		else if nal=2.3 then plafal=&&alz&zon.01;
		else if nal=3   then plafal=&&alz&zon.02;
		else if nal=3.7 then plafal=&&alz&zon.03;
		else if nal=4.3 then plafal=&&alz&zon.04;
		else if 4.3<nal then plafal=&&alz&zon.05+(&&alz&zon.11*(pac_log-5))*(pac_log>5);
		%end;
	%mend PlafondAPL;


%Macro AllocationsLogement;
	proc sort data=modele.baselog; by ident_log;run;
	data modele.baselog;
		set modele.baselog; 

		/*********************/
		/* A. Loyer plafonné */
		/*********************/

		/*zone du logement*/
		if 		reg='11'& TUU2010^='0' then zone='1';/*Paris, unités urbaines d'Ile-de-France*/
		else if reg='11' 			then zone='2';/*reste IDF*/
		else if TUU2010 in ('6','7') 	then zone='2';/*aires urbaines + 100 000 habitants*/
		else 							 zone='3';

		/*loyer plafonné (en fonction de la zone et de la composition familiale*/
		if      zone='1' 	then do; %PlafondAPL(aide='APL',zon=1); plaf1=&plaf1_z1*plafapl ; plaf2=&plaf2_z1*plafapl ; end;
		else if zone='2' 	then do; %PlafondAPL(aide='APL',zon=2); plaf1=&plaf1_z2*plafapl ; plaf2=&plaf2_z2*plafapl ; end;
		else if zone='3' 	then do; %PlafondAPL(aide='APL',zon=3); plaf1=&plaf1_z3*plafapl ; plaf2=&plaf2_z3*plafapl ; end;

		if 	loyer_identlog>0 then loyapl=min(loyer_identlog,plafapl);
		else loyapl=plafapl;

		/* Type aide */

		/***************************************************************/
		/* B. Charges (montant forfaitaire défini dans la législation) */
		/***************************************************************/
		ch=&APL241.+&APL242.*pac_log;

		/***************************************************************/
		/* C. Participation personnelle (P0 et Tp = TF + TL)           */
		/***************************************************************/

		/************************/
		/* C.1 A partir de 2001 */
		/************************/

		%if &anleg.>=2001 %then %do; 

			/*calcul de R0*/
			if      pac_log=0 & nbciv_log=1 then r0=&APL281.;
			else if pac_log=0 & nbciv_log=2 then r0=&APL282.;
			else if pac_log=1 				then r0=&APL283.;
			else if pac_log=2 				then r0=&APL284.;
			else if pac_log=3 				then r0=&APL285.;
			else if pac_log=4 				then r0=&APL286.;
			else if pac_log=5 				then r0=&APL287.;
			else if pac_log=6 				then r0=&APL288.;
			else if pac_log>=7 				then r0=&APL288.+(pac_log-6)*&APL289.;

			/*P0 : Participation minimale*/
			P0=max(&apl272.,(loyapl+ch)*&APL271.);

			/*TF : Taux minimum en fonction de la taille du ménage*/
			if      pac_log=0 & nbciv_log=1 then tf=&APL261.;
			else if pac_log=0 & nbciv_log=2 then tf=&APL262.;
			else if pac_log=1 				then tf=&APL263.;
			else if pac_log=2 				then tf=&APL264.;
			else if pac_log=3 				then tf=&APL265.;
			else if pac_log=4 				then tf=&APL266.;
			else if pac_log>=5 				then tf=&APL266.-(pac_log-4)*&APL269.;

			/*TL : Taux complémentaire en fonction du loyer*/
			if      pac_log=0 & nbciv_log=1 then plafi=&aplz20i.;
			else if pac_log=0 & nbciv_log=2 then plafi=&aplz200.;
			else if pac_log=1 				then plafi=&aplz201.;
			else if pac_log>1 				then plafi=&aplz201.+&aplz211.*(pac_log-1);

			RL=loyapl/plafi;
			if 0<=RL<&APL251. 				then TL=0;
			else if &APL251.<=RL<&APL252. 	then TL=&APL253.*(RL-&APL251.);
			else if &APL252.<=RL 			then TL=&APL254.*(RL-&APL252.)+ &APL253.*(&APL252.-&APL251.);

			/*Taux de participation personnelle*/
			Tp=sum(0,TF,TL);

			/* Application de la RLS à partir de janvier 2018 */ 
			%if &anleg.>=2018 %then %do; 
			/* Eligibilité Remise de Loyer => Calcul des plafonds */
				if zone='1' then do;					
					if nbciv_log=1 AND pac_log=0 then P_ERL= &RLS_Z1_PL_I. ;		/* Personne seule */		
					else if nbciv_log=2 AND pac_log =0 then P_ERL= &RLS_Z1_PL_C. ;		/* Couple sans personne à charge */		
					else if  pac_log=1  then P_ERL= &RLS_Z1_PL_1P. ;					/* une personne à charge */			
					else if  pac_log = 2  then P_ERL= &RLS_Z1_PL_2P. ;					/* 2 personnes à charge */			
					else if  pac_log = 3  then P_ERL= &RLS_Z1_PL_3P. ;					/* 3 personnes à charge */
					else if  pac_log = 4  then P_ERL= &RLS_Z1_PL_4P. ;					/* 4 personnes à charge */
					else if  pac_log = 5  then P_ERL= &RLS_Z1_PL_5P. ;					/* 5 personnes à charge */
					else if  pac_log = 6  then P_ERL= &RLS_Z1_PL_6P. ;					/* 6 personnes à charge */
					else if  pac_log > 6  then P_ERL= &RLS_Z1_PL_6P. + (pac_log-6)* &RLS_Z1_PL_PP. ;	/* > 6 personnes à charge */				
				end;					
				if zone='2' then do;					
					if nbciv_log=1 AND pac_log=0 then P_ERL= &RLS_Z2_PL_I. ;		/* Personne seule */		
					else if nbciv_log=2 AND pac_log =0 then P_ERL= &RLS_Z2_PL_C. ;		/* Couple sans personne à charge */		
					else if  pac_log=1  then P_ERL= &RLS_Z2_PL_1P. ;					/* une personne à charge */			
					else if  pac_log = 2  then P_ERL= &RLS_Z2_PL_2P. ;					/* 2 personnes à charge */			
					else if  pac_log = 3  then P_ERL= &RLS_Z2_PL_3P. ;					/* 3 personnes à charge */
					else if  pac_log = 4  then P_ERL= &RLS_Z2_PL_4P. ;					/* 4 personnes à charge */
					else if  pac_log = 5  then P_ERL= &RLS_Z2_PL_5P. ;					/* 5 personnes à charge */
					else if  pac_log = 6  then P_ERL= &RLS_Z2_PL_6P. ;					/* 6 personnes à charge */
					else if  pac_log > 6  then P_ERL= &RLS_Z2_PL_6P. + (pac_log-6)* &RLS_Z2_PL_PP. ;	/* > 6 personnes à charge */			
				end;			
				if zone='3' then do;					
					if nbciv_log=1 AND pac_log=0 then P_ERL= &RLS_Z3_PL_I. ;		/* Personne seule */		
					else if nbciv_log=2 AND pac_log =0 then P_ERL= &RLS_Z3_PL_C. ;		/* Couple sans personne à charge */		
					else if  pac_log=1  then P_ERL= &RLS_Z3_PL_1P. ;					/* une personne à charge */			
					else if  pac_log = 2  then P_ERL= &RLS_Z3_PL_2P. ;					/* 2 personnes à charge */			
					else if  pac_log = 3  then P_ERL= &RLS_Z3_PL_3P. ;					/* 3 personnes à charge */
					else if  pac_log = 4  then P_ERL= &RLS_Z3_PL_4P. ;					/* 4 personnes à charge */
					else if  pac_log = 5  then P_ERL= &RLS_Z3_PL_5P. ;					/* 5 personnes à charge */
					else if  pac_log = 6  then P_ERL= &RLS_Z3_PL_6P. ;					/* 6 personnes à charge */
					else if  pac_log > 6  then P_ERL= &RLS_Z3_PL_6P. + (pac_log-6)* &RLS_Z3_PL_PP. ;	/* > 6 personnes à charge */				
				end;
			%end;
			/*Montant de la participation personnelle*/

			/* Note pour comprendre la démarche ci-dessous : 
			Abattement et neutralisation de ressources en cas de chômage 
				- Dans la législation (2013), des abattements de ressources sont prévus pour les 
				personnes au chômage indemnisé (30%) ou non indemnisé (100%). 
			Prise en compte dans Ines et biais engendré 
				- Ces abattements sont intégrés dans les ressources calculées dans ress_log. 
				On travaille cependant sur une base annuelle, et on considère que l'abattement 
				s'applique à l'ensemble des ressources annuelles dès lors que la personne a été 
				au chômage un mois dans l'année. Alors que, dans la législation, l'abattement n'est 
				effectif que durant les périodes de chômage des allocataires. Appliquer tel quel 
				les abattements sur l'ensemble des ressources annuelles conduirait ainsi à minorer 
				les ressources des allocataires, et donc à verser trop d'AL. 
			"Patch" pour éviter le biais 
				Pour éviter ce biais, il a été décidé de calculer 4 bases ressources : 
					- ress_log1 : sans prise en compte des abattements 
					- ress_log2 : avec prise en compte des abattements pour la personne de référence 
					- ress_log3 : avec prise en compte des abattements pour le conjoint 
					- ress_log4 : avec prise en compte des abattements pour la personne de réf. et son conjoint 
				On calcule 4 montants d'allocations logement en fonction de chacune des bases 
				ressources. On fait ensuite la moyenne pondérée de ces montants, en tenant compte 
				du nb de mois que le foyer a passé dans chacune des situations (sans chômage, 
				chômage pers. référence, chômage conjoint, chômage des deux)
			On fait un "patch" similaire" en cas de neutralisation pour RSA : 2 BR avec ou sans abattement et montants d'allocations logement selon ces 2 BR, 
			pondérées ensuite par le nombre de trimestres au RSA ou non. 
			*/ 

			array PP(5) 		PP1-PP5;
			array ress_log(5) 	ress_log1-ress_log5;
			array ALm(5) 		ALm1-ALm5;
			array ALm_hand(5) 	ALm_hand1-ALm_hand5;
			array TOP_ERL(5) 	TOP_ERL1-TOP_ERL5;
			array Remise(5) 	Remise1-Remise5;
			array aide_brute(5) 		aide_brute1-aide_brute5;
			array aide_brute_hand(5) 	aide_brute_hand1-aide_brute_hand5;
			array Loyer_remise(5) 		Loyer_remise1-Loyer_remise5;

			do i=1 to 5;
				ress_log(i)=(1+floor(ress_log(i)/100))*100; /* on arrondit les ressources au multiple de 100 supérieur (législation) */
				PP(i)=sum(0,P0,Tp*max(0,ress_log(i)-r0)); 
				/* planchers de ressources : etudiants. Pour le moment, on ne gère pas bien les couples d'étudiants et les colocataires étudiants*/
				/*if stud>1 and ress_log(i)<&APL007 then PP(i)=P0+Tp*max(0,&APL007-r0);*/

				/*** Calcul de l'allocation ***/
				ALm(i)=(loyapl+ch)-PP(i);

				ALm_hand(i)=ALm(i); /*servira au calcul des AL pour les bénéficiaires de l'AAH ou de l'AEEH pour lesquels le calcul des AL est inchangé */
				/* Depuis 2016 : dégressivité de l'AL si le loyer dépasse un 1er plafond, et suppression de l'AL au-delà d'un 2eme plafond */
				/* La diminution du montant d'AL est proportionnelle au dépassement du seuil de dégressivité de sorte que ce montant soit nul au 2e plafond */

					%if &anleg.>=2016 %then %do;
						ALm(i)=(ALm(i)-ALm(i)*(loyer_identlog-plaf1)/(plaf2-plaf1)*(loyer_identlog>plaf1))*(loyer_identlog<=plaf2) ;
					%end;

					%if &anleg.>=2017 %then %do; /* ECRETEMENT 5€  ---- REFORME ACTEE POUR OCTOBRE 2017 */
						ALm(i) = sum(ALm(i),-&ecret.);  
						ALm_hand(i)= sum(ALm_hand(i),-&ecret.);
					%end;

					%if &anleg.>=2018 %then %do; /* Application de la RLS à partir de janvier 2018 */
					Rls_appliquee = 0;

					/* Eligibilité Remise de Loyer */
					TOP_ERL(i)=((ress_log(i))<=(P_ERL)); /* ici sont éligibles en termes de revenu à la RLS*/
					Remise(i)=0;		
					/* Calcul du coeff LP/Lpzone1 isolé  - Ce coefficient vis ensuite à calculer une RLS proportionnelle au loyer plafond*/
					Ratio_Lp_Lp1iso = plafapl/&APLZ10i.;
					/* Remise de loyer :il s'agit de la baisse de loyer - La baisse d'AL est calculée plus tard*/
					if TOP_ERL(i)=1 and logt='3' /*and alloc='apl'*/ then do ; /*Champ remise*/
					/*Dans Ines le champ APL n'est pas correct (cf. hypothèse permettant de distinguer ALF als et APL)
					En ciblant sur les APL ET HLM on a peu de foyer par rapport aux fichiers CNAF ce qui conduit à sousestimer l'effet RLS
					Dans les fichiers CNAF, on constate que peu de foyer HLM sont en als ou en alf. 
					Dans Ines, On applique donc la mesure RLS à l'ensemble des HLM (logt='3'), peu importe le type d'aide*/
						remise(i)=&RLS_Z1_M_I.*Ratio_Lp_Lp1iso;		
						Rls_appliquee = 1;
						IF remise(i) = 0 and ALm(i)=<&RLS_Min. THEN ALm(i) = 0 ;
						else IF remise(i) > 0 and ALm(i) =<&RLS_Min. THEN ALm(i) = 0 ;
						else ALm(i) = ALm(i);

						IF remise(i) = 0 and ALm_hand(i)<&RLS_Min. THEN ALm_hand(i) = 0 ;
						else IF remise(i) > 0 and ALm_hand(i) <&RLS_Min. THEN ALm_hand(i) = 0 ;
						else ALm_hand(i) = ALm_hand(i);

						/* Aide brute */
						aide_brute(i) = ALm(i);
						aide_brute_hand(i) = ALm_hand(i);

						/* Aide après application de la RLS */
						ALm(i)=max(0,aide_brute(i)-&RLS_Taux.*(remise(i)));
						ALm_hand(i)=max(0,aide_brute_hand(i)-&RLS_Taux.*(remise(i)));

						/* Aide après application de la CRDS et troncature */
						/* ALm(i) =floor(ALm(i)*0.995);*/
						ALm(i) =floor(ALm(i)); /* sans deduction en compte de la CRDS */
						ALm_hand(i) =floor(ALm_hand(i)); /* sans deduction en compte de la CRDS */
						/* Loyer après remise*/
						Loyer_remise(i)=sum(loyer_identlog,-remise(i));
						end;
					else do; /* application du seuil de versement quand aucune remise n'est appliquée */
						if ALm(i)<&L008. then ALm(i)=0; /* seuil de non versement */
						if ALm_hand(i)<&L008. then ALm_hand(i)=0; /* seuil de non versement */
						Loyer_remise(i)=sum(loyer_identlog);
						end;
					%end;
				
					%if &anleg.<2018 %then %do; 
					if ALm(i)<&L008. then ALm(i)=0; /* seuil de non versement */
					if ALm_hand(i)<&L008. then ALm_hand(i)=0; /* seuil de non versement */
					%end ;

			end;

			/* CALCUL DE L'AIDE AU LOGEMENT ANNUELLE TOTALE */

			/* Abattement au titre du RSA */
			/*  w1 : nb de trimestre sans RSA 
				w5 : nb de trimestre avec RSA */
			if w5>0 then do ; /* on ne veut calculer cette moyenne pondérée que pour les bénéficiaires de RSA */
				if &anleg.<=2015 then AL=w1*ALm1+w5*ALm5 ; 
				if &anleg.<=2015 then AL_hand=w1*ALm_hand1+w5*ALm_hand5;

				if &anleg.>=2016 then AL=w1*INT(ALm1)+w5*INT(ALm5); /*Depuis 2016 : montant mensuel arrondi à l'euro inférieur*/
				if &anleg.>=2016 then AL_hand=w1*INT(ALm_hand1)+w5*INT(ALm_hand5);
				
				if &anleg.>=2018 then do;
					remise_an=w1*remise1+w5*remise5; /*Depuis 2018 : Loyer diminué de la remise*/
					Loyer_remise_an = (loyer_identlog - (remise_an/12));
					end;
				end;
			/* Abattement au titre du chômage */
			/*	p1:nb de mois sans chômage 
				p2:nb de mois avec chômage de la pers. de référence 
				p3:nb de mois avec chômage du conjoint  
				p4:nb de mois avec chômage des deux; */
			else do ;
				if &anleg.<=2015 then AL=p1*ALm1+p2*ALm2+p3*ALm3+p4*ALm4;
				if &anleg.<=2015 then AL_hand=p1*ALm_hand1+p2*ALm_hand2+p3*ALm_hand3+p4*ALm_hand4;

				if &anleg.>=2016 then AL=p1*INT(ALm1)+p2*INT(ALm2)+p3*INT(ALm3)+p4*INT(ALm4); /*Depuis 2016 : montant mensuel arrondi à l'euro inférieur*/
				if &anleg.>=2016 then AL_hand=p1*INT(ALm_hand1)+p2*INT(ALm_hand2)+p3*INT(ALm_hand3)+p4*INT(ALm_hand4);
				
				if &anleg.>=2018 then do;
					remise_an=p1*remise1+p2*remise2+p3*remise3+p4*remise4; /*Depuis 2018 : Loyer diminué de la remise*/
					Loyer_remise_an = (loyer_identlog - (remise_an/12));
					end;
				end;

			if sum(0,pac_log,nbciv_log)=0 then AL=0; /*Pas d'apl si on manque d'informations sur la composition du logement */
			if sum(0,pac_log,nbciv_log)=0 then AL_hand=0; /*Pas d'apl si on manque d'informations sur la composition du logement */
			drop i ALm_hand1 ALm_hand2 ALm_hand3 ALm_hand4 ALm_hand5 ;	

		%end;

		/**********************/
		/* C.2 Avant 2001     */
		/**********************/

		/************************/
		/* C.2.1 Avant 1996     */
		/************************/

		%if &anleg.<=1996 %then %do;	
			/* calcul du nombre de parts             */
		    if      pac_log=0 & nbciv_log=1 then do; napl=1.4;	nal=1.2; end;
		    else if pac_log=0 & nbciv_log=2 then do; napl=1.8;	nal=1.5; end;
		    else if pac_log=1               then do; napl=2.5;	nal=2.3; end;
		    else if pac_log=2               then do; napl=3;	nal=napl; end;
		    else if pac_log=3               then do; napl=3.7;	nal=napl; end;
		    else if pac_log=4               then do; napl=4.3;	nal=napl; end;
		    else if pac_log>=5              then do; napl=4.3+0.5*(pac_log-4);	nal=napl; end;

			/*****/
			/*APL*/
			/*****/

			/* calcul du loyer minimum   ( LO )       */
			%let APL121=%sysevalf(&APL101.*&APL111.);                     /* element tranche 2 */
			%let APL122=%sysevalf(&APL121.+(&APL102.-&APL101.)*&APL112.); /* element tranche 3 */
			%let APL123=%sysevalf(&APL122.+(&APL103.-&APL102.)*&APL113.); /* element tranche 4 */
			%let APL124=%sysevalf(&APL123.+(&APL104.-&APL103.)*&APL114.); /* element tranche 5 */
			%let APL125=%sysevalf(&APL124.+(&APL105.-&APL104.)*&APL115.); /* element tranche 6 */

			/* On travaille sans les abattements pour simplifier*/
			/* Les étudiants ont un plancher de ressources*/
			ress_apl= max(ress_log1,(stud=1 & ress_log1<&APL007.)*&APL007.,0);

			if      ress_apl<=&APL101.*napl  then L0=ress_apl*&APL111.;
		    else if ress_apl<=&APL102.*napl  then L0=&APL121.*napl+(ress_apl-(&APL101.*napl))*&APL112.;
		    else if ress_apl<=&APL103.*napl  then L0=&APL122.*napl+(ress_apl-(&APL102.*napl))*&APL113.;
		    else if ress_apl<=&APL104.*napl  then L0=&APL123.*napl+(ress_apl-(&APL103.*napl))*&APL114.;
		    else if ress_apl<=&APL105.*napl  then L0=&APL124.*napl+(ress_apl-(&APL104.*napl))*&APL115.;
		    else if &APL105.*napl<ress_apl   then L0=&APL125.*napl+(ress_apl-(&APL105.*napl))*&APL116.;
		    L0=int(L0);
		    L0=L0+napl*&APL130.;

			/* calcul du coefficient Kapl de prise en charge */
			%if &anleg.<1998 %then %do;
		    	if napl>0 then Kapl=&APL151.-((ress_apl-&APL152.*napl)/(&APL153.*napl));
				%end;
			%else %if &anleg.>=1998 %then %do;
				Kapl=1;
				%end;

			/* Calcul du montant d'apl*/
			if Kapl<0 or 12*(loyapl+ch)-L0<0 	then apl=0;
	           else apl=Kapl*(12*(loyapl+ch)-L0);
			if 12*(loyapl+ch)-apl < 12*&APL009. then apl=12*(loyapl+ch)-&APL009.*12;
			if apl<12*&L008. 				then apl=0;
			if sum(0,pac_log,nbciv_log)>0 then APL=0; /*Pas d'apl pour les logements bizarres, soit 51 logements sur l'ERFS 2009*/
			%end;

		/************************/
		/* C.2.2 De 1996 à 2000 */
		/************************/

		%else %if 1996<&anleg. and &anleg.<= 2000 %then %do;	

			/* On travaille sans les abattements pour simplifier*/
			/* Les étudiants ont un plancher de ressources*/
			ress_apl= max(ress_log1,(stud=1 & ress_log1<&APL007.)*&APL007.,0);

			/* Participation personnelle (Pp=Tp*R/10000 et Tp = TF + TL + TR) */
			/*TF : Taux minimum en fonction de la taille du ménage*/
			if      pac_log=0 & nbciv_log=1 then tf=&APL261.;
			else if pac_log=0 & nbciv_log=2 then tf=&APL262.;
			else if pac_log=1 				then tf=&APL263.;
			else if pac_log=2 				then tf=&APL264.;
			else if pac_log=3 				then tf=&APL265.;
			else if pac_log=4 				then tf=&APL266.;
			else if pac_log>=5 				then tf=&APL266.-(pac_log-4)*&APL269.;

			/*TL : Taux complémentaire en fonction du loyer*/
			if      pac_log=0 & nbciv_log=1 then plafi=&aplz20i.;
			else if pac_log=0 & nbciv_log=2 then plafi=&aplz200.;
			else if pac_log=1 				then plafi=&aplz201.;
			else if pac_log>1 				then plafi=&aplz201.+&aplz211.*(pac_log-1);

			RL=loyapl/plafi;
			if 0<=RL<&APL251. 				then TL=0;
			else if &APL251.<=RL<&APL252. 	then TL=&APL253.*(RL-&APL251.) ;
			else if &APL252.<=RL 			then TL=&APL254.*(RL-&APL252.) 
													+ &APL253.*(&APL252.-&APL251.);
			/*TR : Taux complémentaire en fonction des revenus*/
			%macro calc_TR(rev,ximpot);
				&ximpot. = 0;
				%do i = 1 %to 6; 
					%let j = %eval(&i+1);
					&ximpot. = &ximpot. + &&trtx&i.*max(min(&rev.-&&trplaf&i,&&trplaf&j-&&trplaf&i),0);
					%end; 
				&ximpot. = &ximpot. + &trtx7.*max((&rev.-&&trplaf7.),0);
				%mend calc_TR;

			rna=100*floor(ress_apl/100)+100;
			if (pac_log=0 and nbciv_log=1) then do; 
				%let trplaf1=%sysevalf(&trplaf1a.); end;
				else do ; %let trplaf1=%sysevalf(&trplaf1b.); 
				end;
			%calc_TR(rna,TR); 

			/* TP : Taux de participation personnelle */
			TP = sum(0,TF,TR,TL);

			/* Pp : Montant de la participation personnelle */
			PPT=max(TP/10000*ress_apl,max(&apl272.,(loyapl+ch)*&APL271.));

			APL=12*((loyapl+ch)-PPT);
			if apl<12*&L008. 	then apl=0;
			%end;

	   	/*****/
		/*AL */
		/*****/
		%if &anleg.<2001 %then %do;     
		
			/* calcul du plafond  des loyers mensuels pour les AL*/
		    if zone='1' then do;%PlafondAPL(aide='AL',zon=1);end;
		    if zone='2' then do;%PlafondAPL(aide='AL',zon=2);end;
		    if zone='3' then do;%PlafondAPL(aide='AL',zon=3);end;
		    if loyer_identlog>0 then loyal=min(loyer_identlog,plafal);
			else 			loyal=plafal;
		
			/* calcul du loyer minimum (LO)       */
			%let AL121=%sysevalf((&AL102.-&AL101.)*&AL111.);      		/* element tranche 3 */
			%let AL122=%sysevalf(&AL121.+(&AL103.-&AL102.)*&AL112.); 	/* element tranche 4 */
			%let AL123=%sysevalf(&AL122.+(&AL104.-&AL103.)*&AL113.); 	/* element tranche 5 */

			/* On travaille sans les abattements pour simplifier*/
			/* Les étudiants ont un plancher de ressources*/
			ress_al= max(ress_log1,(stud=1 & ress_log1<&AL007.)*&AL007.);

	    	if      ress_al<=&AL101.*nal then loal=0;
	   		else if ress_al<=&AL102.*nal then loal=(ress_al-(&AL101.*nal))*&AL111.;
		    else if ress_al<=&AL103.*nal then loal=&AL121.*nal+(ress_al-(&AL102.*nal))*&AL112.;
		    else if ress_al<=&AL104.*nal then loal=&AL122.*nal+(ress_al-(&AL103.*nal))*&AL113.;
		    else if &AL104.*nal<ress_al  then loal=&AL123.*nal+(ress_al-(&AL104.*nal))*&AL114.;
		    loal=int(loal);
		    loal=loal+&AL130.;

			/* calcul du coefficient K de prise en charge        */
			if nal>0 then Kal=&AL151.-(ress_al/(&AL152.*nal));


			/* Calcul du montant d'AL */
			if kal<0 or 12*(loyal+ch)-loal<0 then AL=0;
			else                                  AL=kal*(12*(loyal+ch)-loal);
			if 12*(loyal+ch)-al < 12*&AL009. 	then  AL=12*(loyal+ch)-&AL009.*12;
			if AL<12*&L008. then AL=0;

			drop ress_al ress_apl;
			%end;
		run;

	/******************************************************************/
	/* C.2.c Synthèse des AL pour les législations antérieures à 2001 */
	/******************************************************************/
	proc sort data=modele.baseind (keep=ident aah aspa handicap_e) out=baseind; by ident; run;
	data droit_als;
		/* Les ayant-droits à l'ALS avant 1993 sont : les plus de 65 ans ou +60 avec infirmité
		les invalides, les jeunes travailleurs de moins de 25 ans, les rmistes*/
		merge 	travail.irf&anr.e&anr.	(keep=ident naia lprm ADFDAP acteu6) 
				modele.baselog			(keep=ident reg TUU2010 logt)
				modele.basersa			(keep=ident m_rsa_socle: in=a) 
				baseind					(in=b) ; 
		by ident ;
		if sum(of m_rsa_socle_th1-m_rsa_socle_th4,0)>0;
		retain droit 0;
		if first.ident then droit=0;
		if lprm in ('1','2') then do;
			if &anref.-input(naia,4.)>=65 					then droit=1;
			if &anref.-input(naia,4.)>=60 & (aspa>0) 		then droit=1;
			if ADFDAP ne '' and acteu6 in ('3','4') then do; 
				if &anref.-input(ADFDAP,4.)>5  				then droit=1;
				end;
			if &anref.-input(naia,4.)<25 & acteu6 in ('1') 	then droit=1; 
			%if &anleg.>1991 %then %do;
				if TUU2010 in ('6','7') 						then droit=1;
				%end; 
			%if &anleg.>1990 %then %do;
				if reg='11' 								then droit=1;
				%end;
			end;
		if a ! b then droit=1;
		if last.ident then output;
		run;

	data modele.baselog (drop=droit); 
		merge 	modele.baselog(in=a) 
				droit_als (keep= ident logt droit); 
		by ident;
		if a;
		%if &anleg.>2001 %then %do;
			alloc='apl';
			%end;
		%else %do;
			alloc='';
			%end;
		/* l'ordre est important entre APL, ALF et ALS */
		if pac_log=0 & droit=1 	then alloc='als'; 
		if pac_log >0 			then alloc='alf'; /*il manque les jeunes couples...*/
		%if &anleg.<=2001 %then %do;
			if logt ='3' then do;
				alloc='apl';
				al=apl;
				end;
			%end;
		if alloc='' 			then al=0;
		label alloc	= "Type d'allocation logement";
		run;

	/* les bénéficiaires AAH/AEEH ne sont pas concernés par la dégressivité de 2016-->calcul de l'AL est identique aux anleg précédentes */

		%if &anleg.=2016 %then %do;

			data al_handicap ;
			merge       modele.baselog			(keep=ident AL_hand)
						baseind					(keep=ident aah handicap_e) ; 
				by ident ;
				if aah>0 OR handicap_e ne ''; aah_aeeh=1 ;
			run;

			data modele.baselog(drop=aah_aeeh AL_hand) ; 
				merge 	modele.baselog(in=a) 
						al_handicap(keep=ident aah_aeeh); 
				by ident;
				if a;
				if aah_aeeh=1 then AL=AL_hand; 
				if aah_aeeh ne 1 then AL=(AL_hand+AL)/2 ;/*nouveau mode de calcul à partir de juillet 2016(50% ancien montant + 50% nouveau montant)*/	
			run;
			proc sort data=modele.baselog nodupkey; by ident_log; run;
		%end;

		%if &anleg.>=2017 %then %do; /*(Nouveau mode de calcul sauf pour les bénéficiaires AAH/AEEH)*/

			data al_handicap ;
			merge       modele.baselog			(keep=ident AL_hand)
						baseind					(keep=ident aah handicap_e) ; 
				by ident ;
				if aah>0 OR handicap_e ne ''; aah_aeeh=1 ;
			run;

			data modele.baselog(drop=aah_aeeh AL_hand) ; 
				merge 	modele.baselog(in=a) 
						al_handicap(keep=ident aah_aeeh); 
				by ident;
				if a;
				if aah_aeeh=1 then AL=AL_hand; 
			run;
			proc sort data=modele.baselog nodupkey; by ident_log; run;
		%end;

	%Mend AllocationsLogement;

%AllocationsLogement;

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

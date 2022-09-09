/************************************************************************************/
/*																					*/
/*								PAJE												*/
/*																					*/
/************************************************************************************/

/* Modélisation de l'allocation de base et de la prime à la naissance ou à l'adoption
de la Prestation d'Accueil du Jeune Enfant
	
 En entrée : 	modele.basefam													
 En sortie : 	modele.basefam                                     

Plan
A. Plafond de ressources de la Paje 
B. Montant mensuel de l'allocation de base et de la prime à la naissance de la Paje
	B.1 Création des variables nécessaires
	B.2 Prime à la naissance de la Paje
	B.3 Allocation de base de la Paje 
	B.4 Montant total de la Paje (base+prime à la naissance)
	B.5 Nombre de mois de bénéfices de l'allocation de base de la Paje

Notes
1. La paje se décompose en plusieurs allocations : 
- l'allocation de base
- la prime à la naissance/adoption
- le complement de libre choix d'activité (CLCA), simulé dans un programme dédié
- le complèment mode de garde (CMG), simulé dans un programme dédié
 
2. Attention, les montants de la PAJE sont calculés avant CRDS. Il faut la déduire pour arriver au revenu disponible

3. Modulation de l'allocation de base pour les enfants nés à partir du 01/04/2014 :
La nouvelle variable naissance_apres_avril créée dans travail_clca.sas repère les enfants concernés par la réforme,
ils sont un peu plus nombreux chaque année, jusqu'en avril 2017 ou tous le seront. 
*/

/************************************************/
/* A. Plafond de ressources de la Paje          */
/************************************************/

/* Dans la législation le plafond de référence est donné pour un enfant, mais la valorisation des enfants à charge
s'exprime en pourcentage d'un plafond théorique pour 0 enfant. Il faut donc au préalable retrouver ce plafond
par calcul en divisant le plafond de référence pour un enfant par la valeur du 1er enfant à charge */
/* Note: les enfants à naître sont comptés à charge */


%macro Calcul_Paje;
	data tot;
		set	modele.basefam;
		/*Nb d'enfants de 0 à 3 ans*/
		%nb_enf(je,0,&age_pajebase.,age_enf);
		/*Nb d'enfants de 0 à 19 ans s'il y a au moins 1 enfant de moins de 3 ans*/
		if je>0;
		%nb_enf(e_c,0,&age_pf.,age_enf); 

		/*Plafond pour couple mono-actif avec 1 enfant*/
		if sum(e_c,enf_1)<=1 then pl=&paje002.;
		/*Plafond pour couple mono-actif avec plus de 1 enfant*/
		else if sum(e_c,enf_1)>1 then pl=&paje002./(1+&paje_majo_pac12.)*
										 (1+&paje_majo_pac12.*min(2,sum(e_c,enf_1)) 
										 +&paje_majo_pac3.*max(0,sum(e_c,enf_1)-2));
		/*Plafond pour couple bi-actif ou parent seul*/
		if men_paje='H' then pl=pl+&paje001.;
		
		/* On calcule ici les plafonds taux plein et taux partiel qui ne serviront que pour anleg>=2014 (voir note 3 en haut du programme) */
		/*Plafonds pour couple mono-actif avec 1 enfant*/
		if sum(e_c,enf_1)<=1 then do;
			pl_txplein=&paje_plaf.;
			pl_txpartiel=&paje_plaf_part.;
			end;
		/*Plafonds pour couple mono-actif avec plus de 1 enfant*/
		else if sum(e_c,enf_1)>1 then do;
			pl_txplein=&paje_plaf./(1+&majo_pac.)*(1+&majo_pac.*sum(e_c,enf_1));
			pl_txpartiel=&paje_plaf_part./(1+&majo_pac.)*(1+&majo_pac.*sum(e_c,enf_1));
			end;
		/*Plafonds pour couple bi-actif ou parent seul : on ne l'écrit plus en absolu mais en coefficient pour
			avoir le même paramètre pour le taux plein et le taux partiel*/
		if men_paje='H' then do;
			pl_txplein=pl_txplein + &majo_biact.;
			pl_txpartiel=pl_txpartiel + &majo_biact_part.;
			end;
		
		/***************************************************************************************/
		/* B. Montant mensuel de l'allocation de base et de la prime à la naissance de la Paje */
		/***************************************************************************************/
		/* Note: si naissances multiples, l'allocataire cumule plusieurs allocations de base */
		/* Hypothèse : si 2 enfants ont le même age, on les considère comme jumeaux */

		/******************************************/
		/* B.1 Création des variables nécessaires */
		/******************************************/
		%if &anleg. <= 2013 %then %do ; /* Jusqu'en 2013, l'allocation de base de la PAJE est exprimée en fonction de la BMAF */
			mpaje=&bmaf.*&paje_t.;
			%end ;
		%if &anleg. = 2014 %then %do ; /* A partir du 1er avril 2014, l'AB de la PAJE est gelée et surtout déconnectée de la BMAF */ 
			mpaje=((3*&bmaf_n.*&paje_t.)+(9*&paje_m.))/12; /* pour les 3 premiers mois de l'année, l'AB est encore exprimée en fonction de la BMAF (valeur de celle-ci au 1er janvier).
			On fait une moyenne sur l'année, même si en pratique le montant mensuel n'est pas modifié à partir d'avril (malgré la déconnection de la Bmaf */
			mpaje_partiel=&paje_m_partiel.; /* Pas de moyenne sur l'année car le montant partiel ne concerne que les enfants nés à partir du 1er avril */
			%end ;
		%if &anleg. >= 2015 %then %do ; 
			mpaje=&paje_m.; 
			mpaje_partiel=&paje_m_partiel.;
			%end ;
		%Init_Valeur(paje_1 paje0 paje1 paje2 paje3 paje03);
		%Init_Valeur(droit_AB,valeur='aucun');
		%nb_enf(enf00,0,0,age_enf);
		%nb_enf(enf01,1,1,age_enf);
		%nb_enf(enf02,2,2,age_enf);
		%nb_enf(enf03,3,3,age_enf);

		/******************************************/
		/* B.2 Prime à la naissance de la Paje    */
		/******************************************/
		Cond_PrimNais=res_paje<=pl or (&anleg.<1996);
		if Cond_PrimNais then do;	
			/*Note: Jusqu'en 2014, cette prime est versée en une seule fois au 7ème mois de grossesse. 
			A partir du 1er janvier 2015 (grossesses déclarées à la CAF à partir de cette date), la prime est versée "avant la fin du dernier jour du second mois" après la naissance de l'enfant. 
		    Et pour les familles bénéficiaires de l'AB, la prime est versée en même temps soit le 1er jour du mois civil suivant la naissance. 
			On suppose donc qu'avec le changement de législation, la prime est versée au 2e mois de l'enfant */
			paje_nais=0;
			%if &anleg. <= 2014 %then %do ;
				if enf_1>0 then paje_nais=&paje_prinais.*mpaje*enf_1;
				/* Pour enfants nés pendant l'année d'intéret après février*/
				if enf00>0 & mois00>2 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;
				%end ;
			%if &anleg. = 2015 %then %do ; /* Ne s'applique qu'aux grossesses déclarées à la CAF à partir du 1er janvier 2015, que l'on suppose à 3 mois. 
			       Concerne donc les naissances à partir du mois de juillet 2015 */
				/* Naissances entre mars et juin : prime versée au 7e mois de grossesse donc entre janvier et avril. 	
				   Naissances entre juillet et octobre : prime versée au 2e mois de l'enfant donc entre septembre et décembre */
				if enf00>0 & mois00>2 & mois00<11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;
				%end ;
			%if &anleg. >=2016 %then %do ; /* Prime au 2e mois de l'enfant */
				/* Naissances en novembre et décembre de l'année précédente */
				if enf01>0 & mois01=11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf01; 
				if enf01>0 & mois01=12 then paje_nais=paje_1+&paje_prinais.*mpaje*enf01; 	
				/* Naissances entre janvier et novembre de l'année d'intérêt */
				if enf00>0 & mois00>2 & mois00<11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;					
				%end ;
		end;

		/******************************************/
		/* B.3 Allocation de base de la Paje      */
		/******************************************/

		if res_paje<=pl then do;  
			droit_AB='plein';
			/* Enfant de 0 an:alloc de base à partir du mois de naissance */
			if enf00>0 then paje0=(12-mois00)*mpaje*enf00;
			/* Enfant de 1 an ou 2 ans:alloc de base toute l'année */
			if enf01>0 then paje1=12*mpaje*enf01;
			if enf02>0 then paje2=12*mpaje*enf02;
			/* Enfant de 3 ans : alloc de base jusqu'au mois précédant son 3ème anniversaire */
			if enf03>0 then paje3=(mois03-1)*mpaje*enf03;
			end;

	/* Modulation de l'allocation de base de la Paje en 2014 pour enfants nés après Avril 2014 :
		on code la transition année par année (voir note 3 en haut du programme) */

		/** 2014 : on repère les enfants nés après avril : on sait que seuls des enfants de moins d'1 an seront concernés **/
		%if &anleg.=2014 %then %do;
			if naissance_apres_avril=1 then do;
				droit_AB='aucun';
				paje_nais=0;
				/* 1) tx plein */
				if res_paje<=pl_txplein then do;
					/* prime de naissance */
					if enf_1>0 then paje_nais=&paje_prinais.*mpaje*enf_1;
					if enf00>0 & mois00>2 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;
					/* AB */
					if enf00>0 then paje0=(12-mois00)*mpaje*enf00;
					droit_AB='plein';
					end;
				/* 2) tx partiel */
				else if pl_txplein<res_paje<=pl_txpartiel then do;
					/* prime de naissance */
					if enf_1>0 then paje_nais=&paje_prinais.*mpaje*enf_1;
					if enf00>0 & mois00>2 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;
					/* AB */
					if enf00>0 then paje0=(12-mois00)*mpaje_partiel*enf00;
					droit_AB='partiel';
					end;
				end;
		%end;

		/** 2015 : enfants de 0 et 1 an concernés **/
		%if &anleg.=2015 %then %do;
			if naissance_apres_avril in (1,2) then do;
				droit_AB='aucun';
				paje_nais=0;
				/* 1) tx plein */
				if res_paje<=pl_txplein then do;
					/* prime de naissance */
					if enf00>0 & mois00>2 & mois00<11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;
					/* AB */
					if enf00>0 then paje0=(12-mois00)*mpaje*enf00;
					if enf01>0 then paje1=12*mpaje*enf01;
					droit_AB='plein';
					end;
				/* 2) tx partiel */
				else if pl_txplein<res_paje<=pl_txpartiel then do;
					/* prime de naissance */
					if enf00>0 & mois00>2 & mois00<11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;
					/* AB */
					if enf00>0 then paje0=(12-mois00)*mpaje_partiel*enf00;
					if enf01>0 then paje1=12*mpaje_partiel*enf01;
					droit_AB='partiel';
					end;
				end;
		%end;

		/** 2016 : enfants de 0, 1 et 2 ans concernés **/
		%if &anleg.=2016 %then %do;
			if naissance_apres_avril in (1,2,3) then do;
				droit_AB='aucun';
				paje_nais=0;
				/* 1) tx plein */
				if res_paje<=pl_txplein then do;
					/* Prime de naissance */
					if enf01>0 & mois01=11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf01;
					if enf01>0 & mois01=12 then paje_nais=paje_1+&paje_prinais.*mpaje*enf01; 		
					if enf00>0 & mois00>2 & mois00<11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;	
					/* AB */
					if enf00>0 then paje0=(12-mois00)*mpaje*enf00;
					if enf01>0 then paje1=12*mpaje*enf01;
					if enf02>0 then paje2=12*mpaje*enf02;
					droit_AB='plein';
					end;
				/* 2) tx partiel */
				else if pl_txplein<res_paje<=pl_txpartiel then do;
					/* prime de naissance */
					if enf01>0 & mois01=11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf01;
					if enf01>0 & mois01=12 then paje_nais=paje_1+&paje_prinais.*mpaje*enf01; 		
					if enf00>0 & mois00>2 & mois00<11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;	
					/* AB */
					if enf00>0 then paje0=(12-mois00)*mpaje_partiel*enf00;
					if enf01>0 then paje1=12*mpaje_partiel*enf01;
					if enf02>0 then paje2=12*mpaje_partiel*enf02;
					droit_AB='partiel';
					end;
				end;
		%end;

		/** 2017 : enfants de 0, 1, 2 et 3 ans concernés **/
		%if &anleg.=2017 %then %do;
			if naissance_apres_avril in (1,2,3,4) then do;
				droit_AB='aucun';
				paje_nais=0;
				/* 1) tx plein */
				if res_paje<=pl_txplein then do;
					/* prime de naissance */
					if enf01>0 & mois01=11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf01;
					if enf01>0 & mois01=12 then paje_nais=paje_1+&paje_prinais.*mpaje*enf01; 		
					if enf00>0 & mois00>2 & mois00<11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;	
					/* AB */
					if enf00>0 then paje0=(12-mois00)*mpaje*enf00;
					if enf01>0 then paje1=12*mpaje*enf01;
					if enf02>0 then paje2=12*mpaje*enf02;
					if enf03>0 then paje3=(mois03-1)*mpaje*enf03;
					droit_AB='plein';
					end;
				/* 2) tx partiel*/
				else if pl_txplein<res_paje<=pl_txpartiel then do;
					/* prime de naissance */
					if enf01>0 & mois01=11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf01;
					if enf01>0 & mois01=12 then paje_nais=paje_1+&paje_prinais.*mpaje*enf01; 		
					if enf00>0 & mois00>2 & mois00<11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;	
					/* AB */
					if enf00>0 then paje0=(12-mois00)*mpaje_partiel*enf00;
					if enf01>0 then paje1=12*mpaje_partiel*enf01;
					if enf02>0 then paje2=12*mpaje_partiel*enf02;
					if enf03>0 then paje3=(mois03-1)*mpaje_partiel*enf03;
					droit_AB='partiel';
					end;
				end;
		%end;

		/* Si enfant de 0 et de 3 ans: addition des 2 alloc sur une partie de l'année */
		IF paje0>0 & paje3>0 THEN DO;
			IF droit_AB = 'partiel' THEN paje03 = paje0 + paje3 - max(0,mois03-1-mois00)*mpaje_partiel;
			ELSE paje03 = paje0 + paje3 - max(0,mois03-1-mois00)*mpaje;
			END;

		/* Montant de l'allocation de base de la Paje */
		paje_base=max(paje0,paje1,paje2,paje3,paje03);

		/***********************************************************/
		/* B.4 Montant total de la Paje (base+prime à la naissance */
		/***********************************************************/

		pajexx=sum(0,paje_nais,paje_base);

		/**********************************************************************/
		/* B.5 Nombre de mois de bénéfices de l'allocation de base de la Paje */
		/**********************************************************************/
		/* Nombre de mois de bénéfice de la PAJE */
		if paje_base>0 then do;
			if paje_base=paje1|paje_base=paje2 then nbmois_paje=12;
			else if paje_base=paje0 then nbmois_paje=12-mois00+1;
			else if paje_base=paje3|paje_base=paje03 then nbmois_paje=mois03-1;
			else nbmois_paje=12;
			end;
		else nbmois_paje=0;
	run;


	data modele.basefam;
		merge modele.basefam 
			  tot(keep=ident_fam paje_base paje_nais droit_AB);
		by ident_fam;
		if paje_base=. then paje_base=0; 
		if paje_nais=. then paje_nais=0; 

		label	paje_base="allocation de base"
				paje_nais="prime à la naissance"
		 		droit_AB="type de droit à l'allocation de base";
	run;

	%mend;
%Calcul_Paje;


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

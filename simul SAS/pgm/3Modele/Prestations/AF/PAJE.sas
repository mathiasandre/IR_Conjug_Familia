/************************************************************************************/
/*																					*/
/*								PAJE												*/
/*																					*/
/************************************************************************************/

/* Mod�lisation de l'allocation de base et de la prime � la naissance ou � l'adoption
de la Prestation d'Accueil du Jeune Enfant
	
 En entr�e : 	modele.basefam													
 En sortie : 	modele.basefam                                     

Plan
A. Plafond de ressources de la Paje 
B. Montant mensuel de l'allocation de base et de la prime � la naissance de la Paje
	B.1 Cr�ation des variables n�cessaires
	B.2 Prime � la naissance de la Paje
	B.3 Allocation de base de la Paje 
	B.4 Montant total de la Paje (base+prime � la naissance)
	B.5 Nombre de mois de b�n�fices de l'allocation de base de la Paje

Notes
1. La paje se d�compose en plusieurs allocations : 
- l'allocation de base
- la prime � la naissance/adoption
- le complement de libre choix d'activit� (CLCA), simul� dans un programme d�di�
- le compl�ment mode de garde (CMG), simul� dans un programme d�di�
 
2. Attention, les montants de la PAJE sont calcul�s avant CRDS. Il faut la d�duire pour arriver au revenu disponible

3. Modulation de l'allocation de base pour les enfants n�s � partir du 01/04/2014 :
La nouvelle variable naissance_apres_avril cr��e dans travail_clca.sas rep�re les enfants concern�s par la r�forme,
ils sont un peu plus nombreux chaque ann�e, jusqu'en avril 2017 ou tous le seront. 
*/

/************************************************/
/* A. Plafond de ressources de la Paje          */
/************************************************/

/* Dans la l�gislation le plafond de r�f�rence est donn� pour un enfant, mais la valorisation des enfants � charge
s'exprime en pourcentage d'un plafond th�orique pour 0 enfant. Il faut donc au pr�alable retrouver ce plafond
par calcul en divisant le plafond de r�f�rence pour un enfant par la valeur du 1er enfant � charge */
/* Note: les enfants � na�tre sont compt�s � charge */


%macro Calcul_Paje;
	data tot;
		set	modele.basefam;
		/*Nb d'enfants de 0 � 3 ans*/
		%nb_enf(je,0,&age_pajebase.,age_enf);
		/*Nb d'enfants de 0 � 19 ans s'il y a au moins 1 enfant de moins de 3 ans*/
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
		/*Plafonds pour couple bi-actif ou parent seul : on ne l'�crit plus en absolu mais en coefficient pour
			avoir le m�me param�tre pour le taux plein et le taux partiel*/
		if men_paje='H' then do;
			pl_txplein=pl_txplein + &majo_biact.;
			pl_txpartiel=pl_txpartiel + &majo_biact_part.;
			end;
		
		/***************************************************************************************/
		/* B. Montant mensuel de l'allocation de base et de la prime � la naissance de la Paje */
		/***************************************************************************************/
		/* Note: si naissances multiples, l'allocataire cumule plusieurs allocations de base */
		/* Hypoth�se : si 2 enfants ont le m�me age, on les consid�re comme jumeaux */

		/******************************************/
		/* B.1 Cr�ation des variables n�cessaires */
		/******************************************/
		%if &anleg. <= 2013 %then %do ; /* Jusqu'en 2013, l'allocation de base de la PAJE est exprim�e en fonction de la BMAF */
			mpaje=&bmaf.*&paje_t.;
			%end ;
		%if &anleg. = 2014 %then %do ; /* A partir du 1er avril 2014, l'AB de la PAJE est gel�e et surtout d�connect�e de la BMAF */ 
			mpaje=((3*&bmaf_n.*&paje_t.)+(9*&paje_m.))/12; /* pour les 3 premiers mois de l'ann�e, l'AB est encore exprim�e en fonction de la BMAF (valeur de celle-ci au 1er janvier).
			On fait une moyenne sur l'ann�e, m�me si en pratique le montant mensuel n'est pas modifi� � partir d'avril (malgr� la d�connection de la Bmaf */
			mpaje_partiel=&paje_m_partiel.; /* Pas de moyenne sur l'ann�e car le montant partiel ne concerne que les enfants n�s � partir du 1er avril */
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
		/* B.2 Prime � la naissance de la Paje    */
		/******************************************/
		Cond_PrimNais=res_paje<=pl or (&anleg.<1996);
		if Cond_PrimNais then do;	
			/*Note: Jusqu'en 2014, cette prime est vers�e en une seule fois au 7�me mois de grossesse. 
			A partir du 1er janvier 2015 (grossesses d�clar�es � la CAF � partir de cette date), la prime est vers�e "avant la fin du dernier jour du second mois" apr�s la naissance de l'enfant. 
		    Et pour les familles b�n�ficiaires de l'AB, la prime est vers�e en m�me temps soit le 1er jour du mois civil suivant la naissance. 
			On suppose donc qu'avec le changement de l�gislation, la prime est vers�e au 2e mois de l'enfant */
			paje_nais=0;
			%if &anleg. <= 2014 %then %do ;
				if enf_1>0 then paje_nais=&paje_prinais.*mpaje*enf_1;
				/* Pour enfants n�s pendant l'ann�e d'int�ret apr�s f�vrier*/
				if enf00>0 & mois00>2 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;
				%end ;
			%if &anleg. = 2015 %then %do ; /* Ne s'applique qu'aux grossesses d�clar�es � la CAF � partir du 1er janvier 2015, que l'on suppose � 3 mois. 
			       Concerne donc les naissances � partir du mois de juillet 2015 */
				/* Naissances entre mars et juin : prime vers�e au 7e mois de grossesse donc entre janvier et avril. 	
				   Naissances entre juillet et octobre : prime vers�e au 2e mois de l'enfant donc entre septembre et d�cembre */
				if enf00>0 & mois00>2 & mois00<11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;
				%end ;
			%if &anleg. >=2016 %then %do ; /* Prime au 2e mois de l'enfant */
				/* Naissances en novembre et d�cembre de l'ann�e pr�c�dente */
				if enf01>0 & mois01=11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf01; 
				if enf01>0 & mois01=12 then paje_nais=paje_1+&paje_prinais.*mpaje*enf01; 	
				/* Naissances entre janvier et novembre de l'ann�e d'int�r�t */
				if enf00>0 & mois00>2 & mois00<11 then paje_nais=paje_1+&paje_prinais.*mpaje*enf00;					
				%end ;
		end;

		/******************************************/
		/* B.3 Allocation de base de la Paje      */
		/******************************************/

		if res_paje<=pl then do;  
			droit_AB='plein';
			/* Enfant de 0 an:alloc de base � partir du mois de naissance */
			if enf00>0 then paje0=(12-mois00)*mpaje*enf00;
			/* Enfant de 1 an ou 2 ans:alloc de base toute l'ann�e */
			if enf01>0 then paje1=12*mpaje*enf01;
			if enf02>0 then paje2=12*mpaje*enf02;
			/* Enfant de 3 ans : alloc de base jusqu'au mois pr�c�dant son 3�me anniversaire */
			if enf03>0 then paje3=(mois03-1)*mpaje*enf03;
			end;

	/* Modulation de l'allocation de base de la Paje en 2014 pour enfants n�s apr�s Avril 2014 :
		on code la transition ann�e par ann�e (voir note 3 en haut du programme) */

		/** 2014 : on rep�re les enfants n�s apr�s avril : on sait que seuls des enfants de moins d'1 an seront concern�s **/
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

		/** 2015 : enfants de 0 et 1 an concern�s **/
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

		/** 2016 : enfants de 0, 1 et 2 ans concern�s **/
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

		/** 2017 : enfants de 0, 1, 2 et 3 ans concern�s **/
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

		/* Si enfant de 0 et de 3 ans: addition des 2 alloc sur une partie de l'ann�e */
		IF paje0>0 & paje3>0 THEN DO;
			IF droit_AB = 'partiel' THEN paje03 = paje0 + paje3 - max(0,mois03-1-mois00)*mpaje_partiel;
			ELSE paje03 = paje0 + paje3 - max(0,mois03-1-mois00)*mpaje;
			END;

		/* Montant de l'allocation de base de la Paje */
		paje_base=max(paje0,paje1,paje2,paje3,paje03);

		/***********************************************************/
		/* B.4 Montant total de la Paje (base+prime � la naissance */
		/***********************************************************/

		pajexx=sum(0,paje_nais,paje_base);

		/**********************************************************************/
		/* B.5 Nombre de mois de b�n�fices de l'allocation de base de la Paje */
		/**********************************************************************/
		/* Nombre de mois de b�n�fice de la PAJE */
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
				paje_nais="prime � la naissance"
		 		droit_AB="type de droit � l'allocation de base";
	run;

	%mend;
%Calcul_Paje;


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

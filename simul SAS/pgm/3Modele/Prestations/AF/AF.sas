*************************************************************************************;
/*																					*/
/*								AF													*/
/*																					*/
*************************************************************************************;

/* Modélisation des allocations familiales  */
/* En entrée : modele.basefam   */
/* En sortie : modele.basefam   */

********************************************************************;
/* 
Plan
1. Allocation familiale de base
2. Majoration pour âge 
3. Allocation forfaitaire
4. Complément familial
5. Calcul pour les DOM
6. Label
*/
********************************************************************;

%Macro AF;
	proc sort data=modele.basefam;by ident_fam01 ident_fam;run;

	data modele.basefam(rename=(age_enf12=age_enf));
		set modele.basefam(rename=(age_enf=age_enf12));
		by ident_fam01; 
		array age_enf age_enf1-age_enf12;
		%Init_Valeur(afxx0 majafxx alocforxx comxx majo_comxx af12 alocfor12 com12 majaf12 plaf1 plaf2 plaf3 plaf4);

		if first.ident_fam01 then do m=1 to 12;
			%Init_Valeur(af12 alocfor12 com12 majaf12 afm majafm);
			%nb_enf(e_c,0,&age_pf.,age_enf(m)); /*e_c donne le nb d'enfants à charge au mois m */
			if e_c>=2 then do;	/*Sélection des familles avec au moins 2 enfants à charge*/ 
	
			/************************************************************/
			/* 1. Allocation familiale de base et majoration pour âge */
			/************************************************************/
			
			/*les AF sont modulées sous condition de ressources à partir du 1er juillet 2015 :
			il y a trois tranches (montants inchangés, divisés par deux et divisés par quatre) 
			et un complément dégressif par douzièmes pour effacer les effets de seuil (décret n°2015-611).
			Ce complément dégressif inclue les majorations pour âge, c'est pour ça qu'on rassemble le calcul AF et majoration à la fin (voir 1bis)*/	

			/*1a. AF de base sans modulation */
			%if &anleg.<2015 %then %do;
				afxx0=afxx0+&bmaf.*(&af_t1.+&af_t2.*(e_c-2)); /*montant annuel*/
				af12=&bmaf.*(&af_t1.+&af_t2.*(e_c-2)); /*montant en décembre*/
			%end;

			/*1b. majoration pour âge sans modulation */

			/* En 2008 la majoration à partir d'un certain âge de l'enfant est réformée. Avant, 
			deux taux sont appliqués : un pour les enfants de 11 à 15 ans, et un autre pour les enfants
			de 15 à 19 ans. La nouvelle majoration n'a qu'un seul taux et ne concerne que les enfants 
			de 14 à 19 ans, nés après le 30 avril 1997. Jusqu'en 2011 inclu, les deux majorations 
			coexistent. En pratique, de 2008 à 2011, cela se traduit par une remontée de l'âge
			minimal pour le premier taux de la majoration dans le fichier paramètre, passant de 11 à 
			15 ans, puis à partir de 2011, on commence à compter les enfants de 14 ans dans le nb_majo.
			En 2012, on arrête de compter les enfants de plus de 16 ans dans l'ancienne majoration, 
			mais dans la nouvelle. Les enfants ne doivent être comptés qu'une fois : la somme de 
			nb_majo, nb_majo_old_t1 et nb_majo_old_t2 doit donner le nb d'enfants concernés par la 
			majoration, aînés compris même s'ils n'y donnent pas droit.	*/
			
			%if &anleg.>=2011 %then %do; 
				%nb_enf(nb_majo,&majo_a14.,&majo_a19.,age_enf(m));
				%end; 
			%else %do;
				nb_majo=0;
				%end;

			%if &anleg.<2012 %then %do;
				%nb_enf(nb_majo_old_t1,&majo_old_a11.,&majo_old_a15.,age_enf(m));
				%end; 
			%else %do;
				nb_majo_old_t1=0;
				%end;

			%if &anleg.<2016 %then %do; 
				%nb_enf(nb_majo_old_t2,&majo_old_a16.,&majo_old_a19.,age_enf(m)); 
				%end;
			%else %do;
				nb_majo_old_t2=0;
				%end;

			%if &anleg.<2015 %then %do;
			/* Si la famille a 2 enfants : pas de majoration pour l'ainé des enfants. Uniquement pour le 2e s'il remplie la condition d'âge */
				if e_c=2 and (nb_majo_old_t1+nb_majo_old_t2+nb_majo)=2 then do;		
					if (nb_majo_old_t1=2 or (nb_majo_old_t1=1 and nb_majo_old_t2=1)) then do;
						majafxx=majafxx+&majo_old_t1.*&bmaf.;
						majaf12=&majo_old_t1.*&bmaf.;
						end;
					else if (nb_majo_old_t2=2) then do;
						majafxx=majafxx+&majo_old_t2.*&bmaf.;
						majaf12=&majo_old_t2.*&bmaf.;
						end;
					else if ((nb_majo_old_t1=1 and nb_majo=1) or (nb_majo_old_t2=1 and nb_majo=1)) 
						or nb_majo=2 /* à partir de anleg=2012, tout le monde est dans ce cas */
						then do;
						majafxx=majafxx+&majo_t.*&bmaf.; /* montant annuel */
						majaf12=&majo_t.*&bmaf.; /* montant de décembre */
						end;
					end;				
			/* Si la famille a plus de 2 enfants à charge : une majoration par enfant remplissant les conditions d'âge */
				else if e_c>=3 then do;
					majafxx=majafxx+(&majo_old_t1.*nb_majo_old_t1
									 +&majo_old_t2.*nb_majo_old_t2
									 +&majo_t.*nb_majo)*&bmaf.; /* montant annuel */
					majaf12=( &majo_old_t1.*nb_majo_old_t1
								+&majo_old_t2.*nb_majo_old_t2
								+&majo_t.*nb_majo)*&bmaf.; /* montant de décembre */
					end;
				%end;

			/***********************************************************************************/
			/*1bis. modulation sous condition de ressources : AF et majoration pour âge */	
			/***********************************************************************************/
			/*Pour cette partie, on calcule d'abord les montants mensuels et on les accumule 
				pour obtenir les montants annuels ensuite*/

			/*En 2015, la modulation est uniquement sur les six derniers mois. 
			Par ailleurs, les majorations pour âge sont encore avec l'ancien système : nb_majo_old_t2 non nul (même si on a bien nb_majo_old_t1=0) */
			%if &anleg.=2015 %then %do;
				/*montants mensuels non modulés des AF et des majorations pour âge*/
				afm=&bmaf.*(&af_t1.+&af_t2.*(e_c-2)); 
				/* Si la famille a 2 enfants : pas de majoration pour l'ainé des enfants. Uniquement pour le 2e s'il a plus de 14 ans */
				if e_c=2 and (nb_majo_old_t2+nb_majo)=2 then do;
					majafm=max(&majo_old_t2.,&majo_t.)*&bmaf.; 
					end ;
				/* Si la famille a exactement plus de 2 enfants à charge : une majoration par enfant de plus de 14 ans */
				else if e_c >=3 then do ;				
					majafm=(&majo_old_t2.*nb_majo_old_t2+&majo_t.*nb_majo)*&bmaf.; 
					end;
						
				/*A] Première partie de l'année (janvier-juin) : pas de modulation sous condition de ressource*/
				if m < 7 then do ;
					af12=afm;
					majaf12=majafm;
					end;

				/*B] Seconde partie de l'année : avec modulation sous condition de ressource*/
				if m>6 then do ;
					plaf1 = &af_plaf1.+e_c*&af_plafpart.;
					plaf2 = plaf1+12*(afm/2+majafm/2);
					plaf3 = &af_plaf2.+e_c*&af_plafpart. ;
					plaf4 = plaf3+12*(afm/4+majafm/4);

					/* cas 0 : montants inchangés*/
					if res_paje<=plaf1 then do;
						af12=afm; 
						majaf12=majafm;
					end;
					/* cas 1 : atténuation des effets de seuil */
					if plaf1< res_paje and res_paje<= plaf2 then do;
						af12=max(0,afm + (plaf1-res_paje)/12); 
						majaf12=max(0,majafm + (plaf1-res_paje)/12);
						end;
					/* cas 2 : division par deux des montants sans coefficient dégressif */
					if plaf2 < res_paje and res_paje <=plaf3 then do;
						af12=afm/2; 
						majaf12=majafm/2;
						end;				
					/* cas 3 : atténuation des effets de seuil */
					if plaf3 < res_paje and res_paje <=plaf4  then do;
						af12=max(0,afm/2 + (plaf3-res_paje)/12); 
						majaf12=max(0,majafm/2 + (plaf3-res_paje)/12);
						end;
					/* cas 4 : division par quatre des montants sans coefficient dégressif */
					if plaf4 < res_paje then do;
						af12=afm/4; 
						majaf12=majafm/4;
						end;
					end;					
					 /*montants annuels*/
					afxx0=afxx0+af12; 
					majafxx=majafxx+majaf12;
				%end; 

			%if &anleg.>2015 %then %do;
			/*NB: après 2015 , le calcul des majorations est simplifié avec seulement nb_majo car nb_majo_old_t1=0 et nb_majo_old_t2=0 */
			/* Le calcul est particulier avec 2 enfants à charge, car dans ce cas pas de majoration pour âge pour l'ainé */ 
			/*montants mensuels non modulés des AF et des majorations pour âge*/
				afm=&bmaf.*(&af_t1.+&af_t2.*(e_c-2)); 
				if e_c=2 and nb_majo=2 then do ;
					majafm=&majo_t.*&bmaf.;
					end ;
				else if e_c >=3 then do ;
					majafm=nb_majo*&majo_t.*&bmaf.;
					end ;

				/* cas 0 : montants inchangés*/
				plaf1 = &af_plaf1.+e_c*&af_plafpart.;
				plaf2 = plaf1+12*(afm/2+majafm/2);
				plaf3 = &af_plaf2.+e_c*&af_plafpart. ;
				plaf4 = plaf3+12*(afm/4+majafm/4);

				/* cas 0 : montants inchangés*/
				if res_paje<=plaf1 then do;
					af12=afm; 
					majaf12=majafm;
					end;
				/* cas 1 : atténuation des effets de seuil */
				if plaf1< res_paje and res_paje<= plaf2 then do;
					af12=max(0,afm + (plaf1-res_paje)/12); 
					majaf12=max(0,majafm + (plaf1-res_paje)/12);
					end;
				/* cas 2 : division par deux des montants sans coefficient dégressif */
				if plaf2 < res_paje and res_paje <=plaf3 then do;
					af12=afm/2; 
					majaf12=majafm/2;
					end;				
				/* cas 3 : atténuation des effets de seuil */
				if plaf3 < res_paje and res_paje <=plaf4  then do;
					af12=max(0,afm/2 + (plaf3-res_paje)/12); 
					majaf12=max(0,majafm/2 + (plaf3-res_paje)/12);
					end;
				/* cas 4 : division par quatre des montants sans coefficient dégressif */
				if plaf4 < res_paje then do;
					af12=afm/4; 
					majaf12=majafm/4;
					end;			
				 /*montants annuels*/
				afxx0=afxx0+af12; 
				majafxx=majafxx+majaf12;			
			%end; 				

			/*****************************/
			/* 2. Allocation forfaitaire */
			/*****************************/
		
			%nb_enf(enf20,&age_pl.,&age_pl.,age_enf(m)); /* nombre d'enfants de 20 ans*/

			/*2a. Allocation sans modulation */
			%if &anleg.<2015 %then %do;
				if enf20>0 then do;
					alocforxx=alocforxx+&forfait_t.*&bmaf.; /* montant annuel */
					alocfor12=&forfait_t.*&bmaf.; /* montant de décembre */
					end;
			%end;
			
			/*2b. modulation sous condition de ressources */	
			/*En 2015, la modulation est uniquement sur les six derniers mois. */
			%if &anleg.=2015 %then %do;
				if enf20>0 then do;
					/*A] Première partie de l'année (janvier-juin) : pas de modulation sous condition de ressource*/
					if m < 7 then do ;
						alocfor12=&forfait_t.*&bmaf.;
						end;

					/*B] Seconde partie de l'année : avec modulation sous condition de ressource*/
					if m>6 then do ;
						plaf1 = &af_plaf1.+e_c*&af_plafpart.;
						plaf2 = plaf1+12*round(&forfait_t./2,0.001)*&bmaf.; /*les taux sont arrondis à trois chiffres*/
						plaf3 = &af_plaf2.+e_c*&af_plafpart. ;
						plaf4 = plaf3+12*round(&forfait_t./4,0.001)*&bmaf.;

						/* cas 0 : montants inchangés*/
						if res_paje<=plaf1 then do;
							alocfor12=&forfait_t.*&bmaf.;
						end;
						/* cas 1 : atténuation des effets de seuil */
						if plaf1< res_paje and res_paje<= plaf2 then do;
							alocfor12=max(0,&forfait_t.*&bmaf.+(plaf1-res_paje)/12); 
							end;
						/* cas 2 : division par deux des montants sans coefficient dégressif */
						if plaf2 < res_paje and res_paje <=plaf3 then do;
							alocfor12=round(&forfait_t./2,0.001)*&bmaf.;
							end;				
						/* cas 3 : atténuation des effets de seuil */
						if plaf3 < res_paje and res_paje <=plaf4  then do;
							alocfor12= max(0,round(&forfait_t./2,0.001)*&bmaf.+ (plaf3-res_paje)/12);
							end;
						/* cas 4 : division par quatre des montants sans coefficient dégressif */
						if plaf4 < res_paje then do;
							alocfor12=round(&forfait_t./4,0.001)*&bmaf.;
							end;
						end;					
						 /*montants annuels*/
						alocforxx=alocforxx+alocfor12;
					end;
				%end; 

			%if &anleg.>2015 %then %do;
				if enf20>0 then do;
					plaf1 = &af_plaf1.+e_c*&af_plafpart.;
					plaf2 = plaf1+12*round(&forfait_t./2,0.001)*&bmaf.; /*les taux sont arrondis à trois chiffres*/
					plaf3 = &af_plaf2.+e_c*&af_plafpart. ;
					plaf4 = plaf3+12*round(&forfait_t./4,0.001)*&bmaf.;

					/* cas 0 : montants inchangés*/
					if res_paje<=plaf1 then do;
						alocfor12=&forfait_t.*&bmaf.;
						end;
					/* cas 1 : atténuation des effets de seuil */
					if plaf1< res_paje and res_paje<= plaf2 then do;
						alocfor12=max(0,&forfait_t.*&bmaf.+(plaf1-res_paje)/12); 
						end;
					/* cas 2 : division par deux des montants sans coefficient dégressif */
					if plaf2 < res_paje and res_paje <=plaf3 then do;
						alocfor12=round(&forfait_t./2,0.001)*&bmaf.;
						end;				
					/* cas 3 : atténuation des effets de seuil */
					if plaf3 < res_paje and res_paje <=plaf4  then do;
						alocfor12= max(0,round(&forfait_t./2,0.001)*&bmaf.+ (plaf3-res_paje)/12);
						end;
					/* cas 4 : division par quatre des montants sans coefficient dégressif */
					if plaf4 < res_paje then do;
						alocfor12=round(&forfait_t./4,0.001)*&bmaf.;
						end;		
				 	/* montants annuels */
					alocforxx=alocforxx+alocfor12;
					end ;
				%end; 				
				

			/**************************/
			/* 3. Complément familial */
			/**************************/

				/* on colle à la législation et plus aux brochures, 
				il y a un taux pour bi activité et un seul montant de plafond */
				%nb_enf(je,0,2,age_enf(m));	
				/* je donne le nombre d'enfants de 0 à 2 ans inclus*/
				if je=0 & e_c+enf20>2 then do;
					pl = &cf_plaf./1.25*(1+0.25+0.25+0.3*(e_c+enf20-2))+&cf_diff_plaf.*(men_paje='H');
					pl_majo = &cf_plaf_majo./1.25*(1+0.25+0.25+0.3*(e_c+enf20-2))+&cf_diff_majo.*(men_paje='H');
					
					if res_paje<pl_majo then do; /* Avant 2014 cette situation ne devrait pas être rencontrée pl_majo étant nul */
						majo_comxx=majo_comxx+max(0,&bmaf.*&cf_majo.-&bmaf.*&cf_t.); *on doit isoler le montant de la majoration pour le retirer ensuite de la BR du rsa;
						comxx=comxx+&bmaf.*&cf_majo.; /* montant annuel majoré */
						com12=&bmaf.*&cf_majo.; /* montant de décembre */
						end;
					else if res_paje<=pl then do;
						comxx=comxx+&bmaf.*&cf_t.; /* montant annuel */
						com12=&bmaf.*&cf_t.; /* montant de décembre */
						end;
					else if res_paje-pl<=&bmaf.*&cf_t.*12 then do;
						comxx=comxx+&bmaf.*&cf_t.-(res_paje-pl)/12; /* montant annuel */
						com12=&bmaf.*&cf_t.-(res_paje-pl)/12; /* montant de décembre */
						end;
					end;
			/**************************/
			/* 4. Calcul pour les DOM */
			/**************************/

				/*passage à décommenter lorsque l'on travaille sur les DOM
				if dom then do; 
					if e_c=1 then do; 
						%nb_enf(nb_majo_old_t1,&majo_old_a11.,&majo_old_a15.,age_enf(m)); 
						age1=11,age2=15,age3=16,age4=20;
						%nb_enf(nb_majo_old_t2,&majo_old_a16.,&majo_old_a19.,age_enf(m));
						afxx0=afxx0+&bmaf*&afdom1; 	
						*&afdom1=5.88%=0.0588, &majdom1=3.69%,&majdom2=5.67%;
						majafxx=majafxx+(nb_majo_old_t1=1)*&majdom1*&bmaf
									 +(nb_majo_old_t2=1)*&majdom2*&bmaf;
				 	end;
					*le complément familial a un autre montant et une autre limite de calcul du 
					plafond de ressources, c'est celui de l'ARS (métropole et DOM).;
					pl=(&rs001-&rs002)+e_c*&rs002;
					if res_paje<=pl then comxx=comxx+&bmaf*&cfdom;*cfdom=23.79%;
					else if res_paje-pl<=&bmaf*&cf_t*12 then comxx=comxx+&bmaf*&cf_t-(res_paje-pl);
					end;*/

				end;
			end;
			
			/**************************************/
			/* 3.bis Complément familial en 2014 */
			/************************************/

		%if &anleg.=2014 %then %do;
			if first.ident_fam01 then do;
				%Init_Valeur(comxx majo_comxx com12 pl pl_majo);
				do m=1 to 3;
					%nb_enf(e_c,0,&age_pf.,age_enf(m));
					if e_c>=2 then do;
						%nb_enf(je,0,2,age_enf(m));	
						%nb_enf(enf20,&age_pl.,&age_pl.,age_enf(m)); 
						if je=0 & e_c+enf20>2 then do;
							pl = &cf_plaf./1.25*(1+0.25+0.25+0.3*(e_c+enf20-2))+&cf_diff_plaf.*(men_paje='H');

							if res_paje<=pl then comxx=comxx+&bmaf.*&cf_t.; /* montant annuel */
							else if res_paje-pl<=&bmaf.*&cf_t.*12 then comxx=comxx+&bmaf.*&cf_t.-(res_paje-pl)/12; /* montant annuel */
							end;
						end;
					end;

				do m=4 to 12;
					%nb_enf(e_c,0,&age_pf.,age_enf(m));
					if e_c>=2 then do;
						%nb_enf(je,0,2,age_enf(m));	
						%nb_enf(enf20,&age_pl.,&age_pl.,age_enf(m)); 
						if je=0 & e_c+enf20>2 then do;
							pl = &cf_plaf./1.25*(1+0.25+0.25+0.3*(e_c+enf20-2))+&cf_diff_plaf.*(men_paje='H');
							pl_majo = &cf_plaf_majo./1.25*(1+0.25+0.25+0.3*(e_c+enf20-2))+&cf_diff_majo.*(men_paje='H');

							if res_paje<pl_majo then do; /* Avant 2014 cette situation ne devrait pas être rencontrée pl_majo étant nul */
								majo_comxx=majo_comxx+max(0,&bmaf.*&cf_majo.-&bmaf.*&cf_t.); *on doit isoler le montant de la majoration pour le retirer ensuite de la BR du rsa;
								comxx=comxx+&bmaf.*&cf_majo.; /* montant annuel majoré */
								com12=&bmaf.*&cf_majo.; /* montant de décembre */
								end;

							else if res_paje<=pl then do;
								comxx=comxx+&bmaf.*&cf_t.; /* montant annuel */
								com12=&bmaf.*&cf_t.; /* montant de décembre */
								end;

							else if res_paje-pl<=&bmaf.*&cf_t.*12 then do;
								comxx=comxx+&bmaf.*&cf_t.-(res_paje-pl)/12; /* montant annuel */
								com12=&bmaf.*&cf_t.-(res_paje-pl)/12; /* montant de décembre */
								end;

							end;
						end;
					end;
				end;

			%end;

		label 	afxx0 	= 	"AF-montant annuel "
				majafxx	=	"Majoration AF-montant annuel"
				alocforxx=	"Allocation forfaitaire AF-montant annuel"
				comxx	=	"Complement familial AF-montant annuel"
				af12	=	"AF-montant de decembre"
				majaf12 =	"Majoration AF-montant de decembre"
				alocfor12=	"Allocation forfaitaire AF-montant de decembre"
				com12	=	"Complement familial AF-montant de decembre";

		drop je enf20 nb_majo_old_t1 nb_majo_old_t2 nb_majo pl pl_majo m plaf1 plaf2 plaf3 plaf4 majafm afm;
	run;

	proc datasets mt=data kill;run;quit;
	%Mend AF;

%AF;


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

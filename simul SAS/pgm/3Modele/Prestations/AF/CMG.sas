****************************************************************************************;
************************** Calcul du Compl�ment Mode de Garde **************************; 
****************************************************************************************;

/* Mod�lisation du Compl�ment Mode De Garde              			*/
/* En entr�e : modele.basefam 			
/* En sortie : modele.basefam                                     	*/
*********************************************************************;
/* 
Plan
A. Cr�ation de la base � travailler
	A.1 Familles concern�es par le CMG
	A.2 Plafond de ressources du CMG
B. Calcul des montants de CMG
	B.1 CMG prestations
		B.1.a Montant max de CMG prestation vers�
		B.1.b Montant de CMG presta per�u 
	B.2 CMG exon�rations
		B.2.a Montant de CMG exo assistant maternel per�u
		B.2.b Montant de CMG exo salari� � domicile per�u
*/
********************************************************************;
************************************************************************* ;
*					EXPLICATION INTRODUCTIVE							  ;
************************************************************************* ;

* Non pris en compte par le programme: 
- 1: Si le m�nage travaille et fait garder son enfant au moins 25 heures dans le mois selon 
des horaires sp�cifiques (nuit, dimanche, jours f�ri�s) le compl�ment est major�,
- 2: pour les modes de gardes 'structure', le montant est diff�rent si la structure emploie 
quelqu'un qui vient au domicile(ou est une micro-cr�che) ou si la structure emploi un 
assistant maternel. Mais nous ne faisons pas la diff�rence: on donne le plus faible montant 
qui peut �tre per�u (c'est � dire celui d'une structure qui emploi un assistant maternel). 
On pourrait faire la moyenne ou l'inverse; 

* Hypoth�ses:
- H1: une famille garde tous ses enfants de la m�me fa�on. Pour ne pas faire cette hypoth�se, il faudrait 
avoir une entr�e mode de garde par enfant et non par famille.
- H2: on suppose, sans coh�rence avec les montants d�clar�s dans les d�clarations d'impots, que l'on d�pense 
toujours jusqu'au plafond pour l'emploi direct d'une personne � domicile;

************************************************************************************ ;


%Macro CMG;


	/**********************************************/
	/* A. Cr�ation de la base � travailler        */
	/**********************************************/

	/**************************************/
	/* A.1 Familles concern�es par le CMG */
	/**************************************/

	data calcul; 
		set modele.basefam;
		/* Nb d'enfants de 0 � 5 ans */
		%nb_enf(enf,0,5,age_enf); 

		/* On ne garde que les familles o�:
		- est utilis� un mode de garde CMG (assistant maternel, salari� � domicile ou 
		structure/micro cr�che), 
		- tous les adultes de la famille travail (les 2 adultes s'ils sont deux, l'adulte si 
		parent isol�)
		- il y a au moins un enfant �g� de 0 � 5 ans*/
		if garde in ('assmat','saldom','structur') & men_paje='H' & enf>0;
		/* On peut assouplir la condition  men_paje='H' car dans la loi, il n'y a pas de condition de ressources 
		n�cessaire pour toucher le CMG si la PR
		- est �tudiante,
		- ou per�oit l'AAH,
		- ou per�oit le RSA,
		- ou est demandeuse d'emploi et � l'ASS*/
		run;

		/**************************************/
		/* A.2 Plafond de ressources du CMG   */
		/**************************************/

	data plafond; 
		set calcul; 
		/* Les plafonds de ressources du CMG et de l'AB de la Paje sont en partie communs.
		On les recalcule ici pour le CMG car on n'est pas forc�ment sur la m�me sous-population de b�n�ficiaires, 
		mais il s'agit du m�me code qui peut �tre copi�-coll� */

		/* Avant 2014 */
		/*Nb d'enfants de 0 � 19 ans s'il y a au moins 1 enfant de moins de 3 ans*/
		%nb_enf(e_c,0,&age_pf.,age_enf); 

		/*Plafond pour couple mono-actif avec 1 enfant*/
		if sum(e_c,enf_1)<=1 then pl=&paje002.;
		/*Plafond pour couple mono-actif avec plus de 1 enfant*/
		else if sum(e_c,enf_1)>1 then pl=&paje002./(1+&paje_majo_pac12.)*
										 (1+&paje_majo_pac12.*min(2,sum(e_c,enf_1)) 
										 +&paje_majo_pac3.*max(0,sum(e_c,enf_1)-2));
		pl=pl+&paje001.;
		
		/* Apr�s 2014 (enfants n�s � partir du 1er avril 2014) */
		/*Plafond pour couple mono-actif avec 1 enfant (on ne calcule que le "taux partiel" de l'AB de la Paje) */
		if sum(e_c,enf_1)<=1 then pl_txpartiel=&paje_plaf_part.;
		/*Plafond pour couple mono-actif avec plus de 1 enfant (on ne calcule que le "taux partiel" de l'AB de la Paje)*/
		else if sum(e_c,enf_1)>1 then pl_txpartiel=&paje_plaf_part./(1+&majo_pac.)*(1+&majo_pac.*sum(e_c,enf_1));
		
		pl_txpartiel=pl_txpartiel + &majo_biact_part.;
		/* On remplace pl par le "taux partiel" pour les enfants n�s � partir du 1er avril 2014 */ 
		%if &anleg.=2014 %then %do;
			if naissance_apres_avril=1 then do;
				pl = pl_txpartiel ;
				end ;
			%end ;
		%if &anleg.=2015 %then %do;
			if naissance_apres_avril in (1,2) then do;
				pl = pl_txpartiel ;
				end ;
			%end ;
		%if &anleg.=2016 %then %do;
			if naissance_apres_avril in (1,2,3) then do;
				pl = pl_txpartiel ;
				end ;
			%end ;
		%if &anleg.=2017 %then %do;
			if naissance_apres_avril in (1,2,3,4) then do;
				pl = pl_txpartiel ;
				end ;
			%end ;

		/* Avant 2004, pour l'AGED, le plafond de r�f�rence n'�tait pas celui de la PAJE mais 
		celui de l'ARS les seuils �tait � 110% et � 80%, on calcul ici 110%, et plus loin 
		cmg_tplaf sera �gal � 80/110*/
		%if &anleg.<2004 %then %do;
			pl=110/100*(&rs001.-&rs002.)+e_c*&rs002.;
			%end; 
		run;

	/**********************************************/
	/* B. Calcul des montants de CMG              */
	/**********************************************/

	/**************************************/
	/* B.1 CMG prestations                */
	/**************************************/

	/*********************************************/
	/* B.1.a Montant max de CMG prestation vers� */
	/*********************************************/

	data montant_max; 
		set plafond; 
		/* Nb d'enfants de 0 � 2 ans */
		%nb_enf(enf02,0,2,age_enf); 
		/* Nb d'enfants de 3 � 5 ans */
		%nb_enf(enf35,3,5,age_enf); 

		/* Variable CMG = montant maximum de CMG prestation qui peut �tre per�u par famille */
		cmg=0;

		/* Pour les familles faisant partie de la tranche 1 (basse) selon le mode de garde*/
		if res_paje<&cmg_tplaf.*pl then do; 
			/*Garde en structure assistant maternel*/
			if garde='structur'		then CMG=(enf02+0.5*enf35)*&cmg_hdom1.*&bmaf.*12; 
			/* Garde en structure employ�/microcreche: non pris en compte comme expliqu� en introduction du code*/
			/*if garde='structur' then CMG=max((enf02+0.5*enf35),1)*&cmg_dom1*&bmaf*12;*/
			/*Garde assistant maternel*/
			if garde='assmat'		then CMG=(enf02+0.5*enf35)*&cmg_sal1.*&bmaf.*12; 
			*Garde employ� � domicile;
			if garde='saldom' 		then CMG=max((enf02+0.5*enf35),1)*&cmg_sal1.*&bmaf.*12; 
			end; 

		else if &cmg_tplaf.*pl<res_paje<&cmg_tplaf.*pl*&cmg_majoPI. & nbciv=1 then do;
			%let ratio=%sysevalf(7/12*(&anleg.=2012)+1*(&anleg.>2012)); /* 0 avant 2012 */
			/* on ne donne que 7/12 de CMG en 2012 car la loi est appliqu� � partir du 1er juin */

			/*majoration du plafond de ressoures des parents isol�s*/
			/*Garde en structure assistant maternel*/
			if garde='structur'		then CMG=(enf02+0.5*enf35)*&cmg_hdom1.*&bmaf.*12*&ratio.;
			/* Garde en structure employ�/microcreche: non pris en compte comme expliqu� en introduction du code*/
			/*if garde='structur' then CMG=max((enf02+0.5*enf35),1)*&cmg_dom1*&bmaf*12*&ratio.;*/
			/*Garde assistant maternel*/
			if garde='assmat'		then CMG=(enf02+0.5*enf35)*&cmg_sal1.*&bmaf.*12*&ratio.; 
			/*Garde employ� � domicile*/
			if garde='saldom'		then CMG= max((enf02+0.5*enf35),1)*&cmg_sal1.*&bmaf.*12*&ratio.;
			end;

		/* Pour les familles faisant partie de la tranche 2 selon le mode de garde */
		else if res_paje<pl then do; 
			if garde='structur' 	then CMG=(enf02+0.5*enf35)*&cmg_hdom2.*&bmaf.*12; 
			/*if garde='structur' then CMG=max((enf02+0.5*enf35),1)*&cmg_dom2*&bmaf*12;*/ 
			if garde='assmat'  		then CMG=(enf02+0.5*enf35)*&cmg_sal2.*&bmaf.*12; 
			if garde='saldom'  		then CMG= max((enf02+0.5*enf35),1)*&cmg_sal2.*&bmaf.*12; 
			end; 

		else if pl<res_paje<pl*&cmg_majoPI. & nbciv=1 then do;
			%let ratio=%sysevalf(7/12*(&anleg.=2012)+1*(&anleg.>2012)); /* 0 avant 2012 */
			/* on ne donne que 7/12 de CMG en 2012 car la loi est appliqu� � partir du 1er juin */

			/*majoration du plafond de ressoures des parents isol�s*/
			/*on ne donne que 7/12 de CMG en 2012 car la loi est appliqu� � partir du 1er juin*/
			if garde='structur' 	then CMG=(enf02+0.5*enf35)*&cmg_hdom2.*&bmaf.*12*&ratio.;
			/*if garde='structur' then CMG=max((enf02+0.5*enf35),1)*&cmg_dom2*&bmaf*(7/12); */
			if garde='assmat'  		then CMG=(enf02+0.5*enf35)*&cmg_sal2.*&bmaf.*12*&ratio.;
			if garde='saldom'  		then CMG= max((enf02+0.5*enf35),1)*&cmg_sal2.*&bmaf.*12*&ratio.;
			end;

		/* Pour les familles faisant partie de la tranche 3 (haute) selon le mode de garde */
		else do;
			if garde='structur' then CMG=(enf02+0.5*enf35)*&cmg_hdom3.*&bmaf.*12; 
			/*if garde='structur'	then CMG=max((enf02+0.5*enf35),1)*&cmg_dom3*&bmaf*12; */
			if garde='assmat'  then CMG=(enf02+0.5*enf35)*&cmg_sal3.*&bmaf.*12; 
			if garde='saldom'  then CMG= max((enf02+0.5*enf35),1)*&cmg_sal3.*&bmaf.*12; 
			end; 
		run;

	/*********************************************/
	/* B.1.b Montant de CMG prestation per�u     */
	/*********************************************/

	data montant_participation; 
		set montant_max; 

		/* Rappel: la variable FraisGardeSuperbrut&anr2. est le salaire superbrut de l'employ�. La participation de la Caf
		s'applique au salaire net, c'est � dire la variable FraisGardeNet&anr2.*/
		/* Creation de la variable FraisGardeNet&anr2.*/
		if garde in ('assmat','saldom') then FraisGardeNet&anr2.=FraisGardeSuperbrut&anr2.*(1-&salcot_assmat.)/(1+&patcot_assmat.);
		else FraisGardeNet&anr2.=FraisGardeSuperbrut&anr2.;

		%if &anleg.<2004 %then %do;
			CMG = min(CMG,FraisGardeNet&anr2.);
			%end;
		/* Application de la r�gle des 85% de salaire net pris en charge par la Caf jusqu'� un certain montant. La 
		variable CMG cr�e pr�c�demment permet de donner le montant maximum pouvant �tre rembours� par la Caf*/
		%else %if &anleg.>= 2004 %then %do;
			CMG = min(CMG,0.85*FraisGardeNet&anr2.);
			%end;

		/**************************************/
		/* B.2 CMG exon�rations               */
		/**************************************/
		/* Note: pour les modes de garde en structure, il n'y a pas de CMG exon�ration */

		/*********************************************************/
		/* B.2.a Montant de CMG exo assistant maternel per�u     */
		/*********************************************************/
		/* Exon�ration � 100% pour les assistants maternels */
		/* La prise en charge des cotisations salariales et patronales est � 100% � condition 
		que la r�mun�ration de l'assistant maternel ne d�passe pas 5 SMIC horaire par jour 
		et par enfant gard�. On part de la base de 52 semaines travaill�es (avec des cong�s 
		pay�s) par an et de 5 jours travaill�s par semaine */

		if garde='assmat' then CMG_exo=min(FraisGardeSuperbrut&anr2.-FraisGardeNet&anr2.,(enf02+enf35)*5*52*5*&smich.*sum(0,&salcot_assmat.,&patcot_assmat.));

		/*********************************************************/
		/* B.2.b Montant de CMG exo salari� � domicile per�u     */
		/*********************************************************/
		/* Exon�ration � 50% pour les salari�s � domicile */
		/* La prise en charge des cotisations salariales et patronales est � 50% dans une 
		limite de 419�(=cmg_exo_l1)	par mois pour un enfant de 0 � 2 ans et de 210�
		(=cmg_exo_l2)par mois pour un enfant de 3 � 5 ans */

		if enf02>0 then plafond_cot=&cmg_exo_l1.*12;
		else if enf35>0 then plafond_cot=&cmg_exo_l2.*12;

		if garde='saldom' then do; 
			CMG_exo=min(0.5*(FraisGardeSuperbrut&anr2.-FraisGardeNet&anr2.),plafond_cot);
			%if &anleg.<1998 %then %do;
				CMG_exo= min(1*(FraisGardeSuperbrut&anr2.-FraisGardeNet&anr2.),plafond_cot);
				%end;
			%if 1998<=&anleg. and &anleg.<2004 %then %do; 
				if res_paje<&aged_plaf. & enf02>0 then CMG_exo=min(0.75*(FraisGardeSuperbrut&anr2.-FraisGardeNet&anr2.),1.5*plafond_cot);
				%end;
			end;
		run; 

	proc sort data=montant_participation; by ident_fam; run; 
	proc sort data=modele.basefam; by ident_fam; run;
	data modele.basefam;
		merge modele.basefam(in=a)
			  montant_participation(keep=ident_fam CMG CMG_exo);
		by ident_fam; 
		if a; 
		if CMG=. then CMG=0; 
		if CMG_exo=. then CMG_exo=0; 
		label	CMG="compl�ment de libre choix du mode de garde - salaire"
				CMG_exo="compl�ment de libre choix du mode de garde - cotisations";
		run; 

	%Mend CMG;

%CMG;


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

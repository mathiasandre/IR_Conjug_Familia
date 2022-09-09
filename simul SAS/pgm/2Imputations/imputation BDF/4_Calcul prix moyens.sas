/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*																					   */
/*  						CALCUL DES PRIX MOYENS UNITAIRES	                       */
/*																					   */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/* Le programme permet de calculer les prix moyens unitaires pour obtenir par la suite 
des quantit�s pour les produits sur lesquels il y a des droits sur les quantit�s 
consomm�es. Cette �tape est r�alis�e � partir des carnets de bdf&anBDF.. Elle ne d�pend pas 
de l'ann�e de l�gislation simul�e, mais il est n�cessaire d'avoir construit les d�ciles de 
niveau de vie dans BDF pour le calcul des prix du vin et de la bi�re. */
 
/* Tables d'entr�es : 
		- bdf&anBDF..carnets 
		- bdf&anBDF..carnets6 (donn�es des carnets au niveau COICOP 6 chiffres pour quelques 
		  postes - sur demande aupr�s de l'�quipe BDF)
		- base20&anr2.                                                         */

/*Tables de sorties :
		- dossier.prix_moyen_&anBDF. : prix moyens des liquides list�s dans  &liste_liquides_nomen.
		- dossier.prix_&anBDF._vin : prix moyen par d�cile du vin
		- dossier.prix_&anBDF._biere : prix moyen par d�cile de la bi�re */

/* AV : pourquoi n'exclut-on pas les DOM hors vin et bi�re ? pour le rhum, �a doit pas mal biaiser les estimations :) */

/* 	Pour chaque produit (hors vin et bi�re), on conserve le prix moyen apr�s avoir exclu 
    les valeurs < p5 et > p95. L'ensemble des m�nages sont pris en compte (DOM inclus).
    Pour le vin et la bi�re, on calcule les prix par d�ciles. Pour ne pas r�duire davantage 
    l'�chantillon, on conserve toutes les valeurs. Par contre, les m�nages des DOM sont exclus */															
										                                  					                                  
/****************************************************************************************/
%Macro calcul_prix() ;

%if &casd.=non %then %do ;

	/* �tape data pour tous les nomens et aussi les quantit�s U et L pour les liquides*/
	data carnet_li ; 
		set BDF&anBDF..carnets6;
		/* On ne conserve que les d�penses des liquides pour lesquels on connait la quantit� consomm�e */
		if montant < 0 then delete ;
		if quantite = . then delete;
		if unite = "" then unite = "U"; /*les valeurs manquantes sont enti�res, on suppose que c'est des bouteilles*/
	/* On d�termine le prix au litre */
		if unite = "L" then prix_litre = montant / quantite ; 
		if unite = "U" then prix_litre = montant / (quantite*0.75) ; /* on suppose que l'unit� est une bouteille */
		if prix_litre = . then delete;
		/*on ne garde que les valeurs de nomen6 qui sont dans la liste des liquides*/
		%Keep_list(&liste_liquides_nomen., nomen6);
		run;
	/*on fait directement la moyenne trim�e*/
	proc univariate data = carnet_li  trimmed=0.1; 
		class nomen6;
		var prix_litre; 
		ods output TrimmedMeans = dossier.prix_moyen_&anBDF.  (keep = nomen6 mean rename =(mean = prix_&anBDF.)) ; 
		run;	

	/*pour le vin et la bi�re, on calcule les prix moyens par d�cile*/
	data carnet_vin ; 
		merge BDF&anBDF..carnets6 (in =a) base20&anr2. (keep = ident_men dec_aj) ;
		by ident_men ;
		if a ;
		/* On ne conserve que les d�penses des liquides pour lesquels on connait la quantit� consomm�e */
		if montant < 0 then delete ;
		if quantite = . then delete;
		/* On d�termine le prix au litre */
		if unite = "L" then prix_litre = montant / quantite ; 
		if prix_litre = . then delete;
		if dec_aj = '' then delete ;
		if nomen6 = "021211" then output; /*vin*/
		run;

	/*On cr�e la table avec les prix moyens par d�cile*/
	proc sort data = carnet_vin; by dec_aj ; run ;
	proc univariate data = carnet_vin noprint; 
		var prix_litre; 
		by dec_aj;
		output out = dossier.prix_&anBDF._vin (where = (dec_aj not in (" ")))  N = effectif mean = px_li_vin ; 
		run;	

	/*Idem pour la bi�re mais c'est via nomen5 de la table carnets*/
	data carnet_biere; 
		merge BDF&anBDF..carnets (in =a) base20&anr2. (keep = ident_men dec_aj) ;
		by ident_men ;
		if a ;
		/* On ne conserve que les d�penses des liquides pour lesquels on connait la quantit� consomm�e */
		if montant < 0 then delete ;
		if quantite = . then delete;
		/* On d�termine le prix au litre */
		if unite = "L" then prix_litre = montant / quantite ; 
		if prix_litre = . then delete;
		if dec_aj = '' then delete ;
		if nomen5 = "02131" then output; /*bi�re*/
		run;
	/*On cr�e la table avec les prix moyens par d�cile*/
	proc sort data = carnet_biere; by dec_aj ; run ;
	proc univariate data = carnet_biere noprint; 
		var prix_litre; 
		by dec_aj;
		output out = dossier.prix_&anBDF._biere (where = (dec_aj not in (" ")))  N = effectif mean = px_li_biere ; 
		run;	

	%end ;
%mend;

%calcul_prix() ;


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

/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*																					   */
/*  						CALCUL DES PRIX MOYENS UNITAIRES	                       */
/*																					   */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/* Le programme permet de calculer les prix moyens unitaires pour obtenir par la suite 
des quantités pour les produits sur lesquels il y a des droits sur les quantités 
consommées. Cette étape est réalisée à partir des carnets de bdf&anBDF.. Elle ne dépend pas 
de l'année de législation simulée, mais il est nécessaire d'avoir construit les déciles de 
niveau de vie dans BDF pour le calcul des prix du vin et de la bière. */
 
/* Tables d'entrées : 
		- bdf&anBDF..carnets 
		- bdf&anBDF..carnets6 (données des carnets au niveau COICOP 6 chiffres pour quelques 
		  postes - sur demande auprès de l'équipe BDF)
		- base20&anr2.                                                         */

/*Tables de sorties :
		- dossier.prix_moyen_&anBDF. : prix moyens des liquides listés dans  &liste_liquides_nomen.
		- dossier.prix_&anBDF._vin : prix moyen par décile du vin
		- dossier.prix_&anBDF._biere : prix moyen par décile de la bière */

/* AV : pourquoi n'exclut-on pas les DOM hors vin et bière ? pour le rhum, ça doit pas mal biaiser les estimations :) */

/* 	Pour chaque produit (hors vin et bière), on conserve le prix moyen après avoir exclu 
    les valeurs < p5 et > p95. L'ensemble des ménages sont pris en compte (DOM inclus).
    Pour le vin et la bière, on calcule les prix par déciles. Pour ne pas réduire davantage 
    l'échantillon, on conserve toutes les valeurs. Par contre, les ménages des DOM sont exclus */															
										                                  					                                  
/****************************************************************************************/
%Macro calcul_prix() ;

%if &casd.=non %then %do ;

	/* étape data pour tous les nomens et aussi les quantités U et L pour les liquides*/
	data carnet_li ; 
		set BDF&anBDF..carnets6;
		/* On ne conserve que les dépenses des liquides pour lesquels on connait la quantité consommée */
		if montant < 0 then delete ;
		if quantite = . then delete;
		if unite = "" then unite = "U"; /*les valeurs manquantes sont entières, on suppose que c'est des bouteilles*/
	/* On détermine le prix au litre */
		if unite = "L" then prix_litre = montant / quantite ; 
		if unite = "U" then prix_litre = montant / (quantite*0.75) ; /* on suppose que l'unité est une bouteille */
		if prix_litre = . then delete;
		/*on ne garde que les valeurs de nomen6 qui sont dans la liste des liquides*/
		%Keep_list(&liste_liquides_nomen., nomen6);
		run;
	/*on fait directement la moyenne trimée*/
	proc univariate data = carnet_li  trimmed=0.1; 
		class nomen6;
		var prix_litre; 
		ods output TrimmedMeans = dossier.prix_moyen_&anBDF.  (keep = nomen6 mean rename =(mean = prix_&anBDF.)) ; 
		run;	

	/*pour le vin et la bière, on calcule les prix moyens par décile*/
	data carnet_vin ; 
		merge BDF&anBDF..carnets6 (in =a) base20&anr2. (keep = ident_men dec_aj) ;
		by ident_men ;
		if a ;
		/* On ne conserve que les dépenses des liquides pour lesquels on connait la quantité consommée */
		if montant < 0 then delete ;
		if quantite = . then delete;
		/* On détermine le prix au litre */
		if unite = "L" then prix_litre = montant / quantite ; 
		if prix_litre = . then delete;
		if dec_aj = '' then delete ;
		if nomen6 = "021211" then output; /*vin*/
		run;

	/*On crée la table avec les prix moyens par décile*/
	proc sort data = carnet_vin; by dec_aj ; run ;
	proc univariate data = carnet_vin noprint; 
		var prix_litre; 
		by dec_aj;
		output out = dossier.prix_&anBDF._vin (where = (dec_aj not in (" ")))  N = effectif mean = px_li_vin ; 
		run;	

	/*Idem pour la bière mais c'est via nomen5 de la table carnets*/
	data carnet_biere; 
		merge BDF&anBDF..carnets (in =a) base20&anr2. (keep = ident_men dec_aj) ;
		by ident_men ;
		if a ;
		/* On ne conserve que les dépenses des liquides pour lesquels on connait la quantité consommée */
		if montant < 0 then delete ;
		if quantite = . then delete;
		/* On détermine le prix au litre */
		if unite = "L" then prix_litre = montant / quantite ; 
		if prix_litre = . then delete;
		if dec_aj = '' then delete ;
		if nomen5 = "02131" then output; /*bière*/
		run;
	/*On crée la table avec les prix moyens par décile*/
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

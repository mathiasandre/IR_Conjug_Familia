/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*																					   */
/*  	          IMPUTATION DE LA STRUCTURE DE CONSOMMATION DANS INES 		           */
/*																					   */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/* Le programme impute des donn�es de consommation dans le mod�le INES : construction des
strates (choix des variables, nombre de strates, nombre minimum d'observations par strate),
dans BDF puis INES et calcul des taux de consommation (sur 261 postes) par strates*/

/* Tables d'entr�es : 
		- base20&anr2. 
		- ressources_erfs			
		- travail.mrf&anr.e&anr.														*/

/* Table de sortie : 
		- taxind.conso_imput (consommation imput�e par ident : obs = m�nage)			*/ 

/* Le programme comporte 4 �tapes : 	
/*	I   - Choix des variables et construction des strates dans BDF (base20&anr2.)        */ 
/* 	II  - Calcul des taux de consommation par strates dans BDF			                 */  
/* 	III - Construction de strates identiques dans ERFS                    		 		 */ 
/*  IV  - Imputation des taux de consommation dans ERFS                                  */ 
							                    
/*****************************************************************************************/


/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                                                                              */  
/*                       I - Choix des variables et construction des strates dans BDF                           */
/*                                                                                                              */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

data base20&anr2. ; 
	set base20&anr2. ;
	/****************** Pr�paration et s�lection des variables  ******************/
	/* Statut d'occupation du logement */
	if stalog in ('2') then occlog = '1' ; /* propri�taire */
	else if stalog in ('1', '3', '4', '5', '6') then occlog = '2' ; /* autre */
	/* R�gion d'habitation */
	if zeat in ('1') then reg = '1' ; /* R�gion parisienne */
	else reg = '2' ;
	/* Taille de l'unit� urbaine */
	if tuu in ('6', '7', '8') then uu = '1' ; /* Unit� urbaine sup�rieure � 100 000 hab */
	else uu = '2' ;
/************************* Constitution des modalit�s de strates (71 strates) **********************************/
	format strate $4. ;
	if typmen7 ='5' then strate = '5000' ; /* M�nages complexes */
	else if typmen7 = '2' then strate = typmen7!!dec_aj!!'0' ; /* familles monoparentales */
	else strate = typmen7!!dec_aj!!occlog ; /* autres cas de figure */
run;

/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                                                                              */  
/*                          II - Taux de consommation par strates dans BDF                                      */
/*                                                                                                              */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/	

/***** Agr�gation par strates *****/
%Sum_by_Class(base20&anr2., strate, pondmen, revdisp_aj, revdisp_aj &liste_conso.) ;

/***** Calcul des taux de consommation par strate *****/
data base20&anr2._strate; 
	set base20&anr2._strate ; 
	%Calcul_Part(&liste_conso., revdisp_aj)
	/* Part dans le revenu disponible BDF cal�"*/
run ;

/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                                                                              */  
/*                          III - Construction de strates identiques dans ERFS                                  */
/*                                                                                                              */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/	

proc sort data = ressources_erfs ; by ident ; run ;
proc sort data = travail.mrf&anr.e&anr. ; by ident ; run ;

data ressources_erfs ;
	merge ressources_erfs (in = a)  travail.mrf&anr.e&anr. (keep = ident typmen7 logt) ;
	by ident ;
	if a ;
	/***** On modifie les variables pour obtenir les m�mes modalit�s que dans BDF *****/
	/* Statut d'occupation du logement */
	if logt in ('2') then occlog = '1' ; /* propri�taire */
	else if logt in ('1', '3', '4', '5', '6') then occlog = '2' ; /* autre */
	/* On construit les strates */
	format strate $4. ;
	if typmen7 in ('5', '6', '9') then strate = '5000' ; /* M�nages complexes */
	else if typmen7 = '2' then strate = typmen7!!dec_aj!!'0' ; /* familles monoparentales */
	else strate = typmen7!!dec_aj!!occlog ; /* autres cas de figure */
	if length(strate) < 4 then strate = '1'!!dec_aj!!'1'; /*si une des variables typmen7 ou logt est manquante (rarissime), on prend : personne seule propri�taire */
run ;


/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                                                                              */  
/*                IV - Imputation des taux de consommation            */
/*                                                                                                              */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/	

/* Imputation des taux de consommation */
proc sql;
	create table conso as
		select *
		from ressources_erfs as a LEFT JOIN base20&anr2._strate (keep=strate part_C01111--part_C12712) as b
		on a.strate=b.strate; 
quit;

/*exportation de la table de sortie et labelisation*/
data taxind.conso_imput;
	set conso (keep = ident strate poi nb_uci dec dec_aj part: occlog revdis: logt typmen7 );
	%MACRO label_conso(ListeVar) ;
		%do i=1 %to %sysfunc(countw(&ListeVar.));
			%let n5_temp= %scan(&ListeVar.,&i.); /*nomen5*/
			%let n3_temp = %sysfunc(substr(&n5_temp.,1, 4)); /*nomen3*/
			/*on r�cup�re les labels dans la table consommation*/
			%let dsid=%sysfunc(open(consommation,i)); /*num�ro de la table*/
			%let num_var = %sysfunc(varnum(&dsid.,%scan(&ListeVar.,&i.))); /*num�ro de la variable*/
			%let label_var=%unquote(%sysfunc(varlabel(&dsid.,&num_var.))); /*label*/
			 %let rc = %sysfunc(close(&dsid.)); /*fermeture de la table*/
			/*%unquote est n�cessaire pour imprimer les labels avec des ' ou " */
			label part_%scan(&ListeVar.,&i.) = &label_var.;
		%end;
	%MEND label_conso;
	%label_conso(&liste_conso.);
run ;


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

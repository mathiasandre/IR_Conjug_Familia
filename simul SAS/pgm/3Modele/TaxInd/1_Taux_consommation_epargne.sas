/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*			 						      */
/* TAUX DE CONSOMMATION ET D'EPARGNE      */
/*				 					      */
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/* Le programme permet de calculer les taux de consommation et d'�pargne � l'issue de l'appariement avec INES, pour v�rifier que les agr�gats 
et les taux de consommation et d'�pargne sont coh�rents avec la CN et INES   */

/* Tables d'entr�es : 
		- taxind.conso_imput 
		- modele.basemen
*/

/* Table de sortie : 
		- work.basemen_BDF 
		- work.basemen_BDF_decile 
		- work.basemen_BDF_agrege                                                      	  */ 
	   
/******************************************************************************************/

/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/
/*                                                     	*/  
/* Calcul des consommations avec revenu disponible Ines */
/*                                             			*/  
/*XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX*/

/*on multiplie le revenu disponible simul� par Ines par les parts de consommation en 128 postes */
proc sql;
	create table basemen_BDF as
	select distinct a.uci, a.poi, a.revdisp, a.etud_pr, a.nbp, a.revdisp_ajuste, b.*
	from modele.basemen as a LEFT JOIN  taxind.conso_imput (keep = ident strate part: typmen7 occlog) as b
	on a.ident = b.ident;
quit;

data basemen_BDF ; 
	set basemen_BDF ;
		NdV = revdisp/ uci;
		poiind = poi*nbp ;
		%ListXVar(ListeVar=&liste_part., my_var=revdisp, ListeNom=&liste_conso.) ;
	where revdisp > 0 ;
	/* Agr�gation des d�penses en grandes fonctions de consommation */
	%MACRO sum_conso(fin); 
		%do i = 1 %to &fin. ; C0&i. = sum (of C0&i.:); %end; 
	%MEND sum_conso;
	%sum_conso(fin=9);
	/*on ne fait pas de boucle pour les trois ci-dessous 
		car une macro en C: cr�e des bugs si elle est appliqu�e deux fois*/
	C10 = sum(of C10:);
	C11 = sum(of C11:);
	C12 = sum(of C12:);
	/* Consommation totale */
	conso_tot = sum(0, C01, C02, C03, C04, C05, C06, C07, C08, C09, C10, C11, C12) ;
	/*r�cup�ration des labels des variables part_CXXXXX vers les variables CXXXXX */
	%MACRO label_part(ListeVar) ;
		%do i=1 %to %sysfunc(countw(&ListeVar.));
			/*on r�cup�re les labels dans la table taxind.conso_imput*/
			%let dsid=%sysfunc(open(taxind.conso_imput,i)); /*num�ro de la table*/
			%let num_var = %sysfunc(varnum(&dsid.,%scan(&ListeVar.,&i.))); /*num�ro de la variable*/
			%let label_var=%unquote(%sysfunc(varlabel(&dsid.,&num_var.))); /*label*/
			/*%unquote est n�cessaire pour imprimer les labels avec des ' ou " */
			%let rc = %sysfunc(close(&dsid.)); /*fermeture de la table*/
			label %sysfunc(scan(%scan(&ListeVar.,&i.),2, '_')) = &label_var.;
			/*avec la fonction scan, on prend les secondes parties des mots 'part_CXXXXX' avec pour s�parateur '_' => variables CXXXX */
		%end;
	%MEND label_part;
	%label_part(&liste_part.);
run ;

/* construction des d�ciles de niveau de vie, �chelle individus */
%quantile(10,basemen_BDF,NdV,poiind,decile);

/*agr�gation par d�cile*/
%Sum_by_Class(basemen_BDF, decile, poi, revdisp,  revdisp conso_tot &liste_conso_12.) ;

/*agr�gation totale*/
proc means 
	data=  basemen_BDF(where = (revdisp> 0)) noprint;
	var revdisp conso_tot &liste_conso_12. ;
	weight poi ;
	output out=basemen_BDF_agrege (drop=_type_ _freq_)  sum= ;
	run ;

/***** Calcul des taux de consommation et �pargne *****/
%Macro tx_conso_epargne(table) ;
data &table. ; 
	set &table. ; 
	/* Part dans le revenu disponible Ines */
	%Calcul_Part(&liste_conso_12., revdisp);
	if revdisp=0 then part_conso_tot = 0;
	else part_conso_tot = conso_tot/revdisp;
	label part_conso_tot= "Part de la consommation totale dans le revenu disponible Ines" ;
	tx_epargne = 1 - part_conso_tot ;
	label tx_epargne = "Taux d'�pargne" ;
	/* Part en % de la consommation totale  */
	%Calcul_Part(&liste_conso_12., conso_tot, suffixe = _C); 
	run ;
%Mend tx_conso_epargne ;

%tx_conso_epargne(basemen_BDF_decile) ; /* d�ciles */
%tx_conso_epargne(basemen_BDF_agrege) ; /* agr�g� */
 
/*copie de la table dans la librairie taxind*/
data taxind.basemen_BDF ;	set basemen_BDF; run;

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

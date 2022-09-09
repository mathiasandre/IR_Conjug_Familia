/************************************************************************************/
/*																															*/
/*						Modele d'imputation de la consommation BDF							*/
/*																															*/
/************************************************************************************/

/*ce programme rassemble le bloc du module de taxation indirecte effectuant 
l'imputation des données de consommation de l'enquête BDF => se reporter au wiki ou au document de travail */
/*Attention : contrairement aux autres programmes d'Ines, les sous-programmes du module ne sont pas indépendants les uns des autres (tables dans la work entre deux)*/

/* Tables utilisées (entrées et sorties) par programme (voir les en-têtes de chaque programme pour des précisions) : 
		1) pour 1_calage_consommation
				Entrées: 
					- bdf&anBDF..C05 
					- bdf&anBDF..C06 
					- bdf&anBDF..a04 
					- bdf&anBDF..menage 
					- Compta_nat_nomen3.xls  (fichier paramètres)
				Sorties :
					- work.consommation
					- work.conso_aj
		2) pour 2_calage revenus
				Entrées: 
					- bdf&anBDF..menage
					- bdf&anBDF..C05 
					- bdf&anBDF..depmen
					- work.conso_aj
					- rpm.menage&anr.
					- revdisp_ines_taxind.xls
				Sorties :
					- base20&anr2.
					- work.ressources_erfs
					- work.coef_calage_rev
		3) pour 3_Imputation par strates
				Entrées: 
					- base20&anr2. 
					- work.ressources_erfs							
					- travail.mrf&anr.e&anr. 
				Sorties :
					- taxind.conso_imput	
		3) pour 4_calcul prix moyens (Hors CASD uniquement)
				Entrées: 
					- bdf&anBDF..carnets 
					- bdf&anBDF..carnets6 
					- base20&anr2.   
				Sorties :
					- dossier.prix_moyen_&anBDF. 
					- dossier.prix_&anBDF._vin 
					- dossier.prix_&anBDF._biere
*/

%macro champ_imputBDF;
	%if &inclusion_TaxInd.=oui %then %do; 
		%include "&imputation.\imputation BDF\1_calage consommation.sas";
		%include "&imputation.\imputation BDF\2_calage revenus.sas"; 		
		%include "&imputation.\imputation BDF\3_Imputation par strates.sas";
		%include "&imputation.\imputation BDF\4_Calcul prix moyens.sas";
		%include "&imputation.\imputation BDF\5_Sorties_imputation BDF.sas";
	%end;
%mend;
%champ_imputBDF;

proc datasets mt=data library=work kill;run;quit;


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

/************************************************************************************/
/*																															*/
/*						Modele d'imputation de la consommation BDF							*/
/*																															*/
/************************************************************************************/

/*ce programme rassemble le bloc du module de taxation indirecte effectuant 
l'imputation des donn�es de consommation de l'enqu�te BDF => se reporter au wiki ou au document de travail */
/*Attention : contrairement aux autres programmes d'Ines, les sous-programmes du module ne sont pas ind�pendants les uns des autres (tables dans la work entre deux)*/

/* Tables utilis�es (entr�es et sorties) par programme (voir les en-t�tes de chaque programme pour des pr�cisions) : 
		1) pour 1_calage_consommation
				Entr�es: 
					- bdf&anBDF..C05 
					- bdf&anBDF..C06 
					- bdf&anBDF..a04 
					- bdf&anBDF..menage 
					- Compta_nat_nomen3.xls  (fichier param�tres)
				Sorties :
					- work.consommation
					- work.conso_aj
		2) pour 2_calage revenus
				Entr�es: 
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
				Entr�es: 
					- base20&anr2. 
					- work.ressources_erfs							
					- travail.mrf&anr.e&anr. 
				Sorties :
					- taxind.conso_imput	
		3) pour 4_calcul prix moyens (Hors CASD uniquement)
				Entr�es: 
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

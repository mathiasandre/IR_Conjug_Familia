/*************************************************************************************/
/*                   			7_type_menage_Insee  			                     */
/*************************************************************************************/

/*************************************************************************************/
/* On cr�e une variable qui correspond � la classification des m�nages selon l'Insee */
/*																					 */
/* Table en entr�e : travail.mrf&anr.e&anr.											 */
/*																					 */
/* Table en sortie : travail.menage&anr.					 						 */
/*************************************************************************************/

data typmen;
	set travail.mrf&anr.e&anr. (keep=ident typmen7 nbenfc nbenfnc);

	length typmen_Insee $2 ;
	/* m�nages complexes */
	/* on classe en m�nages complexes les personnes avec des enfants non c�libataires. idem INSEE */
		if (typmen7 in ("5" "6" "9") or nbenfnc>0) and nbenfc=0 then typmen_Insee="30"; 
		else if (typmen7 in ("5" "6" "9") or nbenfnc>0) and nbenfc>0 then typmen_Insee="31";
	/* personnes seules */
		else if typmen7="1" then typmen_Insee="10"; 
	/* familles monoparentales */
		else if typmen7="2" and nbenfc=1 then typmen_Insee="11";
		else if typmen7="2" and nbenfc=2 then typmen_Insee="12";
		else if typmen7="2" and nbenfc>2 then typmen_Insee="13";
	/* couples sans enfants */
		else if typmen7="3" then typmen_Insee="20";
	/* couples avec enfants */
		else if typmen7="4" and nbenfc=1 then typmen_Insee="21";
		else if typmen7="4" and nbenfc=2 then typmen_Insee="22";
		else if typmen7="4" and nbenfc>2 then typmen_Insee="23";
	/* rattrapage de cas aberrants (peu nombreux) pour �viter les valeurs manquantes */
		else if nbenfnc=0 and nbenfc=0 then typmen_Insee="30" ;

run; 

proc sort data=travail.menage&anr.; by ident; run;
proc sort data=typmen; by ident; run;

data travail.menage&anr.;
	merge travail.menage&anr.
		  typmen (keep=ident typmen_Insee);
	by ident;
run;

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

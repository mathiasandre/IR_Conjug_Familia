/*************************************************************************************/
/*                   			7_type_menage_Insee  			                     */
/*************************************************************************************/

/*************************************************************************************/
/* On crée une variable qui correspond à la classification des ménages selon l'Insee */
/*																					 */
/* Table en entrée : travail.mrf&anr.e&anr.											 */
/*																					 */
/* Table en sortie : travail.menage&anr.					 						 */
/*************************************************************************************/

data typmen;
	set travail.mrf&anr.e&anr. (keep=ident typmen7 nbenfc nbenfnc);

	length typmen_Insee $2 ;
	/* ménages complexes */
	/* on classe en ménages complexes les personnes avec des enfants non célibataires. idem INSEE */
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
	/* rattrapage de cas aberrants (peu nombreux) pour éviter les valeurs manquantes */
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

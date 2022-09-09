*************************************************************************************;
/*																					*/
/*									4_calage_AEEH									*/
/*								 													*/
*************************************************************************************;

/* Programme de tirage du degré d'handicap pour les enfants : on cale sur les marges 
des  bénéficiaires de l'AEEH														*/
/* En entrée : travail.menage&anr. 													*/
/*			   imput.enfant_h					               						*/
/* En sortie : imput.enfant_h                                     					*/

/* NOTE : 
	- Le complément d'AEEH s'échelonne en 6 catégories en fonction du handicap.
Ce que l'on appelle la catégorie 0 est en fait le montant de base de l'AEEH.		*/ 


data tirage_categ_AEEH; 
	set imput.enfant_h (keep=wpela&anr. ident noi handicap_e);
	select (handicap_e);
		when ('source CNAF') 		classement=ranuni(1);
		when ('source fiscale') 		classement=2*ranuni(1);
		when ('tirage au sort') 	classement=3*ranuni(1);
		end;
	/*On crée un aléa favorisant les handicaps de source plus sûre, comme la CAF plutôt que les tirages*/
	run;

proc sort data=tirage_categ_AEEH; by classement;run; 
data tirage_categ_AEEH; 
	set tirage_categ_AEEH;
	retain co 0;
	co=co+wpela&anr.;
	if co<&maraeeh00. then categ='0';
	else if co<&maraeeh00.+&maraeeh01. then categ='1';
	else if co<&maraeeh00.+&maraeeh01.+&maraeeh02. then categ='2';
	else if co<&maraeeh00.+&maraeeh01.+&maraeeh02.+&maraeeh03. then categ='3';
	else if co<&maraeeh00.+&maraeeh01.+&maraeeh02.+&maraeeh03.+&maraeeh04. then categ='4';
	else if co<&maraeeh00.+&maraeeh01.+&maraeeh02.+&maraeeh03.+&maraeeh04.+&maraeeh05. then categ='5';
	else if co<&maraeeh00.+&maraeeh01.+&maraeeh02.+&maraeeh03.+&maraeeh04.+&maraeeh05.+&maraeeh06. then categ='6';
	else do;
		categ='';
		end;
	label categ="Catégorie du complément d'AEEH";
	run;


/* Sauvegarde */
proc sort data=tirage_categ_AEEH; by ident noi; run; 
data imput.enfant_h;
	set tirage_categ_AEEH(keep=ident noi handicap_e categ wpela&anr.);
	by ident noi;
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

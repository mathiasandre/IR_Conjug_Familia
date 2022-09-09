*************************************************************************************;
/*																					*/
/*									4_calage_AEEH									*/
/*								 													*/
*************************************************************************************;

/* Programme de tirage du degr� d'handicap pour les enfants : on cale sur les marges 
des  b�n�ficiaires de l'AEEH														*/
/* En entr�e : travail.menage&anr. 													*/
/*			   imput.enfant_h					               						*/
/* En sortie : imput.enfant_h                                     					*/

/* NOTE : 
	- Le compl�ment d'AEEH s'�chelonne en 6 cat�gories en fonction du handicap.
Ce que l'on appelle la cat�gorie 0 est en fait le montant de base de l'AEEH.		*/ 


data tirage_categ_AEEH; 
	set imput.enfant_h (keep=wpela&anr. ident noi handicap_e);
	select (handicap_e);
		when ('source CNAF') 		classement=ranuni(1);
		when ('source fiscale') 		classement=2*ranuni(1);
		when ('tirage au sort') 	classement=3*ranuni(1);
		end;
	/*On cr�e un al�a favorisant les handicaps de source plus s�re, comme la CAF plut�t que les tirages*/
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
	label categ="Cat�gorie du compl�ment d'AEEH";
	run;


/* Sauvegarde */
proc sort data=tirage_categ_AEEH; by ident noi; run; 
data imput.enfant_h;
	set tirage_categ_AEEH(keep=ident noi handicap_e categ wpela&anr.);
	by ident noi;
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

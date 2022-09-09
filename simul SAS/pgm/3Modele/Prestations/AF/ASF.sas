/************************************************************************************/
/*																					*/
/*								ASF													*/
/*																					*/
/************************************************************************************/

/* Mod�lisation de l'allocation de soutien familial                	*/
/********************************************************************/
/* En entr�e : modele.basefam										*/	
/* En sortie : modele.basefam                                      	*/
/********************************************************************/

data modele.basefam;
	set	modele.basefam;
	%nb_enf(e_c,0,&age_pf.,age_enf);
	asf=0;
	asf_horsReval2014=0;
	if elig_asf='oui' then do;
		asf=max(0,&asf1.*&bmaf.*e_c*12-pensrecu); /* On introduit un max, m�me si du fait de la s�lection des �ligibles la pension ne devrait pas 
		�tre sup�rieure � l'ASF et donc on ne devrait pas avoir de valeurs n�gatives. */
		asf_horsReval2014=max(0,&asf1_av2014.*&bmaf.*e_c*12-pensrecu); /* on anticipe ici plus facilement sur le calcul de la BR du RSA */
		end;
	label asf="Allocation de soutien familial";
	label asf_horsReval2014="Allocation de soutien familial avant la revalorisation exceptionnelle de 2014";
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

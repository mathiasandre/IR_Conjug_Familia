/************************************************************************************/
/*																					*/
/*								ASF													*/
/*																					*/
/************************************************************************************/

/* Modélisation de l'allocation de soutien familial                	*/
/********************************************************************/
/* En entrée : modele.basefam										*/	
/* En sortie : modele.basefam                                      	*/
/********************************************************************/

data modele.basefam;
	set	modele.basefam;
	%nb_enf(e_c,0,&age_pf.,age_enf);
	asf=0;
	asf_horsReval2014=0;
	if elig_asf='oui' then do;
		asf=max(0,&asf1.*&bmaf.*e_c*12-pensrecu); /* On introduit un max, même si du fait de la sélection des éligibles la pension ne devrait pas 
		être supérieure à l'ASF et donc on ne devrait pas avoir de valeurs négatives. */
		asf_horsReval2014=max(0,&asf1_av2014.*&bmaf.*e_c*12-pensrecu); /* on anticipe ici plus facilement sur le calcul de la BR du RSA */
		end;
	label asf="Allocation de soutien familial";
	label asf_horsReval2014="Allocation de soutien familial avant la revalorisation exceptionnelle de 2014";
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

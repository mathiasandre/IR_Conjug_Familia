*************************************************************************************;
/*																					*/
/*									7_baseind_fin									*/
/*								 													*/
*************************************************************************************;

/* Agr�gation des tables d'imputations 								*/
/* En entr�e : base.baseind 										*/
/*			   imput.calendrier					                 	*/
/*			   imput.handicap					                 	*/
/*			   imput.enfant_h					                 	*/
/*			   imput.form						                 	*/
/*			   imput.aspa_asi						               	*/
/*			   imput.a_naitre						               	*/
/*			   imput.effectif						               	*/
/* En sortie : base.baseind                                     	*/

proc sort data=base.baseind; by ident noi;run;
data base.baseind; 
	merge 	base.baseind (in=a)
			imput.calendrier(in=b keep=ident noi cal0)
			imput.handicap(in=c)
			imput.enfant_h(in=d)
			imput.form(in=e)
			imput.aspa_asi(in=f)
			imput.effectif (keep=ident noi effi);
	by ident noi;
	if a or b or c or d or e or f;
	if handicap=. then handicap=0;
	label handicap = "source du handicap de l'adulte";
	label handicap_e = "source du handicap de l'enfant";
	label niv = "niveau de formation initiale en cours";
	label form = "type de formation initiale suivie";
	label elig_aspa_asi = "�ligibilit� � l'ASPA ou � l'ASI";
	run; 

/* Ajout des enfants � naitre. On leur attribue seulement leur declar1, leurs poids, un naia �gal � &anref + 1, le rep�re enf_1
	et un noi construit	comme le num�ro suivant le dernier noi de leur m�nage */
data a_naitre (drop=nai);
	merge	base.baseind (in=a keep=ident noi wpela: declar1 quelfic)
			imput.a_naitre (in=b keep=ident mois_1);
	by ident;
	if last.ident & b;
	noi=noi+1;
	enf_1=1;
	nai=&anref.+1;
	naia=putn(nai,4);
	naim=mois_1;
	label enf_1 = "enfant � naitre";
	label mois_1 = "mois de naisance de l'enfant � naitre";
	run;

data base.baseind;
	set		base.baseind (in=a)
			a_naitre;
	run;

proc sort data=base.baseind nodupkeys; by ident noi; run; /* on enl�ve les doublons �ventuels (ne devraient pas exister) */


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

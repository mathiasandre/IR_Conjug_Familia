*************************************************************************************;
/*																					*/
/*									7_baseind_fin									*/
/*								 													*/
*************************************************************************************;

/* Agrégation des tables d'imputations 								*/
/* En entrée : base.baseind 										*/
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
	label elig_aspa_asi = "éligibilité à l'ASPA ou à l'ASI";
	run; 

/* Ajout des enfants à naitre. On leur attribue seulement leur declar1, leurs poids, un naia égal à &anref + 1, le repère enf_1
	et un noi construit	comme le numéro suivant le dernier noi de leur ménage */
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
	label enf_1 = "enfant à naitre";
	label mois_1 = "mois de naisance de l'enfant à naitre";
	run;

data base.baseind;
	set		base.baseind (in=a)
			a_naitre;
	run;

proc sort data=base.baseind nodupkeys; by ident noi; run; /* on enlève les doublons éventuels (ne devraient pas exister) */


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

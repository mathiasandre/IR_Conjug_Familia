/**************************************************/
/*			Programme 3_suppression               */ 
/**************************************************/

/**************************************************************************************************************/
/* Tables en entr�e :                                                                                         */
/*	travail.foyer&anr.																						  */		
/*  travail.irf&anr.e&anr																					  */
/*  travail.mrf&anr.e&anr																					  */
/*  travail.indivi&anr.																						  */
/*  travail.indfip&anr.																						  */
/*  travail.menage&anr.																				          */
/* 																											  */
/* Tables en sortie :																						  */
/*	travail.foyer&anr.																						  */
/*  travail.irf&anr.e&anr																					  */
/*  travail.mrf&anr.e&anr																					  */
/*  travail.indivi&anr.																						  */
/*  travail.indfip&anr.																			              */
/*  travail.menage&anr.																						  */
/*																											  */
/* Objectif : Dans ce programme, on supprime des diff�rentes tables de la biblioth�que travail,               */
/*  les m�nages que l'on consid�re comme mal renseign�s.													  */	   
/**************************************************************************************************************/


/* 2007 : pas de suppression */
/* 2008 : � v�rifier */
%suppression(2008, '08060647' '08061140' '08025253' '08003217'); /* dernier cas : d�claration incoh�rente */
/* 2009 : � v�rifier */
%suppression(2009, '09075423' '09083751' '09035373' '09005688' '09067408'
'09064321' '09072842' '09063847' '09069640' '09060689' '09059582' '09090548'); 
*09075423 :;
*09083751 : d�claration pas du tout coh�rente : m�nage mal appari�. on a 5 personnes dans le m�nage. 
le noi=01 est divorc�, vit avec ses 3 enfants et noi=05 qui lui par ailleurs est mari� et a deux enfants.
seulement, au lieu d'attribuer aux enfants du m�nage la d�claration fiscal de noi=01,
on leur a attribu� la d�claration de noi=05. 
ce qui fait que les dates de naissances ne correspondent paset du coup on a un enfant EE. 
de plus, on a le conjoint de noi=5 qui est FIP (sans d�claration) 
mais il manque les enfants FIP de la d�claration fiscale du noi=05... 
* 09035373 : n'a pas de date de naissance; 
* 09067408 : cas de changements de situations 2 fois dans l'ann�e; 
* 09072842  09063847 09069640 09059582 09060689: il manque une d�claration dans foyer mais qui appara�t dans indivi; 
*09064321;
*09090548 : un mariage tr�s mal d�clar� et difficile � corriger;

/* 2010 : � v�rifier */
%suppression(2010, '10057394' '10064012' '10028278' '10037406' '10033118' '10067534'
		     '10022576' '10026364' '10027607' '10035210' '10044711' '10050285'
			 '10055173' '10097007' '10104040' '10050285'
			 '10023257'
			 '10028278'); 
/* 10057394, 10064012 : cas d'un mariage et d'un d�c�s dans l'ann�e
   10028278, 10037406, 10033118, 10067534 : cas d'un mariage et d'un divorce dans l'ann�e
   10022576, 10026364, 10027607, 10035210, 10044711, 10050285, 10055173, 10097007, 10104040, 10050285 : ces cas
   correspondent � des d�cla avec des �v�nements dans l'ann�e. 
   Ils ont deux d�clarations, l'�v�nement d�clar� est diff�rent dans chacune des d�clarations et leur statut matri
   ne correspond pas aux �v�nements d�clar�s 
   10023257 : m�nage avec un individu EE&FIP et un individu EE sans date de naissance
   10028278 : m�nage avec un wpela manquant => fait bugger un cumul (calage_AEEH) */


/* 2011 */
%suppression(2011, '11100652' '11071110' '22018020' '11022595' '11049988' '11056636');
/* 11100652 = observations avec pond�ration aberrante de plus de 11000 */
/* 11071110 = ce m�nage avec des EE_NRT ne devrait pas �tre dans le champ de l'ERFS (acteupr ne '5') */
/* 4 derniers m�nages : constitu�s d'EE_CAF aux declar1 vides */


/* 2012 */
%suppression(2012, 	'12087434' '12087879' '12090212' '12093380' '12094155' '12095263' '12094121' '12099207'
					'12064152' '12075285' '12076696' '12078285' '12078382' '12080793' '12105363' '12110967' '12111048');

/* 1ere ligne : La pr�sence de 10 observations de la table indiv2012_ela sans correspondance dans la table foyer12_ela 
provient d�un d�faut de la collecte 2013 de l�enqu�te Emploi. En effet, certains m�nages enqu�t�s 6 fois 
auraient �t� de nouveau enqu�t�s sous un identifiant(nomen) diff�rent.
Des doublons sont ainsi pr�sents dans la table indiv2012_ela. Ces 10 observations (8 m�nages) sont � supprimer. 

2e ligne : 9 m�nages pr�sents dans foyer12_ela ont les variables Declar1 et Declar2 � blanc dans indiv2012_ela.
Il s�agit l� d�une erreur qui persiste depuis la mise en place d�Ines. 
Le souci se situe au niveau de la correction de la non r�ponse pour les m�nages dont la personne de r�f�rence 
est �tudiante (table EEC : cstotprm= � 84 �). Toutes les personnes du m�nage sont consid�r�es non appari�es. 
Declar1 et Declar2 se retrouvent � blanc, les montants de revenus �galement et ceci pour tous les membres de ces m�nages. 
Or dans ces 9 m�nages, au moins une personne est d�clarante. */

/* 2013 */
%Suppression(2013, '13009267');


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

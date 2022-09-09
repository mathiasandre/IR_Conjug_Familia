/**************************************************/
/*			Programme 3_suppression               */ 
/**************************************************/

/**************************************************************************************************************/
/* Tables en entrée :                                                                                         */
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
/* Objectif : Dans ce programme, on supprime des différentes tables de la bibliothèque travail,               */
/*  les ménages que l'on considère comme mal renseignés.													  */	   
/**************************************************************************************************************/


/* 2007 : pas de suppression */
/* 2008 : à vérifier */
%suppression(2008, '08060647' '08061140' '08025253' '08003217'); /* dernier cas : déclaration incohérente */
/* 2009 : à vérifier */
%suppression(2009, '09075423' '09083751' '09035373' '09005688' '09067408'
'09064321' '09072842' '09063847' '09069640' '09060689' '09059582' '09090548'); 
*09075423 :;
*09083751 : déclaration pas du tout cohérente : ménage mal apparié. on a 5 personnes dans le ménage. 
le noi=01 est divorcé, vit avec ses 3 enfants et noi=05 qui lui par ailleurs est marié et a deux enfants.
seulement, au lieu d'attribuer aux enfants du ménage la déclaration fiscal de noi=01,
on leur a attribué la déclaration de noi=05. 
ce qui fait que les dates de naissances ne correspondent paset du coup on a un enfant EE. 
de plus, on a le conjoint de noi=5 qui est FIP (sans déclaration) 
mais il manque les enfants FIP de la déclaration fiscale du noi=05... 
* 09035373 : n'a pas de date de naissance; 
* 09067408 : cas de changements de situations 2 fois dans l'année; 
* 09072842  09063847 09069640 09059582 09060689: il manque une déclaration dans foyer mais qui apparaît dans indivi; 
*09064321;
*09090548 : un mariage très mal déclaré et difficile à corriger;

/* 2010 : à vérifier */
%suppression(2010, '10057394' '10064012' '10028278' '10037406' '10033118' '10067534'
		     '10022576' '10026364' '10027607' '10035210' '10044711' '10050285'
			 '10055173' '10097007' '10104040' '10050285'
			 '10023257'
			 '10028278'); 
/* 10057394, 10064012 : cas d'un mariage et d'un décès dans l'année
   10028278, 10037406, 10033118, 10067534 : cas d'un mariage et d'un divorce dans l'année
   10022576, 10026364, 10027607, 10035210, 10044711, 10050285, 10055173, 10097007, 10104040, 10050285 : ces cas
   correspondent à des décla avec des événements dans l'année. 
   Ils ont deux déclarations, l'événement déclaré est différent dans chacune des déclarations et leur statut matri
   ne correspond pas aux événements déclarés 
   10023257 : ménage avec un individu EE&FIP et un individu EE sans date de naissance
   10028278 : ménage avec un wpela manquant => fait bugger un cumul (calage_AEEH) */


/* 2011 */
%suppression(2011, '11100652' '11071110' '22018020' '11022595' '11049988' '11056636');
/* 11100652 = observations avec pondération aberrante de plus de 11000 */
/* 11071110 = ce ménage avec des EE_NRT ne devrait pas être dans le champ de l'ERFS (acteupr ne '5') */
/* 4 derniers ménages : constitués d'EE_CAF aux declar1 vides */


/* 2012 */
%suppression(2012, 	'12087434' '12087879' '12090212' '12093380' '12094155' '12095263' '12094121' '12099207'
					'12064152' '12075285' '12076696' '12078285' '12078382' '12080793' '12105363' '12110967' '12111048');

/* 1ere ligne : La présence de 10 observations de la table indiv2012_ela sans correspondance dans la table foyer12_ela 
provient d’un défaut de la collecte 2013 de l’enquête Emploi. En effet, certains ménages enquêtés 6 fois 
auraient été de nouveau enquêtés sous un identifiant(nomen) différent.
Des doublons sont ainsi présents dans la table indiv2012_ela. Ces 10 observations (8 ménages) sont à supprimer. 

2e ligne : 9 ménages présents dans foyer12_ela ont les variables Declar1 et Declar2 à blanc dans indiv2012_ela.
Il s’agit là d’une erreur qui persiste depuis la mise en place d’Ines. 
Le souci se situe au niveau de la correction de la non réponse pour les ménages dont la personne de référence 
est étudiante (table EEC : cstotprm= « 84 »). Toutes les personnes du ménage sont considérées non appariées. 
Declar1 et Declar2 se retrouvent à blanc, les montants de revenus également et ceci pour tous les membres de ces ménages. 
Or dans ces 9 ménages, au moins une personne est déclarante. */

/* 2013 */
%Suppression(2013, '13009267');


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

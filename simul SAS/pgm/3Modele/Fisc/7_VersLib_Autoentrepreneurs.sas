/****************************************************************************/
/*																			*/
/*  Versement lib�ratoire du r�gime des auto-entrepreneurs qui optent pour  */
/*																			*/
/****************************************************************************/

/*	En entr�e :	modele.rev_imp&anr.
				modele.rev_imp&anr1.
				base.foyer&anr2.
	En sortie : modele.VersLibAE */

/* 	Le code de l'�ligibilit� au versement lib�ratoire des autoentrepreneurs est dans le programme Prelev_Forf.sas
	Il figure dans ce programme car il doit tourner deux fois dans Ines, une fois pour l'ann�e N-1 et une fois pour l'ann�e N (=anleg). 
	Le pr�sent programme s'appuie sur l'�ligibilit� en N pour calculer le montant du versement en N. 
	La l�gislation de ce versement est d�taill�e en commentaire de Prelev_Forf.sas. */

proc sql;
	create table modele.VersLibAE as
	select 	a.declar, a.AE_eliPFL&anr2., b.mcdvo, b.ident, 
			b._5ta, b._5ua, b._5va, b._5tb, b._5ub, b._5vb, b._5te, b._5ue, b._5ve
	from modele.rev_imp&anr1. as a
		inner join base.foyer&anr2. as b on a.declar=b.declar;
	quit;

data modele.VersLibAE (keep=ident declar Verslib_AutoEntr);
	set modele.VersLibAE;

	%Init_Valeur(Verslib_AutoEntr);
	if AE_eliPFL&anr2. then Verslib_AutoEntr=	&tx_auto_march.*(_5ta+_5ua+_5va)+
												&tx_auto_serv.*(_5tb+_5ub+_5vb)+
												&tx_auto_bnc.*(_5te+_5ue+_5ve);

	label Verslib_AutoEntr="Versement lib�ratoire des auto-entrepreneurs";
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

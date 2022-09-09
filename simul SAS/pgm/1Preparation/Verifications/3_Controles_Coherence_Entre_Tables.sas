/****************************************************************************************/
/*																						*/
/*					3_Controles_Coherence_Entre_Tables									*/
/*																						*/
/****************************************************************************************/



/* Contr�les de coh�rence entre les tables, principalement sur les identifiants ident, noi, declar. */
/****************************************************************************************/
/* En entr�e : travail.indivi&anr.														*/
/*			   travail.indfip&anr.					          							*/
/*			   travail.menage&anr.					          							*/
/*			   travail.foyer&anr.					          							*/
/*			   travail.irf&anr.e&anr.				          							*/
/****************************************************************************************/
/* PLAN : 																				*/
/* 1. On retrouve tous les ident de travail.indivi&anr. dans travail.menage&anr.		*/
/* 2. On retrouve tous les ident,noi de travail.indivi&anr. dans travail.irf&anr.e&anr. */
/* et r�ciproquement 																	*/
/* 3. On retrouve tous les declar de travail.indivi&anr. dans travail.foyer&anr.		*/
/* 4. On retrouve tous les declar de travail.foyer&anr. dans travail.indivi&anr. 		*/
/* 5. Coh�rence entre les revenus de la table individu et de la table m�nage			*/
/****************************************************************************************/

data indivi&anr.; set travail.indivi&anr. travail.indfip&anr.; run; 
proc sort data=indivi&anr. nodupkey; by ident noi; run;
proc sort data=travail.menage&anr. out=menage&anr.; by ident; run;
proc sort data=travail.irf&anr.e&anr.(keep=ident noi) out=irf&anr.e&anr.; by ident noi; run;
proc sort data=travail.foyer&anr.(keep=sif declar anaisenf ident) out=foyer&anr.; by declar; run;

/****************************************************************************************/
/* 1. On retrouve tous les ident de travail.indivi&anr. dans travail.menage&anr.		*/
/****************************************************************************************/
data pb_indivi&anr.;
	merge 	indivi&anr. (in=a keep=ident noi noindiv declar: quelfic persfip) 
			menage&anr. (in=b keep=ident);
	by ident;
	if a and not b then pb="Individu appartenant � un m�nage 'ident' absent de la table m�nage";
	/* Si les individus sont dans les fichiers fiscaux (quelfic prenant les valeurs ('EE&FIP' ou 'FIP'), 
	ils doivent avoir un declar1 ou un declar2 et un persfip*/
	if 	quelfic in ('EE&FIP','FIP') & declar1='' & declar2='' ! quelfic not in ('EE&FIP','FIP') & (declar1 ne '' ! declar2 ne '') 
		then pb="Incoh�rence entre 'quelfic' et 'declar1' ou 'declar2'";
	if 	(quelfic in ('EE&FIP','FIP') & persfip='') or (quelfic not in ('EE&FIP','FIP') & persfip ne '')
		then pb="Incoh�rence entre 'quelfic' et 'persfip'";
	if pb ne '';
	run;
/* 	ERFS 2010 : 0 cas
	ERFS 2011 : 0 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 0 cas 
	ERFS 2014 : 2 cas (1 m�nage) (pb3) avant corrections ; 0 cas apr�s corrections
	ERFS 2015 : 0 cas 
	ERFS 2016 : 0 cas*/

/****************************************************************************************/
/* 2. On retrouve tous les ident,noi de travail.indivi&anr. dans travail.irf&anr.e&anr. */
/* et r�ciproquement 																	*/
/****************************************************************************************/
data pb_indivi_notirf pb_irf_notindivi;
	merge 	indivi&anr.(in=a where=(quelfic ne 'FIP'))
			irf&anr.e&anr.(in=b);
	by ident noi;
	if (a & not b) then output pb_indivi_notirf ;
	if (b & not a) then output pb_irf_notindivi;
	run;
/* 	ERFS 2009 : 0 cas
	ERFS 2010 : 0 cas
	ERFS 2011 : 0 cas
	ERFS 2012 : 0 cas
	ERFS 2013 : 0 cas
	ERFS 2014 : 1720 cas avant (1140 m�nages) et 1722 apr�s correction => uniquement dans pb_irf_notindivi
	ERFS 2015 : 1554 cas avant et 1555 cas apr�s 
	ERFS 2016 : 1742 cas avant (uniquement dans pb_irf_notindivi) et autant apr�s */

/****************************************************************************************/
/* 3. On retrouve tous les declar de travail.indivi&anr. dans travail.foyer&anr.		*/
/****************************************************************************************/
proc sort data=indivi&anr. out=indivi1; by declar1; run;
data pb_declar1;
	merge 	indivi1 (in=a where=(quelfic in ('EE&FIP','FIP')) rename=(declar1=declar))
			foyer&anr.(in=b);
	by declar;
	if a and not b ; /* Un ou plusieurs EE&FIP ou FIP ont un declar1 absent de la table foyer */
	run;
/*	ERFS 2012 : 10 cas */
/*	ERFS 2013 : 3 cas (1 m�nage) */
/*	ERFS 2014 : 1534 cas avant corrections ; 0 cas apr�s */
/*	ERFS 2015 : 2251 cas avant et 0 apr�s corrections  */
/*	ERFS 2016 : 9 cas avant et 1 apr�s corrections  */

proc sort data=indivi&anr. out=indivi2; by declar2; run;
data pb_declar2;
	merge 	indivi2 (in=a where=(quelfic in ('EE&FIP','FIP')) rename=(declar2=declar))
			foyer&anr. (in=b);
	by declar;
	if a and not b and declar ne ''; /* Un ou plusieurs EE&FIP ou FIP ont un declar2 absent de la table foyer */
	run;
/*	ERFS 2012 : 0 cas */
/*	ERFS 2013 : 0 cas */
/*	ERFS 2014 : 1 cas avant corrections ; 0 cas apr�s  */
/*	ERFS 2015 : 0 cas  */
/*	ERFS 2016 : 3 cas avant corrections ; 0 cas apr�s */

/****************************************************************************************/
/* 4. On retrouve tous les declar de travail.foyer&anr. dans travail.indivi&anr. 		*/
/****************************************************************************************/
data indivi_decl;
	set indivi1(rename=(declar1=declar) drop=declar2 where=(declar ne '')) 
		indivi2(rename=(declar2=declar) drop=declar1 where=(declar ne ''));
	run;
proc sort data=indivi_decl out=indivi_decl nodupkey; by declar; run;
data pb_declar;
	merge 	foyer&anr.(keep=sif declar anaisenf ident in=a)
			indivi_decl(keep=ident noi declar in=b);
	by declar;
	if a and not b and declar ne ''; /* Un 'declar' de la table foyer n'apparait pas ni comme declar1 ni comme declar2 dans indivi */
	run;
/*	ERFS 2012 : 9 cas */
/*	ERFS 2013 : 2 cas */
/*	ERFS 2014 : 542 cas avant correction ; 0 cas apr�s */
/*	ERFS 2015 : 785 cas avant correction ; 0 cas apr�s */
/*	ERFS 2016 : 3 cas avant correction ; 0 cas apr�s */

/****************************************************************************************/
/* 5. Coh�rence entre les revenus de la table individu et de la table m�nage			*/
/****************************************************************************************/
proc summary data=indivi&anr.(where=(quelfic ne 'FIP')) noprint nway;
	class ident;
	var zsali zchoi zrsti zpii zalri zrtoi zragi zrici zrnci;
	output out=somindiv(drop=_type_ rename=_freq_=nbind)
	sum=zsalm zchom zrstm zpim zalrm zrtom zragm zricm zrncm;
	run;
proc compare 	base=somindiv
				compare=menage&anr.(keep=ident zsalm zchom zrstm zpim zalrm zrtom zragm zricm zrncm)
	out=out;
	id ident;
	run;
/* ERFS 2014 : Ok */
/* ERFS 2015 : Ok */
/* ERFS 2016 : Ok */
/* On peut ne pas avoir �galit� sur le nombre d'individus par m�nage car on retire de la table individu les enfants qui sont 
	n�s � partir de mars de &anref+1. Ils ne sont pas retir�s de menage&anr.*/

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

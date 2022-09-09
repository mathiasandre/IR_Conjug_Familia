/*************************************************************************************************/
/*   							5_trimestrialisation_ressources   							   	 */
/*************************************************************************************************/


/* Trimestrialisation des revenus utiles � partir du calendrier d'activit� (cal0)				 */

/* table en entr�e : base.baseind															     */
/*                   base.baserev																 */
/*																								 */
/* table en sortie : base.baserev																 */


proc sort data=base.baseind 
	(keep=ident noi naia cal0) out=baseind; by ident noi; run;
proc sort data=base.baserev
	(keep=ident noi zsali&anr2. zchoi&anr2. zrsti&anr2. zpii&anr2. zragi&anr2. zrici&anr2. zrnci&anr2.)
	out=baserev; by ident noi; run;

data RessTrim ;
	merge	baserev 
			baseind (in=a);
	by ident noi;
	if a ;

	/*calcul du nombre de mois d'activit�/chomage/retraite par trimestre*/
	array nbmois_salT(4) nbmois_salT1-nbmois_salT4;
	array nbmois_choT(4) nbmois_choT1-nbmois_choT4;
	array nbmois_retT(4) nbmois_retT1-nbmois_retT4;
	do i=1 to 4;
		deb=3*(5-i)-2;
		nbmois_salT(i)=count(substr(cal0,deb,3),'1');
		nbmois_choT(i)=count(substr(cal0,deb,3),'4');
		nbmois_retT(i)=count(substr(cal0,deb,3),'5');
		end;
	drop i deb;

	/*trimestrialisation des revenus cat�goriels*/
	array zsaliT(4) zsali&anr2._t1-zsali&anr2._t4;
	array zchoiT(4) zchoi&anr2._t1-zchoi&anr2._t4;
	array zrstiT(4) zrsti&anr2._t1-zrsti&anr2._t4;
	array zpiiT(4) zpii&anr2._t1-zpii&anr2._t4;
	array zindiT(4) zindi&anr2._t1-zindi&anr2._t4;

	/*salaires et assimil�s*/
	do i=1 to 4;
		if zsali&anr2.>0 then do;
			if sum(0,of nbmois_salT1-nbmois_salT4)>0 then do;
				zsaliT(i)=zsali&anr2.*nbmois_salT(i)/sum(0,of nbmois_salT1-nbmois_salT4);
				end;
			else do;
				/* Si on n'a pas de mois d'activit� salari�e, on r�partit le salaire �quitablement
				sur les 4 trimestres */
				zsaliT(i)=zsali&anr2./4;
				end;
			end;
		else do;
			zsaliT(i)=0;
			end;
		end;

	/* ch�mage*/
	do i=1 to 4;
		if zchoi&anr2.>0 then do;
			if sum(0,of nbmois_choT1-nbmois_choT4)>0 then do;
				zchoiT(i)=zchoi&anr2.*nbmois_choT(i)/sum(0,of nbmois_choT1-nbmois_choT4);
				end;
			else do; 
				zchoiT(i)=zchoi&anr2./4;
				end;
			end;
		else do;
			zchoiT(i)=0;
			end;
		end;

	/* retraites et pensions*/
	do i=1 to 4;
		if zrsti&anr2.>0 then do;
			if sum(0,of nbmois_retT1-nbmois_retT4)>0 then do;
				zrstiT(i)=zrsti&anr2.*nbmois_retT(i)/sum(0,of nbmois_retT1-nbmois_retT4);
				end;
			else do; 
				zrstiT(i)=zrsti&anr2./4;
				end;
			end;
		else do;
			zrstiT(i)=0;
			end;
		end;

	/* revenus ind�pendants : liss�s sur l'ann�e
	- HYPOTHESE : on ram�ne les d�ficits d�clar�s � 0; */
	do i=1 to 4;
		if (zragi&anr2.+zrici&anr2.+zrnci&anr2.)>0 then zindiT(i)=(zragi&anr2.+zrici&anr2.+zrnci&anr2.)/4; 
		else zindiT(i)=0;
		end;

	/*HYPOTHESE : lorsqu'un individu a moins de 50 ans ou 65 ans et plus, on r�partit ses pensions de retraite
	  sur 12 mois pour rendre compte dans le premier cas de retraites anticip�es cumulables avec des revenus d'activit�
	  (militaires�) et de pensions d'invalidit� (pouvant �tre d�clar�es dans la m�me case de la d�claration de revenus)
	  et pour le plus �g�s du fait qu'une fois la retraite prise, la pension est per�ue mensuellement.*/
	if ((&anref.-input(naia,4.))<=50) or ((&anref.-input(naia,4.))>=65) then do i=1 to 4;
		zrstiT(i)=zrsti&anr2./4;
		end;
		/*Depuis l'ERFS 2014, les pensions d'invalidit� ont leur propre agr�gat (zpii). On les r�partit sur 12 mois mais on laisse 
		le pr�c�dent traitement avec les conditions d'�ge puisqu'il ne concerne pas que les pensions d'invalidit� (et qu'il reste
		valable pour les ERFS pr�c�dentes) */
	do i=1 to 4;
		zpiiT(i)=zpii&anr2./4;
		end;
	run;

/* sauvegarde dans baserev */
data base.baserev;
	merge	base.baserev (in=a)
			resstrim (keep=ident noi zsali&anr2._t1-zsali&anr2._t4 zchoi&anr2._t1-zchoi&anr2._t4 zrsti&anr2._t1-zrsti&anr2._t4 
				zpii&anr2._t1-zpii&anr2._t4 zindi&anr2._t1-zindi&anr2._t4 nbmois_salt1-nbmois_salt4 nbmois_choT1-nbmois_choT4);
	if a;
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

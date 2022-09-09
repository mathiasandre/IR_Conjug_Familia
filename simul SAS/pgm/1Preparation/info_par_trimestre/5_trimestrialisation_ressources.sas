/*************************************************************************************************/
/*   							5_trimestrialisation_ressources   							   	 */
/*************************************************************************************************/


/* Trimestrialisation des revenus utiles à partir du calendrier d'activité (cal0)				 */

/* table en entrée : base.baseind															     */
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

	/*calcul du nombre de mois d'activité/chomage/retraite par trimestre*/
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

	/*trimestrialisation des revenus catégoriels*/
	array zsaliT(4) zsali&anr2._t1-zsali&anr2._t4;
	array zchoiT(4) zchoi&anr2._t1-zchoi&anr2._t4;
	array zrstiT(4) zrsti&anr2._t1-zrsti&anr2._t4;
	array zpiiT(4) zpii&anr2._t1-zpii&anr2._t4;
	array zindiT(4) zindi&anr2._t1-zindi&anr2._t4;

	/*salaires et assimilés*/
	do i=1 to 4;
		if zsali&anr2.>0 then do;
			if sum(0,of nbmois_salT1-nbmois_salT4)>0 then do;
				zsaliT(i)=zsali&anr2.*nbmois_salT(i)/sum(0,of nbmois_salT1-nbmois_salT4);
				end;
			else do;
				/* Si on n'a pas de mois d'activité salariée, on répartit le salaire équitablement
				sur les 4 trimestres */
				zsaliT(i)=zsali&anr2./4;
				end;
			end;
		else do;
			zsaliT(i)=0;
			end;
		end;

	/* chômage*/
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

	/* revenus indépendants : lissés sur l'année
	- HYPOTHESE : on ramène les déficits déclarés à 0; */
	do i=1 to 4;
		if (zragi&anr2.+zrici&anr2.+zrnci&anr2.)>0 then zindiT(i)=(zragi&anr2.+zrici&anr2.+zrnci&anr2.)/4; 
		else zindiT(i)=0;
		end;

	/*HYPOTHESE : lorsqu'un individu a moins de 50 ans ou 65 ans et plus, on répartit ses pensions de retraite
	  sur 12 mois pour rendre compte dans le premier cas de retraites anticipées cumulables avec des revenus d'activité
	  (militaires…) et de pensions d'invalidité (pouvant être déclarées dans la même case de la déclaration de revenus)
	  et pour le plus âgés du fait qu'une fois la retraite prise, la pension est perçue mensuellement.*/
	if ((&anref.-input(naia,4.))<=50) or ((&anref.-input(naia,4.))>=65) then do i=1 to 4;
		zrstiT(i)=zrsti&anr2./4;
		end;
		/*Depuis l'ERFS 2014, les pensions d'invalidité ont leur propre agrégat (zpii). On les répartit sur 12 mois mais on laisse 
		le précédent traitement avec les conditions d'âge puisqu'il ne concerne pas que les pensions d'invalidité (et qu'il reste
		valable pour les ERFS précédentes) */
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

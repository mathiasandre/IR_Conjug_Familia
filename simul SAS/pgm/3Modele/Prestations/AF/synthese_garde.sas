*************************************************************************************;
/*																					*/
/*								SYNTHESE-GARDE										*/
/*																					*/
*************************************************************************************;

/* Programme g�rant les cas d'exclusion de 2 prestations pour jeune enfant CMG et CLCA */
/* En entr�e : modele.baseind
			   modele.basefam 										*/
/* En sortie : modele.basefam                                     	*/

********************************************************************;
/* 
Plan
A. Agr�gation des donn�es CLCA et CMG au niveau famille
B. Cumul de plusieurs CLCA
C. Cumul du CLCA et du CMG
	C.1 CMG garde � domicile
	C.2 CMG assistant maternel
*/
********************************************************************;
 
/***********************************************************/
/* A. Agr�gation des donn�es CLCA et CMG au niveau famille */
/***********************************************************/

proc sort data=modele.baseind(keep=ident_fam clca clca_tp) out=clca; by ident_fam; run;
proc sort data=modele.basefam; by ident_fam; run;

/* Une m�me famille peut avoir plusieurs CLCA */
data clca_fam; 
	set clca; 
	by ident_fam;
	if ident_fam ne ''; 
	retain clca1 clca2 clca_t clca_tp1 clca_tp2; 
	if first.ident_fam then do; 
		clca1=0; 
		clca2=0; 
		clca_tp1=0; 
		clca_tp2=0;
		clca_t=0;
		end; 
	if clca1 ne 0 then do; 
		clca_tp2=clca_tp;
		clca2=clca;
		end;
	if clca1=0 then do;
		clca_tp1=clca_tp;
		clca1=clca;
		end;
	clca_t=clca_t+clca;
	if last.ident_fam;
run;

data basefam; 
	merge modele.basefam 
		  clca_fam ; 
	by ident_fam; 
run;

/******************************/
/* B. Cumul de plusieurs CLCA */
/******************************/
*Si vous vivez en couple et travaillez tous deux � temps r�duit, vous pouvez b�n�ficier 
chacun du CLCA, dans la limite du montant vers� pour un arr�t complet d'activit�. On 
recalcule ici la variable "compt" comme dans le programme CLCA pour pouvoir calculer le 
CLCA d'inactivit� qui est le majorant; 

data basefam1; 
	set basefam; 
	*Nb d'enfant de 0 � 19 ans;
	%nb_enf(e_c,0,&age_pf.,age_enf);
	compt=0;
	do i = 1 to 12; 
		if e_c>1 then if substr(cal_nai,i,1) in ('1','2','3') then compt=compt+1;
		if e_c=1 then if substr(cal_nai,i,1) in ('1','2') then compt=compt+1;
		end; 
	if clca_tp1 in (2,3) & clca_tp2 in (2,3) then clca_t=min(clca_t,compt*&cca1.*&bmaf.);
	/* Rmq MC : attention, ce qui pr�c�de devrait aussi tenir compte du minimum en cas de 
	b�n�fice de la paje base */

	 * On en d�duit que si un ne travaille pas du tout, le conjoint n'a pas le droit de 
	cumuler du tout;
	if clca_tp1 in (1) & clca_tp2 in (2,3) then clca_t=clca1;
	if clca_tp1 in (1) & clca_tp2 in (1) then clca_t=max(clca1,clca2);
	if clca_tp2 in (1) & clca_tp1 in (2,3) then clca_t=clca2;


/******************************/
/* C. Cumul du CLCA et du CMG */
/******************************/

	/******************************/
	/* C.1 CMG garde � domicile   */
	/******************************/

	if garde='saldom'  then do; 
	/*Il est possible sous certaines conditions de cumuler diff�rents compl�ments :
	- en cas de recours � un assistant maternel et une garde d'enfant � domicile:
	on a exclut cette situation par hypoth�se sur le mode de garde; 
	- en cas d'activit� � temps partiel (CLCA) et de recours � une garde r�mun�r�e (CMG)*/

	/*Si vous b�n�ficiez du CLCA taux plein (=vous ne travaillez plus ou interrompez votre 
	activit� professionnelle), vous ne pouvez pas b�n�ficier du CMG.*/
	if clca_tp1 in (1) ! clca_tp2 in (1) then cmg=0;

	/*Si vous b�n�ficiez du CLCA taux partiel (=vous travaillez � 50% ou moins de la dur�e
	du travail fix�e dans l'entreprise), le montant maximum de CMG est divis� par 2*/
	if clca_tp1 = 2 & clca_tp2 in (2,0) then do;
		/* Nb d'enfants de 0 � 2 ans */
		%nb_enf(enf02,0,2,age_enf); 
		/* Nb d'enfants de 3 � 5 ans */
		%nb_enf(enf35,3,5,age_enf); 

		/* Avant 2014 */
		/*Plafond pour couple mono-actif avec 1 enfant*/
		if sum(e_c,enf_1)<=1 then pl=&paje002.;
		/*Plafond pour couple mono-actif avec plus de 1 enfant*/
		else if sum(e_c,enf_1)>1 then pl=&paje002./(1+&paje_majo_pac12.)*
										 (1+&paje_majo_pac12.*min(2,sum(e_c,enf_1)) 
										 +&paje_majo_pac3.*max(0,sum(e_c,enf_1)-2));
		/*Plafond pour couple bi-actif ou parent seul*/
		if men_paje='H' then pl=pl+&paje001.;
		
		/* Apr�s 2014 (enfants n�s � partir du 1er avril 2014) */
		/*Plafond pour couple mono-actif avec 1 enfant (on ne calcule que le "taux partiel" de l'AB de la Paje) */
		if sum(e_c,enf_1)<=1 then pl_txpartiel=&paje_plaf_part.;
		/*Plafond pour couple mono-actif avec plus de 1 enfant (on ne calcule que le "taux partiel" de l'AB de la Paje)*/
		else if sum(e_c,enf_1)>1 then pl_txpartiel=&paje_plaf_part./(1+&majo_pac.)*(1+&majo_pac.*sum(e_c,enf_1));
		
		if men_paje='H' then pl_txpartiel=pl_txpartiel + &majo_biact_part.;
			
		/* On remplace pl par le "taux partiel" pour les enfants n�s � partir du 1er avril 2014 */ 
		if &anleg.=2014 then do;
			if naissance_apres_avril=1 then pl = pl_txpartiel ;
			end ;
		if &anleg.=2015 then do;
			if naissance_apres_avril in (1,2) then pl = pl_txpartiel ;
			end ;
		if &anleg.=2016 then do;
			if naissance_apres_avril in (1,2,3) then pl = pl_txpartiel ;
			end ;
		if &anleg.=2017 then do;
			if naissance_apres_avril in (1,2,3,4) then pl = pl_txpartiel ;
				end ;

		if res_paje<&cmg_tplaf.*pl then CMG=min(0.5*max((enf02+0.5*enf35),1)*&cmg_sal1.*&bmaf.*12,CMG); 
			else if res_paje<pl then CMG=min(0.5*max((enf02+0.5*enf35),1)*&cmg_sal2.*&bmaf.*12,CMG); 
			else CMG=min(0.5*max((enf02+0.5*enf35),1)*&cmg_sal3.*&bmaf.*12,CMG); 
			end; 

	/*Si vous b�n�ficiez du CLCA taux partiel (=vous travaillez entre 50 et 80% de la dur�e
	du travail fix�e dans l'entreprise), vous cumulez int�gralement le CLCA et le CMG:ici, 
	il n'y a rien � faire */
		end; 


	/******************************/
	/* C.2 CMG assistant maternel */
	/******************************/
	if garde='assmat'  then do; 
	/*Il est possible sous certaines conditions de cumuler diff�rents compl�ments :
	- en cas de recours � un assistant maternel et une garde d'enfant � domicile:
	on a exclut cette situation par hypoth�se sur le mode de garde; 
	- en cas d'activit� � temps partiel (CLCA) et de recours � une garde r�mun�r�e CMG:ici, 
	il n'y a rien � faire;
	- on en d�duit que dans le cas du CLCA � taux plein, on n'a pas de CMG; */
		if clca_tp1 in (1) ! clca_tp2 in (1) then cmg=0;
		end;
run;

proc sort data=basefam1; by ident_fam; run; 
proc sort data=modele.basefam; by ident_fam; run;

data modele.basefam ;
	merge modele.basefam (in=a) 
		  basefam1(keep=ident_fam CMG clca_t rename=(clca_t=clca));
	by ident_fam; 
	if a; 
	if CMG=. then CMG=0; 
	if clca=. then clca=0; 
	label clca="compl�ment de libre choix d'activit�";
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

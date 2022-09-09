*************************************************************************************;
/*																					*/
/*								SYNTHESE-GARDE										*/
/*																					*/
*************************************************************************************;

/* Programme gérant les cas d'exclusion de 2 prestations pour jeune enfant CMG et CLCA */
/* En entrée : modele.baseind
			   modele.basefam 										*/
/* En sortie : modele.basefam                                     	*/

********************************************************************;
/* 
Plan
A. Agrégation des données CLCA et CMG au niveau famille
B. Cumul de plusieurs CLCA
C. Cumul du CLCA et du CMG
	C.1 CMG garde à domicile
	C.2 CMG assistant maternel
*/
********************************************************************;
 
/***********************************************************/
/* A. Agrégation des données CLCA et CMG au niveau famille */
/***********************************************************/

proc sort data=modele.baseind(keep=ident_fam clca clca_tp) out=clca; by ident_fam; run;
proc sort data=modele.basefam; by ident_fam; run;

/* Une même famille peut avoir plusieurs CLCA */
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
*Si vous vivez en couple et travaillez tous deux à temps réduit, vous pouvez bénéficier 
chacun du CLCA, dans la limite du montant versé pour un arrêt complet d'activité. On 
recalcule ici la variable "compt" comme dans le programme CLCA pour pouvoir calculer le 
CLCA d'inactivité qui est le majorant; 

data basefam1; 
	set basefam; 
	*Nb d'enfant de 0 à 19 ans;
	%nb_enf(e_c,0,&age_pf.,age_enf);
	compt=0;
	do i = 1 to 12; 
		if e_c>1 then if substr(cal_nai,i,1) in ('1','2','3') then compt=compt+1;
		if e_c=1 then if substr(cal_nai,i,1) in ('1','2') then compt=compt+1;
		end; 
	if clca_tp1 in (2,3) & clca_tp2 in (2,3) then clca_t=min(clca_t,compt*&cca1.*&bmaf.);
	/* Rmq MC : attention, ce qui précède devrait aussi tenir compte du minimum en cas de 
	bénéfice de la paje base */

	 * On en déduit que si un ne travaille pas du tout, le conjoint n'a pas le droit de 
	cumuler du tout;
	if clca_tp1 in (1) & clca_tp2 in (2,3) then clca_t=clca1;
	if clca_tp1 in (1) & clca_tp2 in (1) then clca_t=max(clca1,clca2);
	if clca_tp2 in (1) & clca_tp1 in (2,3) then clca_t=clca2;


/******************************/
/* C. Cumul du CLCA et du CMG */
/******************************/

	/******************************/
	/* C.1 CMG garde à domicile   */
	/******************************/

	if garde='saldom'  then do; 
	/*Il est possible sous certaines conditions de cumuler différents compléments :
	- en cas de recours à un assistant maternel et une garde d'enfant à domicile:
	on a exclut cette situation par hypothèse sur le mode de garde; 
	- en cas d'activité à temps partiel (CLCA) et de recours à une garde rémunérée (CMG)*/

	/*Si vous bénéficiez du CLCA taux plein (=vous ne travaillez plus ou interrompez votre 
	activité professionnelle), vous ne pouvez pas bénéficier du CMG.*/
	if clca_tp1 in (1) ! clca_tp2 in (1) then cmg=0;

	/*Si vous bénéficiez du CLCA taux partiel (=vous travaillez à 50% ou moins de la durée
	du travail fixée dans l'entreprise), le montant maximum de CMG est divisé par 2*/
	if clca_tp1 = 2 & clca_tp2 in (2,0) then do;
		/* Nb d'enfants de 0 à 2 ans */
		%nb_enf(enf02,0,2,age_enf); 
		/* Nb d'enfants de 3 à 5 ans */
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
		
		/* Après 2014 (enfants nés à partir du 1er avril 2014) */
		/*Plafond pour couple mono-actif avec 1 enfant (on ne calcule que le "taux partiel" de l'AB de la Paje) */
		if sum(e_c,enf_1)<=1 then pl_txpartiel=&paje_plaf_part.;
		/*Plafond pour couple mono-actif avec plus de 1 enfant (on ne calcule que le "taux partiel" de l'AB de la Paje)*/
		else if sum(e_c,enf_1)>1 then pl_txpartiel=&paje_plaf_part./(1+&majo_pac.)*(1+&majo_pac.*sum(e_c,enf_1));
		
		if men_paje='H' then pl_txpartiel=pl_txpartiel + &majo_biact_part.;
			
		/* On remplace pl par le "taux partiel" pour les enfants nés à partir du 1er avril 2014 */ 
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

	/*Si vous bénéficiez du CLCA taux partiel (=vous travaillez entre 50 et 80% de la durée
	du travail fixée dans l'entreprise), vous cumulez intégralement le CLCA et le CMG:ici, 
	il n'y a rien à faire */
		end; 


	/******************************/
	/* C.2 CMG assistant maternel */
	/******************************/
	if garde='assmat'  then do; 
	/*Il est possible sous certaines conditions de cumuler différents compléments :
	- en cas de recours à un assistant maternel et une garde d'enfant à domicile:
	on a exclut cette situation par hypothèse sur le mode de garde; 
	- en cas d'activité à temps partiel (CLCA) et de recours à une garde rémunérée CMG:ici, 
	il n'y a rien à faire;
	- on en déduit que dans le cas du CLCA à taux plein, on n'a pas de CMG; */
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
	label clca="complément de libre choix d'activité";
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

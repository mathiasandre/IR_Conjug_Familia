*************************************************************************************;
/*																					*/
/*								Tirage & imputation avantage mon�taire CMUc et ACS									*/
/*																					*/
*************************************************************************************;

/* I. Tirage parmi les �ligibles	*/
/* II. Imputation des montants CMUc et ACS  */


/* En entr�e : modele.baseind 
							 base.menage&anr2.*/
			
/* En sortie : modele.baseind  */


/**********************************************************/
/*************** I. TIRAGE DES BENEFICIAIRES	****************/
/**********************************************************/

proc sql;
	create table table_tirage as
		select unique ident_cmu, ident, wpela&anr2., elig_cmuc, elig_acs, sum(statut_cmu="pac") as nbpac_cmu, nbp_cmu
			from modele.baseind
			where ident_cmu ne " "
			group by ident_cmu
			order by ident_cmu;
quit;

data table_tirage;
	set table_tirage;
	by ident_cmu;
	/* on fait des types de foyer cmu pour le tirage */
	nbciv=nbp_cmu-nbpac_cmu;
	type_foyer="                                                                 ";
	if nbciv=1 & nbpac_cmu=0 then typfam="0. C�lib";
	else if nbciv=1 & nbpac_cmu=1 then typfam="1. C�lib 1 enfant"; 
	else if nbciv=1 & nbpac_cmu=2 then typfam="2. C�lib 2 enfants +"; 
	else if nbciv=1 & nbpac_cmu>2 then typfam="3. C�lib 3 enfants +"; 
	else if nbciv=2 & nbpac_cmu=0 then typfam="4. Couple sans enfant";
	else if nbciv=2 & nbpac_cmu=1 then typfam="5. Couple 1 enfant";
	else if nbciv=2 & nbpac_cmu=2 then typfam="6. Couple 2 enfants";
	else typfam="7. Couple 3 enfants +";
	run;

/******** A) Tirage des b�n�ficiaires CMUC ********/

/* on cr�e un identifiant de tirage */

proc sort data= table_tirage; by typfam; run;
data table_tirage_cmuc;
    retain id_tirage 0;
	set table_tirage  (where=(elig_cmuc=1));
	by typfam;
	if first.typfam then id_tirage=id_tirage+1; /* on a 8 cases */
	alea=ranuni(1); /* on attribue une variable al�atoire */
	run;

proc sort data= table_tirage_cmuc; by id_tirage alea; run;
data table_tirage_cmuc ;
	set table_tirage_cmuc;
	by id_tirage; 
	recours_cmuc=1;
   	retain poids;
		if first.id_tirage then poids=0;
		poids=poids+wpela&anr2.;
			%macro boucle_cmuc;
			%do i=1 %to 8;
			if id_tirage=&i. and poids>&&part_cmuc_&i.*&nb_benef_cmuc. then recours_cmuc=0;
			%end;
			%mend;
			%boucle_cmuc;
	run;

/******** B) Tirage des b�n�ficiaires ACS ********/

/* on cr�e un identifiant de tirage */

proc sort data= table_tirage; by typfam; run;
data table_tirage_acs;
    retain id_tirage 0;
	set table_tirage  (where=(elig_acs=1));
	by typfam;
	if first.typfam then id_tirage=id_tirage+1; /* on a 8 cases */
	alea=ranuni(1); /* on attribue une variable al�atoire */
	run;

proc sort data= table_tirage_acs; by id_tirage alea; run;
data table_tirage_acs ;
	set table_tirage_acs;
	by id_tirage; 
	recours_acs=1;
   	retain poids;
		if first.id_tirage then poids=0;
		poids=poids+wpela&anr2.;
			%macro boucle_acs;
			%do i=1 %to 8;
			if id_tirage=&i. and poids>&&part_acs_&i.*&nb_benef_acs. then recours_acs=0;
			%end;
			%mend;
			%boucle_acs;
	run;

/**********************************************/
/*************** II. IMPUTATIONS	****************/
/*********************************************/
proc sort data=modele.baseind; by ident_cmu; run;
proc sort data=table_tirage_cmuc; by ident_cmu; run;
proc sort data=table_tirage_acs; by ident_cmu; run;


data modele.baseind;
			merge modele.baseind (in=a)
				   table_tirage_cmuc (keep=recours_cmuc ident_cmu)
				   table_tirage_acs (keep=recours_acs ident_cmu);
	by ident_cmu;
	if a;
	age=(12*&anref.-12*naia)/12;
	avantage_monetaire_cmuc=0;
	cheque_acs=0;
	
/******** A) Avantage mon�taire CMUC ********/

	if recours_cmuc=1 then do;
		if age<16 then avantage_monetaire_cmuc=&part_montant_cmuc_15.*&montant_cmuc.;
		if 16<=age<50 then avantage_monetaire_cmuc=&part_montant_cmuc_49.*&montant_cmuc.;
		if 50<=age<60 then avantage_monetaire_cmuc=&part_montant_cmuc_59.*&montant_cmuc.;
		if 60<=age then avantage_monetaire_cmuc=&part_montant_cmuc_60.*&montant_cmuc.;
	end;
		
/******** B) Ch�que ACS ********/

	if recours_acs=1 then do;
		if age<16 then cheque_acs=&montant_acs_15.;
		if 16<=age<50 then cheque_acs=&montant_acs_49.;
		if 50<=age<60 then cheque_acs=&montant_acs_59.;
		if  60<=age then cheque_acs=&montant_acs_60.;
	end;

	drop recours_acs recours_cmuc age;
	run;

/* suppression des tables interm�diaires */
proc datasets mt=data library=work kill;run;quit; 


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

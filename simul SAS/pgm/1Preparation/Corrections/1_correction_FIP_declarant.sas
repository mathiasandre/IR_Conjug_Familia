/****************************************************************************************/
/*																						*/
/*						1_correction_FIP_declarant										*/
/*																						*/
/****************************************************************************************/

/****************************************************************************************/
/* Quelques corrections automatiques sur le declar des FIP et EE&FIP. 					*/
/*  - Coh�rence entre les 2 premiers chiffres de la variable declar (noi du d�clarant) 	*/
/* 	- Supprime des espaces en trop dans declar et anaisenf								*/
/*	- Correction des cases J (enfant majeur � charge) en cases F (enfant mineur � charge*/
/* en fonction de l'ann�e mentionn�e apr�s la lettre.									*/
/****************************************************************************************/
/* En entr�e : 	travail.indivi&anr. 				                       				*/
/* 				travail.indfip&anr. 				                                	*/
/* 				travail.foyer&anr.	 				                                	*/
/* En sortie : 	travail.indivi&anr. 				                                	*/
/* 				travail.indfip&anr. 				                                	*/
/* 				travail.foyer&anr.	 				                                	*/
/****************************************************************************************/

/* S�lection des d�clarants FIP */
proc sql;
	create table fip as
		select declar1, noi as noiFIP from travail.indfip&anr.
		where persfip='vous';
	create table temp_indivi as
		select a.*, noiFIP from
		travail.indivi&anr. as a left join fip as b
		on a.declar1=b.declar1;
	create table temp_indfip as
		select a.*, noiFIP from
		travail.indfip&anr. as a left join fip as b
		on a.declar1=b.declar1;
	create table temp_foyer as
		select a.*, noiFIP from
		travail.foyer&anr. as a left join fip as b
		on a.declar=b.declar1;
	quit;

data travail.indivi&anr.(drop=noifip) travail.indfip&anr.(drop=noifip);
	set temp_indivi(in=a) temp_indfip(in=b);
	if noiFIP ne '' then substr(declar1,1,2)=noiFIP;

	/* correction automatique des espaces en trop dans le declar1 et declar2 */
	if substr(declar1,30,1)='' & substr(declar1,31,1) ne '' then
		declar1=substr(declar1,1,29)!!substr(declar1,31,length(declar1)-31+1);
	if substr(declar2,30,1)='' & substr(declar2,31,1) ne '' then
		declar2=substr(declar2,1,29)!!substr(declar2,31,length(declar2)-31+1);

	/* correction des lettres J ou F pour les enfants qui viennent de naitre dans declar1 */
	if index(declar1,"J&anref")>0 then do;
		if length(declar1)-index(declar1,"J&anref")-5+1>0 then
		declar1=substr(declar1,1,index(declar1,"J&anref")-1)!!"F&anref"!!substr(declar1,index(declar1,"J&anref")+5,length(declar1)-index(declar1,"J&anref")-5+1); 
		else declar1=substr(declar1,1,index(declar1,"J&anref")-1)!!"F&anref";
		end;

	/* correction des lettres J ou F pour les enfants qui viennent de naitre dans declar2 */
	if index(declar2,"J&anref")>0 then do;
		if length(declar2)-index(declar2,"J&anref")-5+1>0 then
		declar2=substr(declar2,1,index(declar2,"J&anref")-1)!!"J&anref"!!substr(declar2,index(declar2,"J&anref")+5,length(declar2)-index(declar2,"J&anref")-5+1); 
		else declar2=substr(declar2,1,index(declar2,"J&anref")-1)!!"F&anref";
		end;

	if a then output travail.indivi&anr.;
	if b then output travail.indfip&anr.;
	run;

data travail.foyer&anr.(drop=noifip);
	set temp_foyer;
	if noiFIP ne '' then substr(declar,1,2)=noiFIP;

	/* Suppression d'un espace en trop dans declar et anaisenf */
	if substr(anaisenf,1,1)='' & substr(anaisenf,2,1) ne '' then anaisenf=substr(anaisenf,2,39);
	if substr(declar,30,1)='' & substr(declar,31,1) ne '' then declar=substr(declar,1,29)!!substr(declar,31,39);

	/* correction des lettres J ou F pour les enfants qui viennent de naitre */
	if index(anaisenf,"J&anref")>0 then do;
		substr(anaisenf,index(anaisenf,"J&anref"),1)='F';
		if length(declar)-index(declar,"J&anref")-5+1>0 then
		declar=substr(declar,1,index(declar,"J&anref")-1)!!"F&anref"!!substr(declar,index(declar,"J&anref")+5,length(declar)-index(declar,"J&anref")-5+1); 
		else declar=substr(declar,1,index(declar,"J&anref")-1)!!"F&anref";
		sif=substr(sif,1,66)!!'01'!!substr(sif,69,7)!!'00'!!substr(sif,78,17);
		end;
	run;

proc delete data=temp_indivi temp_indfip temp_foyer; run;

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

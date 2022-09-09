/****************************************************************/
/*																*/
/*				5_elig_ASPA_ASI									*/
/*								 								*/
/****************************************************************/


/* PLAN :

	A. S�lection des personnes �ligibles au minimum vieillesse (ASPA) 	
	B. S�lection des personnes �ligibles � l'ASI 
	C. Sauvegarde de ae la variable elig_aspa_asi dans imput 
		
	
 En entr�e : 	travail.cal_indiv								
		   		base.baseind					             
				travail.indivi&anr.				              
		  	 	imput.handicap					              
		  		travail.indfip&anr.				               	
		  		travail.irf&anr.e&anr.		
 
 En sortie : 	imput.aspa_asi                                     


Remarques : 
1. L'�ligibilit� au minimum vieillesse (ASPA) est automatique � partir de 65 ans mais concerne
aussi certaines personnes avant cet �ge, sur la base de crit�res dont on ne dispose pas ici.
Pour s�lectionner aussi des �ligibles de moins de 65 ans, on fait l'hypoth�se suivante : 
ceux qui d�clarent percevoir le minimum vieillesse dans l'enqu�te emploi y sont �ligibles quel que soit leur �ge.

2. L'ASI concerne les personnes invalides, titulaires d'une pension de retraite ou d'invalidit� mais
ne remplissant pas la condition d'age pour b�n�ficier de l'ASPA.
On approxime ces conditions par les crit�res suivantes :
- avoir moins de 60 ans, 
- �tre handicap�, 
- d�clarer une pension de retraite ou invalidit� : depuis ERFS 2014, les pensions d'invalidit� sont d�clar�es � part,
elles ont donc �t� ajout�es au crit�re mais on laisse le crit�re sur zrsti puisqu'on peut avoir des retrait�s invalides
- �tre de nationalit� fran�aise ou d'Europe occidentale (??)
- ne pas �tre dans notre champ des �ligibles ASPA */



/* A. s�lection des �ligibles � l'ASPA */
data elig_aspa;
	set travail.cal_indiv;
	if index(cal_minv ,'1')>0;
	run;
proc sort data=elig_aspa; by ident noi; run;
proc sort data=base.baseind; by ident noi; run;


/* B. s�lection des �ligibles � l'ASI */
data indivi; set travail.indivi&anr.(keep=ident noi zrsti zpii); if zrsti>0 or zpii>0; run;
data fip; set travail.indfip&anr.(keep=ident noi zrsti zpii); if zrsti>0 or zpii>0; run;
data indivi; set indivi fip; run;
proc sort data=indivi; by ident noi; run;

proc sort data=base.baseind; by ident noi; run;
proc sort data=imput.handicap; by ident noi; run;

data elig_asi; 
	merge 	imput.handicap(keep=ident noi handicap)  
			base.baseind(keep=ident noi naia)
			indivi(in=a); 
	by ident noi;
	if a & handicap>0 & &anref.-naia<60;
	run;



/* C. Sauvegarde */
data imput.aspa_asi;
	merge elig_aspa(keep=ident noi in=a) elig_asi(keep=ident noi in=b);
	by ident noi; 
	if a then elig_aspa_asi=1; 
	else if b then  elig_aspa_asi=2;
	else elig_aspa_asi=0;
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

/****************************************************************/
/*																*/
/*				5_elig_ASPA_ASI									*/
/*								 								*/
/****************************************************************/


/* PLAN :

	A. Sélection des personnes éligibles au minimum vieillesse (ASPA) 	
	B. Sélection des personnes éligibles à l'ASI 
	C. Sauvegarde de ae la variable elig_aspa_asi dans imput 
		
	
 En entrée : 	travail.cal_indiv								
		   		base.baseind					             
				travail.indivi&anr.				              
		  	 	imput.handicap					              
		  		travail.indfip&anr.				               	
		  		travail.irf&anr.e&anr.		
 
 En sortie : 	imput.aspa_asi                                     


Remarques : 
1. L'éligibilité au minimum vieillesse (ASPA) est automatique à partir de 65 ans mais concerne
aussi certaines personnes avant cet âge, sur la base de critères dont on ne dispose pas ici.
Pour sélectionner aussi des éligibles de moins de 65 ans, on fait l'hypothèse suivante : 
ceux qui déclarent percevoir le minimum vieillesse dans l'enquête emploi y sont éligibles quel que soit leur âge.

2. L'ASI concerne les personnes invalides, titulaires d'une pension de retraite ou d'invalidité mais
ne remplissant pas la condition d'age pour bénéficier de l'ASPA.
On approxime ces conditions par les critères suivantes :
- avoir moins de 60 ans, 
- être handicapé, 
- déclarer une pension de retraite ou invalidité : depuis ERFS 2014, les pensions d'invalidité sont déclarées à part,
elles ont donc été ajoutées au critère mais on laisse le critère sur zrsti puisqu'on peut avoir des retraités invalides
- être de nationalité française ou d'Europe occidentale (??)
- ne pas être dans notre champ des éligibles ASPA */



/* A. sélection des éligibles à l'ASPA */
data elig_aspa;
	set travail.cal_indiv;
	if index(cal_minv ,'1')>0;
	run;
proc sort data=elig_aspa; by ident noi; run;
proc sort data=base.baseind; by ident noi; run;


/* B. sélection des éligibles à l'ASI */
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

/*verification qu'on ne donne pas plusieurs fois le m�me nom de param�tres;
*on v�rifie aussi qu'on n'a pas de param�tre � valeur nulle; */




libname dossier "N:\Unite\F0\F020\INES\Ines l�g 2010\param�tres";
%let dossier=N:\Unite\F0\F020\INES\Ines l�g 2010\param�tres;


%macro import(doc,feuille,table);
PROC IMPORT DATAFILE = "&dossier.\&doc..xls"  
	OUT = dossier.&table REPLACE;
	sheet = &feuille;
RUN;
%mend import;

%macro symput_mod(table,anleg,tx);
data _null_;
 set dossier.&table (KEEP = nom valeur_INES_&anleg derive);
 if nom ne '';
 if derive = 1 then valeur_INES_&anleg=round(valeur_INES_&anleg*&tx,1);
 if derive = 3 then valeur_INES_&anleg=valeur_INES_&anleg*&tx;
call symputx(nom,valeur_INES_&anleg,'G');
 run;

data &table; 
set sashelp.vmacro;
label value = "valeur_&table";
if scope = 'GLOBAL';
run; 
proc sort data=&table(rename=(value=value_&table)); by name;run;
%delvars;
%mend symput_mod;

%macro delvars;
data vars;
set sashelp.vmacro;
run;
data _null_;
set vars;
if scope='GLOBAL' then call execute('%symdel '
||trim(left(name))||';');
run;
%mend;

%import(param_impot,rgb,imp_abatt);
%import(param_impot,parts,parts);
%import(param_impot,charges,imp_charges);
%import(param_impot,calcul_impot,imp_calc);
%import(param_impot,r�duc,deduc);
%import(param_impot,cr�dit,credit);
%import(param_impot,ppe,ppe);
%import(en_cours new2,af,af);
%import(en_cours new2,minima,minima);
%import(en_cours new2,aeeh,aeeh);
%import(en_cours new2,al,al);
%import(TH,TH,TH);
%import(en_cours new2,cotis,param_soc);

%import(param_baseERFS,base,init);

%let anref= 2008;

%symput_mod(init,%eval(&anref+2),1);



%macro tourne; 
%do i =1 %to 14; 
%let liste_table = init imp_abatt parts imp_charges imp_calc deduc credit ppe af minima al aeeh param_soc th;
%symput_mod(%scan(&liste_table,&i),2010,1);
%end;
%mend; 

%tourne;

%let liste_table = init imp_abatt parts imp_charges imp_calc deduc credit ppe af minima al aeeh param_soc th;

* valeurs manquantes;
%macro manquantes;
%do i=1 %to 14; 
data m_%scan(&liste_table,&i);
set %scan(&liste_table,&i);
if value_%scan(&liste_table,&i)=.;
run;
%end; 
%mend;
%manquantes;


*nom de variable attribu� plusieurs fois; 
%macro trop_attribue;

data toutes; 
merge %do i=1 %to 14; %scan(&liste_table,&i)(in=pres&i) %end; ;
by name; 

pres = sum(of pres1-pres14); 
if pres > 1; 
run; 


 
%mend;
%trop_attribue;


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

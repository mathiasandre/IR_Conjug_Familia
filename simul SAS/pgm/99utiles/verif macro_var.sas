/*verification qu'on ne donne pas plusieurs fois le même nom de paramètres;
*on vérifie aussi qu'on n'a pas de paramètre à valeur nulle; */




libname dossier "N:\Unite\F0\F020\INES\Ines lég 2010\paramètres";
%let dossier=N:\Unite\F0\F020\INES\Ines lég 2010\paramètres;


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
%import(param_impot,réduc,deduc);
%import(param_impot,crédit,credit);
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


*nom de variable attribué plusieurs fois; 
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

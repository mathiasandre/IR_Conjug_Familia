/****************************************/
/* 	Fichier propre � chaque utilisateur */
/* 	Ne pas �tre commit� avec SVN 		*/
/* 	� ajouter dans "ignore list"		*/
/****************************************/


/* option dbms pour les fichiers excel
	* excel2000 � l'Insee sur les postes individuels;
	* xls � l'Insee sous AUS;
	* xls � la Drees pour les import;
	* excelcs � la Drees pour les export, mais instable */


*%let qui=AUS;
%let chemin_dossier=Z:\QC_QF;
%let chemin_bases=X:\HAB-Ines-D2E\Tables Ines;
%let excel_imp=xls;
%let excel_exp=xls;

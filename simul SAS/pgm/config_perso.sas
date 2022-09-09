/****************************************/
/* 	Fichier propre à chaque utilisateur */
/* 	Ne pas être commité avec SVN 		*/
/* 	À ajouter dans "ignore list"		*/
/****************************************/


/* option dbms pour les fichiers excel
	* excel2000 à l'Insee sur les postes individuels;
	* xls à l'Insee sous AUS;
	* xls à la Drees pour les import;
	* excelcs à la Drees pour les export, mais instable */


*%let qui=AUS;
%let chemin_dossier=Z:\QC_QF;
%let chemin_bases=X:\HAB-Ines-D2E\Tables Ines;
%let excel_imp=xls;
%let excel_exp=xls;

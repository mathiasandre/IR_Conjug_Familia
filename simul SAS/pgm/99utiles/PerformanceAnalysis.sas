/* Remarque : il faut une version en anglais de SAS */

/* A lancer avant l'enchainement */
options fullstimer;
%include "&chemin_dossier.\pgm\99utiles\logparse\PASSINFO.sas";
%passinfo;

/* Il faut ensuite enregistrer la log à un endroit avant de lancer l'enchaînement */
proc printto log="&chemin_dossier.\pgm\99utiles\logparse\Log.log" new;
run;
data test;
	set modele.basemen;
	run;

	/* Lancer l'enchaînement */


/* A lancer après l'enchainement */
	/* On remet la log dans la session SAS */
	proc printto; run;
	
	/* On sort l'excel d'analyse */
%include "&chemin_dossier.\pgm\99utiles\logparse\logparse.sas";
   %logparse(&chemin_dossier.\pgm\99utiles\logparse\Log.log, myperfdata, OTH );
proc export 
	dbms=&excel_exp. replace 
	data=myperfdata
	outfile="&sortie_cible.\myperfdata.&excel_exp.";
	run;


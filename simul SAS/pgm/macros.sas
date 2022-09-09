/********************************************************************************/
/*																				*/
/*								  MACROS										*/
/*																				*/
/*                        MACROS UTILES POUR INES                               */
/*																				*/
/********************************************************************************/

/* Ce programme contient plusieurs macros Sas ayant vocation à servir à divers endroits du modèle. 
Toute macro ne servant que dans un et un seul programme, a sa place dans ledit programme, et non ici (beaucoup d'exemples dans le bloc Impot). 
L'intégralité des macros présentes dans ce programmes doivent être listées dans la page "Catalogue des macros" du Wiki. 
Toute nouvelle macro doit donc être ajoutée à cette page dans l'une des catégories suivantes : 
	- macros de manipulation générale ;
	- macros semi-générales ;
	- macros n'ayant pas vocation à servir en-dehors du modèle Ines. */

/********************************************************************************************/
/*	PLAN																					
1\	Macros de manipulation générale
		%Init_Valeur(ListeVar,Valeur=0);
		%Change_length_str(var,len);
		%NumericToString(var,lenString);
		%RemplaceChaineDansMot(motIn,motOut,chaine1,chaine2,nbOcc=1000);
		%SupprimeChaineDansMot(mot,chaine1,nbOcc=1000);
		%SupprimeChaineDansMot_Pos(mot,position1,position2);
		%AjouteChaineDansMot(mot,chaine,position);
		%VarExist(lib=,TABLE=,VAR=);
		%RenameVarSuffixe(table_input,table_output,exception,suffixe);
		%CreeMacrovarAPartirTable(nomMV,table,colonneValeur,colonneIdent,ident);
		%AjouteUpcaseGuillemetsAListe(ListeIn);
		%PartsManquantesDansTable(table,except,seuil);
		%MissingToZero(ListeVar)
2\	Macros semi-générales
		%ListeVariablesDuneTable(table,mv,except,separateur=' ');
		%Cumul(basein,baseout,varin,varout,varAgregation);
		%Revalorisation_Milieu_Annee(VarOld,VarNew,Coef,Mois=Mois_Revalo);
		%CreeParametreRetarde(NomMV,Table,Param,Type,FinNomColonne,NbLag);
		%Quantile(quantile,table,variable,poids,nom_var);

3\	Macros n'ayant pas vocation à servir en-dehors du modèle Ines
		&RevIndividuels
		&RevObserves
		%CreeListeCases
		%Nb_Enf(nom,age1,age2,age_enf);
		%Nb_Mois(nom,type);
		%CasesManquantesEla(anref);
		%CalculAgregatsERFS;
		%Standard_Foyer
		%VariablesChangeantSelonAnref;
		%creaEchantillonERFS(denom);
		%macro_var_BDF
*********************************************************************************************/



/****************************************/
/* 1	Macros de manipulation générale */
/****************************************/


%Macro Init_Valeur(ListeVar,Valeur=0);
	/* Initialise ou réinitialise une liste de variables (séparées par un espace) à zéro par défaut, ou à une autre valeur si renseignée */
	/* @ListeVar : liste de variables séparées par un espace 
       @Valeur : valeur à laquelle les variables doivent être initialisées (0 par défaut) */	
	%do i=1 %to %sysfunc(countw(&ListeVar.));
		%scan(&ListeVar.,&i.)=&Valeur.;
		%end;
	%Mend;


%Macro Change_length_str(var,len);
	/* Change la longueur d'une variable caractère */
	/* @Var : nom de la variable caractère dont on veut modifier la longueur
	   @Len : nouvelle longueur de la variable */
	%global newlabel;
	LENGTH &var._n $ &len.;
	&var._n=&var.;
	call symput('newlabel',vlabel(&var.));/* On garde le label de l'ancienne variable */
	label &var._n = "&newlabel."; 
	drop &var.;
	rename &var._n=&var.;
	%Mend;


%Macro NumericToString(var,lenString);
	/* Convertit une variable numérique en chaîne de caractères */
	/* @Var : nom de la variable numérique que l'on veut convertir en chaine de caractères
	   @LenString : nouvelle longueur de la chaine de caractères */
	%global newlabel;
	LENGTH &var._n $ &LenString.;
	&var._n=put(&var.,&LenString.);
	if &var.=. then &var._n=''; /* Gestion des valeurs manquantes */
	call symput('newlabel',vlabel(&var.));/* On garde le label de l'ancienne variable) */
	label &var._n = "&newlabel."; 
	drop &var.;
	rename &var._n=&var.;
	%Mend;


%Macro RemplaceChaineDansMot(motIn,motOut,chaine1,chaine2,nbOcc=1000);
	/* Macro à insérer dans une data : remplace au max NBOCC occurences de CHAINE1 par CHAINE2 dans la variable MOTIN de type string
	/* le résultat est dans MOTOUT (qui peut être égal à MOTIN) */
	/* @motIn : Variable caractère dans laquelle remplacer une chaine de caractère 
       @motOut : Variable caractère en sortie (peut être égale à motIn)
       @chaine1 : Chaine de caractère à remplacer dans motIn
       @chaine2 : Chaine de caractère qui remplace chaine1
       @nbOcc : nombre maximum d'occurences de chaine 1 à remplacer. Fixé à 1000 par défaut. */ 

	/* Si chaîne modifiée plus longue que la chaîne initiale, on augmente la longueur de la variable */
	/*%if %length("&chaine2.")>%lenght("&chaine1.") %then %do;
		%Change_length_str(&motIn.,%length(&motIn.)-%length(&chaine1.)+%length(&chaine2.));
		%end;*/ /* ce bout de code ne fonctionne pas, à débugger */
	/* En attendant, il faut gérer le problème par une instruction length adéquate placée entre 
	le data et le set de l'étape data dans laquelle est insérée l'appel à cette macro */

	nbOccurences=min(count(&motIn.,&chaine1.),&nbOcc.);
	if nbOccurences ne 0 then do;
		do i=1 to nbOccurences;
			find=find(&motIn.,&chaine1.);
			if find ne 1 then avant=substr(&motIn.,1,find-1);
				else avant="";
			if find+length(&chaine1.)-1 ne length(&motIn.) then apres=substr(&motIn.,find+length(&chaine1.),length(&motIn.)-find-length(&chaine1.)+1);
				else apres="";
			&motOut.=compbl(avant||&chaine2.||apres);
			end;
		end;
	drop find avant apres nbOccurences i;
	%Mend RemplaceChaineDansMot;


%Macro SupprimeChaineDansMot(mot,chaine1,nbOcc=1000);
	/* Macro à insérer dans une data : supprime au max NBOCC occurences de CHAINE1 dans la variable MOT de type string */
	/* @mot : variable caractère dans laquelle supprimer une chaine de caractère
       @chaine1 : chaine de caractère à supprimer dans la variable "mot"
       @nbOcc : nombre d'occurences de chaine1 à supprimer  */
	nbOccurences=min(count(&mot.,&chaine1.),&nbOcc.);
	if nbOccurences ne 0 then do;
		do i=1 to nbOccurences;
			find=find(&mot.,&chaine1.);
			if find ne 1 then avant=substr(&mot.,1,find-1);
				else avant="";
			if find+length(&chaine1.)-1 ne length(&mot.) then apres=substr(&mot.,find+length(&chaine1.),length(&mot.)-find-length(&chaine1.)+1);
				else apres="";
			&mot.=compbl(avant||apres);
			end;
		end;
	drop find avant apres nbOccurences i;
	%Mend SupprimeChaineDansMot;


%Macro SupprimeChaineDansMot_Pos(mot,position1,position2);
	/* Macro à insérer dans une data : supprime la chaîne qui va de POSITION1 à POSITION2 (incluses) dans la variable MOT de type string */
	/* @mot : variable caractère dans laquelle supprimer une chaine de caractère
       @position1 : position où débute la chaine de caractère à supprimer
       @position2 : position où se termine la chaine de caractère à supprimer */
	/* Attention il faut entrer position1<position2 */
	%if &position1.>=&position2. %then %do;
		%put Veuillez revoir l ordre des paramètres (il faut position1<position2);
		%end;
	%else %do;
		avant=substr(&mot.,1,%eval(&position1.-1));
		apres=substr(&mot.,%eval(&position2.+1),length(&mot.)-&position2.);
		&mot.=avant||apres;
		drop avant apres;
		%end;
	%Mend SupprimeChaineDansMot_Pos;


%Macro AjouteChaineDansMot(mot,chaine,position);
	/* Macro à insérer dans une étape data : ajoute la chaine CHAINE (entrer les guillemets) dans le mot MOT, en position POSITION */
	/* @mot : variable caractère dans laquelle ajouter une chaine de caractère
   	   @chaine : chaine de caractère à ajouter (ne pas oublier les guillemets) dans la variable "mot"
       @position : position de la chaine de caractère à ajouter */

	/* Si chaîne modifiée plus longue que la chaîne initiale, on augmente la longueur de la variable */
	/*%if %length(&chaine.)>0 %then %do;
		%Change_length_str(&mot.,%length(&mot.)+%length(&chaine.));
		%end;*/ /* ce bout de code ne fonctionne pas, à débugger */
	/* En attendant, il faut gérer le problème par une instruction length adéquate placée entre 
	le data et le set de l'étape data dans laquelle est insérée l'appel à cette macro */

	/* Si la chaine de caractère est à insérer en toute première position */
	%if &position.=1 %then %do;
		avant="";
		apres=&mot.;
		%end;
	%else %do;
		avant=substr(&mot.,1,%eval(&position.-1));
		apres=substr(&mot.,&position.,length(&mot.)-&position.+1);
		%end;
	&mot.=avant||&chaine.||apres;
	drop avant apres;
	%Mend AjouteChaineDansMot;


%GLOBAL varexist;
%Macro VAREXIST(lib=,TABLE=,VAR=);
	/* Macro permettant d'identifier la présence d'une variable dans une table */
	/* @lib : librairie dans laquelle la table est présente
	   @Table : table 
	   @var : variable recherchée */  
	/* Attention, sensible à la casse des variables ; renvoie varexist=1*/
    proc sql noprint;
        SELECT count(*)
        INTO :varexist
        FROM DICTIONARY.COLUMNS /* équivalent de sashelp.vcolumn */
        WHERE libname="%UPCASE(&lib.)" AND memname="%UPCASE(&table.)"
                   AND name="&var.";
  		quit;
 
    %IF &varexist.>0 %then %put &VAR. existe dans la TABLE &TABLE.;
    %else %put &var. n%str(%')existe pas;
 
	%Mend VAREXIST;


%Macro RenameVarSuffixe(table_input,table_output,exception,suffixe);
	/* Macro permettant de rajouter un suffixe à toutes les variables d'une table, sauf certaines (exception)*/
 	/* @Table_input : table d'entrée contenant les variables à renommer 
 	   @Table_output : nom de la table en sortie 
	   @Exception : liste des variables à ne pas renommer 
	   @Suffixe : suffixe à rajouter au nom des variables 	
	   EXEMPLE : %RenameVarSuffixe(modele.basemen,basemenbis,'ident' 'poi',_ines); */
   	proc contents DATA=&table_input. out=table_output noprint; run;
   	DATA table_output1;
      	SET table_output ;
		if name in (&exception.) then delete;
		RUN;
   	DATA _null_;
      	SET table_output1 ; 
	  	call symput('mvvar'||compress(_n_),compress(name)) ;
	  	call symput('mvmax',compress(_n_)) ;
   		run;

   	DATA &table_output. ;
      	SET &table_input.
        (RENAME= (%do i=1 %TO &mvmax. ;
			&&mvvar&i. = &&mvvar&i.%sysfunc(LEFT(&suffixe.))
            %end; )
			);
   		run;
	%Mend RenameVarSuffixe;


%Macro CreeMacrovarAPartirTable(nomMV,table,colonneValeur,colonneIdent,ident);
	%put "&nomMV.";
	/* Macro qui se suffit à elle-même (pas forcément à insérer dans une data) */
	/*	@nom : 			 Nom de la macrovariable qui sera créée
		@table : 		 Nom de la table qui contient l'information désirée (typiquement une table de la librairie dossier)
		@colonneValeur : Nom de la colonne qui contient la valeur que l'on souhaite donner à la macrovariable
		@colonneIdent :  Nom de la colonne qui contient l'identifiant du paramètre (typiquement la colonne "nom" pour Ines)
		@ident : 		 Nom du paramètre, ie ligne à sélectionner dans la table (pas forcément égal au paramètre &nomMV.) */
	/* Macro utile par exemple pour créer des variables retardées, comme l'exemple ci-dessous : 
	   %CreeMacrovarAPartirTable(smich_lag1,dossier.smic,valeur_Ines_%eval(&anleg.-1),nom,smich); */
	data _null_;
		set &table.;
		keep &colonneValeur. &colonneIdent.;
		if &colonneIdent.="&ident.";
		call symputx("&nomMV.",&colonneValeur.,'G');
		run;
	%put LA MACROVARIABLE &nomMV. A ETE CREEE AVEC LA VALEUR &&&nomMV.;
	%Mend CreeMacrovarAPartirTable;


%Macro AjouteUpcaseGuillemetsAListe(ListeIn);
	/* Cette macro crée une macrovariable globale appelée ListeOut */
	/* @listeIn : Liste des variables modifiées (passées en majuscule et entre guillemets) */
	/* Exemple d'utilisation : AjouteUpcaseGuillemetsAListe(a1 a2 a3) va créer une MV ListeOut="A1" "A2" "A3" */
	/* Remarque : il serait bon que ListeOut soit passé en paramètre, mais on ne peut pas faire un %let &ListeOut. en Sas */
	%global ListeOut;
	%let ListeOut=;
	%do k=1 %to %sysfunc(countw(&ListeIn.));
		%let mot=%upcase(%scan(&ListeIn.,&k.));
		%let ListeOut=&ListeOut. "&mot.";
		%end;
	%Mend AjouteUpcaseGuillemetsAListe;

%Macro PartsManquantesDansTable(table, except, seuil = 99);
	/*Cette macro affiche les part de valeurs manquantes des variables d'une table.
		Elle affiche une erreur en arrêtant le code s'il n'y a que des valeurs manquantes pour une des variables*/
	/* @table : table étudiée*/
	/*@Except : liste de variables à exclure de l'investigation*/
	/*@seuil : seuil à partir duquel la macro retourne un message d'erreur*/
	%ListeVariablesDUneTable(table=&table,mv=liste_var,except=&except., separateur=' ');
	%do j=1 %to %sysfunc(countw(&liste_var.));
		%let var=%scan(&liste_var.,&j.);
		 proc sql noprint;
    	    SELECT floor(100*sum(missing(&var.))/count(*)) INTO: part_miss 
        	FROM &table.;
  			quit;
		%put La variable &var. a &part_miss. % de valeurs manquantes ;
 		data _null_;
			set &table.;
				if &part_miss. > &seuil. then do;
					ERROR "ERROR : la variable &var. a plus de &seuil. % de valeurs manquantes";
					stop;
					end;
			run;
		%end;	
%Mend PartsManquantesDansTable;


%Macro MissingToZero(ListeVar);
/* Remplace des valeurs manquantes par un 0 à l'intérieur d'une étape data */
	%do i=1 %to %sysfunc(countw(&ListeVar.));
		if %scan(&ListeVar.,&i.)= . then %scan(&ListeVar.,&i.)=0 ;
	%end;
%Mend MissingToZero;

/*****************************************/
/* 2	Macros semi-générales			 */
/*****************************************/


%Macro ListeVariablesDuneTable(table,mv,except,separateur=' ');
	/* 	@MV : nom de la macrovariable créée (liste des variables)
		@Table : nom de la table de laquelle la liste des variables est dans MV
		@Except : la liste &MV. ne contiendra pas les variables listées comme exceptions ici
		@Separateur : séparateur entre les éléments de la liste (un blanc par défaut)
		EXEMPLE : %ListeVariablesDUneTable(table=travail.foyer&anr.,mv=liste,except=ident noi, separateur=',');*/

	/*	Genèse de cette macro : 
		Dans une jointure SQL on peut avoir envie de faire un a.* mais sans une certaine variable
		Souvent l'exception est l'identifiant car la variable est déjà dans a et si elle est aussi présente dans b, 
		SQL ne comprend pas laquelle il faut prendre. 
		Cette macro permet alors de générer une macrovariable de type "var1, var2, ..., varN", 
		facilement réinsérable en tant que texte dans une proc sql (exemple dans 6_correction_declar) */

	/* Principe général d'écriture : 
		1	PROC CONTENTS : Récupération de la liste des variables dans une table (temp)
		2	RETAIN : On récupère dans la dernière ligne de temp la liste de toutes les variables
		3	IF FIN : On ne garde que la dernière ligne de temp
		4	CALL SYMPUT : On transforme la valeur de cette observation en une macrovariable
	   Problèmes divers rencontrés gérés dans la macro : 
		-	la casse des noms des variables doit être gérée par des upcase
		-	on veut un séparatateur entre chaque variable, mais on n'en veut ni au début, ni à la fin
		-	s'il existe des variables en exception, il faut les supprimer de la chaîne mais aussi supprimer les virgules */

	%global &mv.; /* Instruction nécessaire pour qu'elle continue à exister en dehors de la macro */

	/* Gestion du cas où la table ne contient aucune variable */
	%let dsid=%sysfunc(open(&table.));
	%let nvar=%eval(%sysfunc(attrn(&dsid.,nvar)));
	%let rc=%sysfunc(close(&dsid.));
	%if &NVar.=0 %then %do;
		%let &mv.=;
		%end;

	/* Tous les autres cas (la table contient au moins une variable) */
	%else %do;
		proc contents data=&table. noprint out=temp (keep=name); run;
		data temp;
			/* l=variable texte qui vaudra à la fin la liste de tous les noms de variables */
			length l $20000.; /* on se donne une taille max très grande */
			set temp end=fin;
			retain l;
			if _N_=1 then l=upcase(name); /* initialisation de l sans le séparateur */
			else l=compbl(l)||&separateur.||compress(upcase(name)); /* à chaque ligne on rajoute à l le séparateur + un nouveau mot */
			if fin; /* on ne garde que la dernière ligne qui contient la liste de toutes les variables */
			%if &except. ne %then %do;
				/* Problème : si on ne renseigne rien dans &except., %sysfunc(countw("&except.")) vaut tout de même 1
				Pour contourner le problème, on rajoute cette condition sur "except doit être renseigné à quelque chose" */
				%do i=1 %to %sysfunc(countw("&except."));
					%let ToDrop=%upcase(%scan(&except.,&i.)); /* Le nom de variable que l'on veut supprimer */
					%if &separateur. ne ' ' %then %do; %SupprimeChaineDansMot(l,"&ToDrop. "||&separateur.,nbOcc=1); %end;
					/* Supression du mot + du séparateur, mais si séparateur=' ' déjà géré par un compress de %SupprimeChaineDansMot */
					%else %do; %SupprimeChaineDansMot(l,"&ToDrop. ",nbOcc=1); %end;
					%end;
				%end;
			call symput("&mv.",l);
			run;
		proc delete data=temp; run;
		%end;
	%Mend ListeVariablesDuneTable;


%Macro Cumul(basein,baseout,varin,varout,varAgregation);
	/* Macro agrégeant une variable par groupe */
	/* @VarIn : variables à cumuler (quanti)
	   @VarAgregation : variable qui définit le groupe au sein duquel cumuler (quali)
	   @BaseIn : table en entrée, doit contenir VarIn et VarAgregation
	   @BaseOut : table qui sera créée en sortie (une ligne par groupe)
	   @VarOut : liste des variables cumulées crées en sortie */
	%let requete=;
	%do k=1 %to %sysfunc(countw(&varin.))-1;
		%let Var1=%scan(&varin.,&k.);
		%let Var2=%scan(&varout.,&k.);
		%let requete=&requete. sum(&Var1.) as &Var2., ;
		%end;
	%let requete=&requete. sum(%scan(&varin.,%sysfunc(countw(&varin.)))) as %scan(&varout.,%sysfunc(countw(&varin.))); /* sans virgule pour la dernière */
	proc sql;
		create table &BaseOut. as
		select distinct(&VarAgregation.), &requete. from &BaseIn.
		group by &VarAgregation.;
		quit;
	%Mend Cumul;


%Macro Revalorisation_Milieu_Annee(VarOld,VarNew,Coef,Mois=Mois_Revalo);
	/* Ligne de calcul à insérer dans une étape data */
	/*	@VarOld : Variable à revaloriser (valeur de référence et non moyenne annuelle)
		@VarNew : Nom de la variable une fois revalorisée (en moyenne annuelle)
		@Coef : Critère de revalorisation (le calcul sera : *(1+coef))
		@Mois : 1er jour du mois auquel a lieu la revalorisation */
	&VarNew.=	&VarOld.*((&Mois.-1)/12)
				+&VarOld.*(1+&Coef.)*((12-(&Mois.-1))/12);
	%Mend Revalorisation_Milieu_Annee;



%Macro CreeParametreRetarde(NomMV,Table,Param,Type,FinNomColonne,NbLag);
	/* Utilisation spécifique à Ines de la macro plus générale écrite ci-dessus */
	/* 	@NomMv : Nom de la macro-variable créée
		@Table : Nom de la table qui contient l'information désirée
		@Param : Nom du paramètre à retarder	
		@Type : vaut ERFS ou Ines selon que l'on est sur param_base_ERFS (1er cas) ou non (2ème cas)
		@FinNomColonne. : vaut ce qui dépasse de "Valeur_Ines_" ou "Valeur_ERFS_"
		La plupart du temps vaut &anref. ou &anleg., mais peut s'accompagner de "_CTF", ou "_ref" ...
		@NbLag : de combien d'années souhaite-t-on décaler par rapport à l'année de référence &Annee. ? */
	/* Cette macro se complique parce qu'elle veut pouvoir traiter le cas où la colonne va s'appeler, par exemple, Valeur_Ines_2013_ref */

	/* EXEMPLE : 	%CreeParametreRetarde(smich_lag2,dossier.smic,smich,Ines,&anleg.,2);
					va créer une macrovariable appelé smich_lag2 et prenant la valeur de smich décalée de deux ans par rapport à anleg */

	/* On cherche à extraire l'année de FinNomColonne, même si souvent FinNomColonne=nom de l'année */
	/* On cherche donc où commence un "20" ou "19" (donc ne marchera plus en 2100) */
	%let find=%eval(%sysfunc(max(%index(&FinNomColonne.,20),%index(&FinNomColonne.,19))));
	%let Annee=%substr(&FinNomColonne.,&find.,4);
	%let Annee2=%eval(&Annee.-&NbLag.);
	/* Toutes ces macrovariables sont locales et disparaissent une fois qu'on sort de la macro */
	%CreeMacrovarAPartirTable(&NomMV.,&Table.,valeur_&Type._&Annee2.,nom,&Param.);
	/* Attention, dans le cas où le nom de fin de colonne est différent de l'année, ce n'est pas pris en compte (fait exprès)
	Exemple : si on travaille sur une colonne Valeur_Ines_2013_ref, smich_lag1 sera la valeur 2012 (donc moyenne annuelle), 
	différente de ce qu'aurait été 2012_ref (dernière valeur de l'année 2012), si cette colonne avait existé */
	%Mend CreeParametreRetarde;


%Macro quantile(quantile,table,variable,poids,nom_var);
/* Macro permettant d'ajouter une variable contenant le numéro du décile de revenu
	@quantile : 	nombre de quantiles désirés
 	@table : 		table sur laquelle on rajoute une variable. Elle doit contenir @variable et @poids 
 	@variable : 	nom de la variable de @table sur laquelle on souhaite calculer les quantiles 
	@poids : 		variable de pondération de @table pour que les quantiles soient représentatifs du champ
	@nom_var :		nom de la variable contenant les quantiles 	
	EXEMPLE : %quantile(10,fpsuc,revavred,poidind,decile);  	*/
	/* Attention : ne marche que lorsque quantile est un diviseur de cent*/
	data temp1; 
		set &table.(keep=ident &variable. &poids.);
		run;
	%let pas=%sysevalf(100/&quantile.);
	proc univariate data=temp1 noprint;
		freq &poids.;
		var &variable.;
		output out=quantile pctlpts=&pas. to %sysevalf(100-&pas.) by &pas. pctlpre=qqqq;
		run;
	data temp1(drop=qqqq:); 
		if _N_=1 then set quantile; 
		set temp1;
		format &nom_var. $2.; /*mettre 3 pour faire des centiles par exemple */
		if &variable.<=qqqq&pas. then &nom_var.="1";
		%do i=2 %to %eval(&quantile.-1); 
			%let limite=%eval(&i.*&pas.);
			else if &variable.<=qqqq&limite. then &nom_var.="&i.";
			%end;
		else &nom_var.="&quantile.";
		%if &quantile. >=10  & &quantile. ne 100 %then %do; 
			if &nom_var.<10 then &nom_var.="0"!!&nom_var.;
			%end; 
		%if &quantile.=100 %then %do;
			if &nom_var.<10 then &nom_var.= "00"!!&nom_var.;
		 	else if &nom_var.<100 then &nom_var.= "0"!!&nom_var.;
			%end;
		data &table.;
			merge 	&table. 
					temp1(keep=ident &nom_var.);
			run;
	%mend quantile; 

/************************************************************************/
/* 3	Macros n'ayant pas vocation à servir en-dehors du modèle Ines	*/
/************************************************************************/

/* Définition de macro-variables */
%let RevIndividuels =zsali zrsti zpii zchoi zalri zrtoi zragi zrici zrnci frais;
%let RevObserves	=zsalo zrsto zpio zchoo zalro zrtoo zrago zrico zrnco;
/* Les variables doivent être dans le même ordre entre les deux macro-variables. 
   Les variables de RI qui n'ont pas d'équivalent dans RO doivent être à la fin (on ne bouclera que sur dim(RevObserves) */

%Macro Nb_Enf(nom,age1,age2,age_enf); 
	/* Compte le nombre d'enfants qui ont entre age1 et age2 inclus et enregistre l'information 
	dans la variable nommée nom*/
	/* @nom : variable résumant le nombre d'enfants ayant entre age1 et age2
	   @age1 : age inférieur 
	   @age2 : age supérieur
	   @age_enf : variable âge des enfants */	
	/* Macro utilisée dans af.sas ressources.sas 8_elig_asf.sas 9_garde.sas 10_travail_clca.sas
	1_SFT.sas ars.sas af.sas cmg.sas clca.sas creche.sas basemen.sas paje.sas synthese_garde.sas
	aah.sas rsa.sas */
	&nom.=0; 
	%do age=&age1.+1 %to &age2.+1; 
		&nom. = &nom.+input(substr(&age_enf.,&age.,1),2.);
		%end;
	%Mend Nb_Enf;


%Macro Nb_Mois(nom_cal,nom_var,type); 
	/* Variable comptant le nombre de mois d'un statut dans un calendrier présenté sous forme de chaine de caratère, chaque caractère 
	représentant un mois donné, la valeur du caractère définissant le statut (exemple => le calendrier d'acivité de &anref. se présente
	comme ceci 111111111111 lorsque la personne est en emploi les 12 mois de l'année de référence) */
	/* 	@nom_cal : le nom de la variable de calendrier au sein de laquelle on dénombre les caractères
		@nom_var : nom de la variable résumant le nombre de mois dénombré
	   	@type : modalité du statut auquel on s'intéresse (Exemples => 1 = activité salariée, 4 = chômage )  */
	&nom_var.=0; 
	%do month=1 %to 12; 
		if substr(&nom_cal.,&month.,1)="&type." then &nom_var.=&nom_var.+1;
		%end;
	%Mend Nb_Mois;


%Macro CasesManquantesEla(anref);
	/* @anref : millésime de l'ERFS que l'on veut corriger */
	/* A utiliser lorsque des cases fiscales sont manquantes dans l'ERFS élargie et pas dans le noyau */
	/* Dans ce cas on va chercher l'info pour les individus du noyau */
	/* A faire tourner avant l'appel de init_foyer */
	/* On ne modifie pas la table de CD par principe, donc on initialise travail.foyer qui sera modifiée largement dans Init_foyer ensuite */	

	/* Ne pas confondre avec le travail lié à la macrovariable noyau_uniquement=oui ou non */
	/* Là, on est tacitement dans le cas noyau_uniquement=non, et il manque de l'info par erreur dans l'ERFS */
	/* Alors qu'autrement, il n'y a pas forcément d'erreur, mais on gère le cas où on souhaite travailler sur l'un ou sur l'autre */

	%local where_list;
	%let where_list=; 
	%if &noyau_uniquement.=oui %then %do; %let where_list=where=(choixech='NOYAU'); %end;
	/* TODO : cette ligne n'est pas satisfaisante pour coder le passage au noyau, 
	simple restriction sur les individus des tables de CD alors qu'on veut utiliser les tables de RPM */

	%if &anref.=2011 %then %do;
	/* Correction spécifique à l'ERFS 2011 qui concerne les revenus accessoires (locations meublées ...) */
	proc sql;
		create table travail.foyer&anr. as
		select a.*, 
			coalesce(b._5hz,0) as _5hz,
			coalesce(b._5iz,0) as _5iz, 
			coalesce(b._5jz,0) as _5jz, 
			coalesce(b._5nd,0) as _5nd, 
			coalesce(b._5ng,0) as _5ng, 
			coalesce(b._5od,0) as _5od, 
			coalesce(b._5og,0) as _5og, 
			coalesce(b._5pd,0) as _5pd, 
			coalesce(b._5pg,0) as _5pg, 
			coalesce(b._7wg,0) as _7wg 
			from cd.foyer&anr._ela(&where_list.) as a 
			left join
			rpm.foyer&anr. as b
			on a.declar=b.declar;
		quit;
		%end;
	%else %do;
		data travail.foyer&anr.;
			set cd.foyer&anr._ela(&where_list.);
			run;
		%end;
	%Mend;


%Macro CalculAgregatsERFS;
	/*Calcule les agrégats de l'ERFS à partir des listes de cases fiscales définies dans la macro %ListeVariablesAgregatsERFS
	Intervient essentiellement dans evol_revenus. */
	cbicf=	max(&abatmicmarch.*_5ko+&abatmicserv.*_5kp,min(_5ko+_5kp,&E2000.))+
			max(&abatmicmarch.*_5lo+&abatmicserv.*_5lp,min(_5lo+_5lp,&E2000.))+
			max(&abatmicmarch.*_5mo+&abatmicserv.*_5mp,min(_5mo+_5mp,&E2000.))+
			max(&abatmicmarch.*_5ta+&abatmicserv.*_5tb,min(_5ta+_5tb,&E2000.))+
			max(&abatmicmarch.*_5ua+&abatmicserv.*_5ub,min(_5ua+_5ub,&E2000.))+
			max(&abatmicmarch.*_5va+&abatmicserv.*_5vb,min(_5va+_5vb,&E2000.));
	cbncf=max(&abatmicbnc.*(_5hq),min(_5hq,&E2000.))+
		  max(&abatmicbnc.*(_5iq),min(_5iq,&E2000.))+
	      max(&abatmicbnc.*(_5jq),min(_5jq,&E2000.))+
	      max(&abatmicbnc.*(_5te),min(_5te,&E2000.))+
	      max(&abatmicbnc.*(_5ue),min(_5ue,&E2000.))+
	      max(&abatmicbnc.*(_5ve),min(_5ve,&E2000.));
	zfonf=sum(_4ba,(1-&tx_microfonc.)*_4be,-_4bb,-_4bc);
	caccf=max(&abatmicmarch.*(_5no+_5ng+_5nj)+&abatmicserv.*(_5np+_5nd)+&abatmicbnc.*_5ku,min(_5no+_5ng+_5nj+_5np+_5nd+_5ku,&E2000.))+
		  max(&abatmicmarch.*(_5oo+_5og+_5oj)+&abatmicserv.*(_5op+_5od)+&abatmicbnc.*_5lu,min(_5oo+_5og+_5oj+_5op+_5od+_5lu,&E2000.))+
		  max(&abatmicmarch.*(_5po+_5pg+_5pj)+&abatmicserv.*(_5pp+_5pd)+&abatmicbnc.*_5mu,min(_5po+_5pg+_5pj+_5pp+_5pd+_5mu,&E2000.));
	augm_plaf=0;
	if (case_l='L' or case_t='T' or case_k='K') and (nbn>0) then augm_plaf=1; 
	psa=sum(_6gu,
			&E2001.*_6gp,
			min(&E2001.*_6gi,&P0490.),
			min(&E2001.*_6gj,&P0490.),
			min(_6el,&P0490.)*(1+augm_plaf),
			min(_6em,&P0490.)*(1+augm_plaf));

	%Init_Valeur(zsalf zchof zrstf zpif zalrf zrtof zragf zvalf zavff zvamf zetrf zalvf zglof zquof zdivf zdivpf);
	zricf=-cbicf;zrncf=-cbncf;zracf=-caccf;
	
	array zsalfP &zsalfP.;
	array zchofP &zchofP.;
	array zrstfP &zrstfP.;
	array zpifP &zpifP.;
	array zalrfP &zalrfP.;
	array zrtofP &zrtofP.;
	array zragfP &zragfP.; array zragfN &zragfN.;
	array zricfP &zricfP.; array zricfN &zricfN.;
	array zrncfP &zrncfP.; array zrncfN &zrncfN.;
	array zvalfP &zvalfP.;
	array zavffP &zavffP.;
	array zvamfP &zvamfP.;
	array zracfP &zracfP.; array zracfN &zracfN.;
	array zetrfP &zetrfP.; 
	array zalvfP &zalvfP.;
	array zglofP &zglofP.;
	array zquofP &zquofP.;
	array zdivfP &zdivfP.; array zdivfN &zdivfN.;
	do i=1 to dim(zsalfP); zsalf=zsalf+zsalfP(i); end;
	do i=1 to dim(zchofP); zchof=zchof+zchofP(i); end;
	do i=1 to dim(zrstfP); zrstf=zrstf+zrstfP(i); end;
	do i=1 to dim(zpifP); zpif=zpif+zpifP(i); end;
	do i=1 to dim(zalrfP); zalrf=zalrf+zalrfP(i); end;
	do i=1 to dim(zrtofP); zrtof=zrtof+zrtofP(i); end;
	do i=1 to dim(zragfP); zragf=zragf+zragfP(i); end;	do i=1 to dim(zragfN); zragf=zragf-zragfN(i); end;
	do i=1 to dim(zricfP); zricf=zricf+zricfP(i); end;	do i=1 to dim(zricfN); zricf=zricf-zricfN(i); end;
	do i=1 to dim(zrncfP); zrncf=zrncf+zrncfP(i); end;	do i=1 to dim(zrncfN); zrncf=zrncf-zrncfN(i); end;
	do i=1 to dim(zvalfP); zvalf=zvalf+zvalfP(i); end;
	do i=1 to dim(zavffP); zavff=zavff+zavffP(i); end;
	do i=1 to dim(zvamfP); zvamf=zvamf+zvamfP(i); end;
	do i=1 to dim(zracfP); zracf=zracf+zracfP(i); end;	do i=1 to dim(zracfN); zracf=zracf-zracfN(i); end;
	do i=1 to dim(zetrfP); zetrf=zetrf+zetrfP(i); end;	
	do i=1 to dim(zalvfP); zalvf=zalvf+zalvfP(i); end;
	do i=1 to dim(zglofP); zglof=zglof+zglofP(i); end;
	do i=1 to dim(zquofP); zquof=zquof+zquofP(i); end;
	do i=1 to dim(zdivfP); zdivpf=zdivpf+zdivfP(i); end;
	do i=1 to dim(zdivfP); zdivf=zdivf+zdivfP(i); end;	do i=1 to dim(zdivfN); zdivf=zdivf-zdivfN(i); end;
	drop i;
	%Mend CalculAgregatsERFS; 


%macro Standard_Foyer;
	/* ATTENTION : 	les modifications de cette partie doivent être répercutées dans le 
					programme de création des foyers de EE et EE_CAF */
	length  xyz mcdvo case_e case_f case_g case_k case_l case_p case_s case_w case_n case_t case_l2 $1  
			nbf nbg nbr nbj nbn nbh nbi agec aged ageh 3
			anaisd anaisc anaih $4
			vousconj $9 
			nbenf $24 	
			jourev moisev $2;	

	/* Création de variables à partir du SIF */
	mcdvo=substr(sif,5,1);
	xyz='0'; 
	if substr(sif,35,1)='X' then xyz='X';/* on considère que X prime pour les doubles déclarations */
	else if substr(sif,44,1)='Y' then xyz='Y';
	else if substr(sif,53,1)='Z' then xyz='Z';
	vousconj=substr(sif,6,4)!!"-"!!substr(sif,11,4);

	label 	case_e='E' case_f='F' case_g='G' case_k='K' case_l='L' case_p='P' 
			case_s='S' case_w='W' case_n='N' case_t='T' case_l2='L2';

	case_e=substr(sif,16,1);
	case_f=substr(sif,17,1);
	case_g=substr(sif,18,1);
	case_k=substr(sif,19,1);
	case_l=substr(sif,20,1);
	case_p=substr(sif,21,1);
	case_s=substr(sif,22,1);
	case_w=substr(sif,23,1);
	case_n=substr(sif,24,1);
	case_t=substr(sif,30,1);
	case_l2=substr(sif,25,1);
	array case case_e case_f case_g case_k case_l case_p case_s case_w case_n case_t case_l2;
	do over case; if case='' then case='0'; end;

	/*Parfois il existe un ' F0' en début de sif (1 cas en 2011)mais ce n'est celui que l'on cherche ie ce n'est pas 
	  celui	à partir duquel on extrait la variable nbenf. on sait que le ' F0' que l'on cherche est dans une position au 
	  delà de 20 au moins donc on uitilise un find plutôt qu'un index*/
	debut_F=find(sif,' F0',20);
	if debut_F=0 then debut_F=find(sif,' F1',20);
	nbenf=substr(sif,debut_F+1,24);
	nbf=input(substr(nbenf,2,2),2.);
	nbg=input(substr(nbenf,5,2),2.);
	nbr=input(substr(nbenf,8,2),2.);
	nbj=input(substr(nbenf,11,2),2.);
	nbn=input(substr(nbenf,14,2),2.);
	nbh=input(substr(nbenf,17,2),2.);
	nbi=input(substr(nbenf,20,2),2.);
		  
	anaisd=substr(vousconj,1,4);  
	anaisc=substr(vousconj,6,4);  
	anaih=substr(sif,26,4); 
	if anaih ne '0000' then ageh=&anref.-input(anaih,4.); else ageh=99; 
	if anaisd not in ('9999','9998') then aged=&anref.-input(anaisd,4.);else aged=0;
	if mcdvo in ('M','O') & anaisc not in ('9999','9998') then agec=&anref.-input(anaisc,4.); else agec=0;
	/* Dans le cas d'un couple marié ou pacsé mais dont on n'a qu'un des deux membres dans le ménage, 
	l'année de naissance du FIP est à 9998 (cf pgm 5a_ee_foyer)*/

	if xyz='X' then do;/*normalement le mois du mariage est en %eval(35+3) mais incoherence 
	possible sif-dec donc on cherche ailleurs*/
		moisev=substr(sif,%eval(35+3),2);
		jourev=substr(sif,%eval(35+1),2);
		if moisev='00' then do;
			moisev=substr(sif,%eval(44+3),2);
			jourev=substr(sif,%eval(44+1),2);
			end;
		if moisev='00' then do;
			moisev=substr(sif,%eval(53+3),2);
			jourev=substr(sif,%eval(53+1),2);
			end;
		end;
	if xyz='Y' then do;
		moisev=substr(sif,%eval(44+3),2);
		jourev=substr(sif,%eval(44+1),2);
		if moisev='00' then do;
			moisev=substr(sif,%eval(35+3),2);
			jourev=substr(sif,%eval(35+1),2);
			end;
		if moisev='00' then do;
			moisev=substr(sif,%eval(53+3),2);
			jourev=substr(sif,%eval(53+1),2);
			end;
		end;
	if xyz='Z' then do;
		moisev=substr(sif,%eval(53+3),2);
		jourev=substr(sif,%eval(53+1),2);
		if moisev='00' then do;
			moisev=substr(sif,%eval(44+3),2);
			jourev=substr(sif,%eval(44+1),2);
			end;
		if moisev='00' then do;
			moisev=substr(sif,%eval(35+3),2);
			jourev=substr(sif,%eval(35+1),2);
			end;
		end;
	if xyz='0' then do;moisev='00';jourev='00';end;
	%mend; 


/* CreeListeCases : crée une macrovariable appelée _liste_&agregat._&individu. (par exemple _liste_zsali_vous)
	et contenant la liste des noms des cases fiscales correspondant à l'agrégat et à cet individu, 
	pour l'année la plus récente (cases séparées par un blanc)

	En entrée : dossier.foyerVarList (créée dans FoyerVarType)
	En sortie : 2 macrovariables : _liste_zsali_vous (par exemple) et liste_cas_part */

/* LISTE_CAS_PART : 
	Liste qui contiendra toutes les cases n'appartenant pas à un agrégat mais faisant l'objet d'un traitement à part, 
	soit ajout= dans l'appel à la macro ci-dessous, soit qui fait l'objet d'une liste à part (COMME_SAL ...) */
%let liste_cas_part=;
%Macro CreeListeCases(agregat,individu,ajout);
	%global _liste_&agregat._&individu.;
	%let _liste_&agregat._&individu.=;
	data x;
		set dossier.FoyerVarList;
		if agregatERFS="&agregat." and index(typeContenu,"&individu.")>0;
		run;
	proc transpose data=x out=x_ (drop=_name_ _label_); id name; run;
	%ListeVariablesDUneTable(table=x_,mv=_liste_&agregat._&individu.,separateur=' ');
	proc delete data=x x_; run;
	%let _liste_&agregat._&individu.=&ajout. &&_liste_&agregat._&individu.;
	%put _liste_&agregat._&individu.=&&_liste_&agregat._&individu.;

	/* On ajoute à la liste des cas particuliers les variables derrière ajout= */
	%let liste_cas_part=&liste_cas_part. &ajout.;

	%Mend;

%Macro VariablesChangeantSelonAnref;
/* Macro définissant les variables qui changent de noms selon le millésime ERFS */
	%global NAF;
	%let condition=&anref.<2008;
	%if &condition. %then %let NAF=naf;
	%else %let NAF=nafn;
	%Mend;
%VariablesChangeantSelonAnref;


%Macro creaEchantillonERFS(denom);
	/* Macro prenant en paramètre 1/le taux d'échantillonage. 
	Exemple : denom=100 va échantillonner au 1/100ème */
	data ech;
		set cdne.men&anref._ela;
		p=ranuni(1);
		if p lt 1/&denom.;
		keep ident&anr.;
		run;
	ods output "Library Members"=tempcd; proc datasets lib=cdne; quit; ods output close;
	ods output "Library Members"=temprpm; proc datasets lib=rpmne; quit; ods output close;
	proc sql; select distinct name into : listeTabCD separated by ' ' from tempcd; quit;
	proc sql; select distinct name into : listeTabRPM separated by ' ' from temprpm; quit;
	%do i=1 %to %sysfunc(countw(&listeTabCD.));
		%let table=%scan(&listeTabCD.,&i.);
		data cd.&table.;
			merge ech (in=a) cdne.&table.;
			by ident&anr.;
			if a;
			run;
		%end;
	%do j=1 %to %sysfunc(countw(&listeTabRPM.));
		%let table=%scan(&listeTabRPM.,&j.);
		data rpm.&table.;
			merge ech (in=a) rpmne.&table.;
			by ident&anr.;
			if a;
			run;
		%end;
	proc delete data=ech tempcd temprpm; run;
	%Mend creaEchantillonERFS;


/* Macro pour module taxation indirecte */
%macro macro_var_BDF;
%if &inclusion_TaxInd.=oui %then %do; 
		%include "&imputation.\imputation BDF\0_macrosBDF.sas";
	%end;
	%mend macro_var_BDF;
%macro_var_BDF;


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

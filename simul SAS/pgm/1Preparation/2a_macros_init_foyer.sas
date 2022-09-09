/********************************************************/
/*          Programme 2a_macros_init_foyer              */ 
/********************************************************/

/* Ce programme regroupe une série de macros appelées ensuite dans 2b_init_foyer : 
	%InitialisationSimple
	%ApparitionSimple
	%DisparitionSimple
	%TransfererCases
	%EchangerCases
	%SuppressionVariablesInutiles
	%Standard_Foyer
*/


%macro InitialisationSimple(listeCases);
    %let variables = %sysfunc(STRIP(&listeCases.)) ;
    %let variables = %sysfunc(COMPBL(&variables.)) ;
    %let nbVariables = %eval(%sysfunc( count( &variables.,%str( ) ) )+1);
    %do i=1 %to &nbVariables.;
        %let casesInutiles = %sysfunc(TRANWRD(&casesInutiles., %scan(&variables.,&i.,%str( )), %str()));
        %end;
    %let variables = %sysfunc(TRANWRD(&variables.,%nrquote( ),%str(=0;)));
    %let variables = &variables.%str(=0;);
    &variables.;
    %mend;

%macro ApparitionSimple(anneeApparition=,listeCases=);
	/**    Lorsque des cases apparaissent une année donnée dans le formulaire fiscal, ...
	  *    @param	anneeApparition		année à partir de laquelle les cases sont présentes dans le formulaire fiscal
	  *    @param	listeCases  		liste des cases qui apparaissent dans le formulaire fiscal  */
    %if &anref.<&anneeApparition. %then %do;
        %InitialisationSimple(&listeCases.);
        %end;
    %mend;

%macro DisparitionSimple(anneeDisparition=,listeCases=);
	/**    Lorsque des cases disparaîssent une année donnée du formulaire fiscal, ...
	  *    @param    anneeDisparition  année à partir de laquelle les cases ne sont plus présentes dans le formulaire fiscal
	  *    @param    listeCases  liste des cases qui disparaissent du formulaire fiscal */
    %if &anref.>=&anneeDisparition. %then %do;
        %initialisationSimple(&listeCases.);
        %end;
    %mend;


%macro TransfererCases(transfert,dateApparitionCasesArrivee,cumulAvecArrivee=N,ponderations=,garderCaseorigine=N);
    
    %let positionFleche=%sysfunc(find(&transfert.,->));

    %let casesOrigine = %sysfunc( substrn(&transfert.,0,&positionFleche.) );
    %let casesOrigine = %sysfunc( strip(&casesOrigine.) );
    %let casesOrigine = %sysfunc( compbl(&casesOrigine.) );

    %let casesArrivee = %sysfunc( substrn(&transfert.,&positionFleche.+2) );
    %let casesArrivee = %sysfunc( strip(&casesArrivee.) );
    %let casesArrivee = %sysfunc( compbl(&casesArrivee.) );

    %let nbCasesOrigine = %eval(%sysfunc( count( &casesOrigine.,%str( ) ) )+1);
    %let nbCasesArrivee = %eval(%sysfunc( count( &casesArrivee.,%str( ) ) )+1);

	%let sommeCasesOrigine = 0;
    %if %length(&ponderations.)=0 %then %do i=1 %to &nbCasesOrigine.;
        %let sommeCasesOrigine = &sommeCasesOrigine. + %scan(&casesOrigine.,&i.,%str( )) ;
        %end;

	%else %do;
        %let ponderations = %sysfunc(strip(&ponderations.));
        %let ponderations = %sysfunc(compbl(&ponderations.));

        /* On vérifie qu'il y a autant de pondérations que de cases d'origne */
        %let nbponderations=%eval(%sysfunc( count( &ponderations.,%str( ) ) )+1);
        %if &nbponderations. ne &nbCasesOrigine. %then %do; 
            error "Il faut autant de pondérations que de cases d'origine";
            abort(nolist);
            %end;

        %do i=1 %to &nbCasesOrigine.;
            %let sommeCasesOrigine = &sommeCasesOrigine. + %sysevalf(%scan(&ponderations.,&i.,%str( )))*%scan(&casesOrigine.,&i.,%str( )) ;
            %end;
        %end;

    %if &anref. < &dateApparitionCasesArrivee. %then %do;
        %do i=1 %to &nbCasesArrivee.;
            %let somme = (&sommeCasesOrigine.)/&nbCasesArrivee.;
            %if &cumulAvecArrivee=O %then %do;
                %let somme = sum(%scan(&casesArrivee.,&i.), &somme.);
                %end;
            %scan(&casesArrivee.,&i.)=&somme.;
            %let casesInutiles = %sysfunc(TRANWRD(&casesInutiles., %scan(&casesArrivee.,&i.,%str( )), %str()));
            %end;
        %if &garderCaseorigine =O %then %do; 
            %do i=1 %to &nbCasesOrigine.;
                %let casesInutiles = &casesInutiles. %scan(&casesOrigine.,&i.);
                %end;
            %end;
        %end;
    %mend;


%macro EchangerCases(echange,anneeEchange);

	%let positionFleche=%sysfunc(find(&echange.,<->));

    %let caseGauche = %sysfunc( substrn(&echange.,0,&positionFleche.) );
    %let caseGauche = %sysfunc( strip(&caseGauche.) );
    %let caseGauche = %sysfunc( compbl(&caseGauche.) );

    %let caseDroite = %sysfunc( substrn(&echange.,&positionFleche.+3) );
    %let caseDroite = %sysfunc( strip(&caseDroite.) );
    %let caseDroite = %sysfunc( compbl(&caseDroite.) );

 	 %if &anref. < &anneeEchange. %then %do;
		%transfererCases(&caseGauche. -> sauve,&anneeEchange.);
		%transfererCases(&caseDroite. -> &caseGauche.,&anneeEchange.);
		%transfererCases(sauve -> &caseDroite.,&anneeEchange.);
		%let casesInutiles = &casesInutiles. sauve;
        %end;
	%mend;

%macro SuppressionVariablesInutiles();
    drop &casesInutiles. ;
    %mend;


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

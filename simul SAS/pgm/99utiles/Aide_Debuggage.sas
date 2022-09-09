/***************************************/
/* Petit programme d'aide au débuggage */
/***************************************/

/* Février 2015 (à l'occasion d'un travail sur le programme Cotisations où ne faire que des proc compare devient vite un enfer) */

%macro Compare(t1,t2,varBy);
	proc compare data=&t1. compare=&t2. method=absolute criterion=2; id &VarBy.; run;
	%mend Compare;

%macro Diff(t1=,t2=,varDiff=,varBy=);
	data Diff_&VarDiff.;
		merge &t1. (in=a rename=(&varDiff.=&varDiff._1)) &t2. (in=b rename=(&varDiff.=&varDiff._2));
		by &VarBy.;
		if a and b and &varDiff._1 ne &varDiff._2;
		run;
	data Diff_&VarDiff.;
		retain &varBy. &varDiff._1 &varDiff._2;
		set Diff_&VarDiff.;
		run;
	%mend Diff;

%Macro GrosEcarts(t1,t2,Var,Seuil,ListeVar1,ListeVar2,varBy=);
	data z_1;
		merge diff_&Var. (in=a keep=&VarBy. &Var.:) &t1. (keep=&VarBy. &ListeVar1.);
		if a and abs(&Var._1-&Var._2) gt &Seuil.;
		by &VarBy.;
		run;

	data z_2;
		merge diff_&Var. (in=a keep=&VarBy. &Var.:) &t2. (keep=&VarBy. &ListeVar2.);
		if a and abs(&Var._1-&Var._2) gt &Seuil.;
		by &VarBy.;
		run;
	%Mend;

/* Exemple d'utilisation sur une table individuelle */
%Compare(tableOld,tableNew,ident noi);
/* On repère une variable à problème */
%Diff(t1=tableNew,t2=tableOld,varDiff=VariableAvecDiff,VarBy=ident noi);
/* Avec un peu d'intuition et en s'aidant du code, on liste les variables générant potentiellement le problème */
%GrosEcarts(tableNew,tableOld,variableAvecDiff,10,Var1 Var2 Var3,Var1 Var2,VarBy=ident noi);
/* si par exemple Var3 n'existe pas dans tableOld car a été créée dans la modif que l'on est en train de tester */
/* on met ici un seuil de 10 pour voir */



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

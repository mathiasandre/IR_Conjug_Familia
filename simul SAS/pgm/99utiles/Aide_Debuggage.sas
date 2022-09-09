/***************************************/
/* Petit programme d'aide au d�buggage */
/***************************************/

/* F�vrier 2015 (� l'occasion d'un travail sur le programme Cotisations o� ne faire que des proc compare devient vite un enfer) */

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
/* On rep�re une variable � probl�me */
%Diff(t1=tableNew,t2=tableOld,varDiff=VariableAvecDiff,VarBy=ident noi);
/* Avec un peu d'intuition et en s'aidant du code, on liste les variables g�n�rant potentiellement le probl�me */
%GrosEcarts(tableNew,tableOld,variableAvecDiff,10,Var1 Var2 Var3,Var1 Var2,VarBy=ident noi);
/* si par exemple Var3 n'existe pas dans tableOld car a �t� cr��e dans la modif que l'on est en train de tester */
/* on met ici un seuil de 10 pour voir */



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

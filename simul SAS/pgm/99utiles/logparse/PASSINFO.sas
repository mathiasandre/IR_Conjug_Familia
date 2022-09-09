/******************************************************************
*
* The %PASSINFO macro prints session information to the SAS log
* for performance analysis. It is optional for use with the
* %LOGPARSE() macro, and both macros are experimental for SAS 9.1.
*
* See the Readme file for instructions.
*
*******************************************************************/


%macro passinfo;

  data _null_;
    length  hostname $ 80;
    hostname=' ';  /* avoid message about uninitialized */
    temp=datetime();
    temp2=lowcase(trim(left(put(temp,datetime16.))));
    call symputx('datetime', temp2);

  %if ( &SYSSCP = WIN )%then %do;  /* windows platforms */
	call symput('host', "%sysget(computername)");
	%end;
  %else %if ( &SYSSCP = OS ) %then %do; /* MVS platform */
    call symput('host', "&syshostname");
  	%end;
  %else %if ( &SYSSCP = VMS ) or ( &SYSSCP = VMS_AXP ) %then %do; /* VMS platform */
    hostname = nodename();
    call symput('host', hostname);
  	%end;
  %else %do;              /* all UNIX platforms */
    filename gethost pipe 'uname -n';
    infile gethost length=hostnamelen;
    input hostname $varying80. hostnamelen;
    call symput('host', hostname);
  	%end;

  	run;

  %put PASS HEADER BEGIN;
  %put PASS HEADER os=&sysscp;
  %put PASS HEADER os2=&sysscpl;
  %put PASS HEADER host=&host;
  %put PASS HEADER ver=&sysvlong;
  %put PASS HEADER date=&datetime;
  %put PASS HEADER parm=&sysparm;

  proc options option=MEMSIZE ; run;
  proc options option=SUMSIZE ; run;
  proc options option=SORTSIZE ; run;

  %put PASS HEADER END;

%mend passinfo;


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

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

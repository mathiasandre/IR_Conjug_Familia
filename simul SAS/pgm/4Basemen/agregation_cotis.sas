/****************************************************************/
/*																*/
/*				    agregation_cotis							*/
/*								 								*/
/****************************************************************/

/****************************************************************/
/* Agrégation des cotisations/contributions au niveau du ménage	*/
/* En entrée : modele.cotis										*/ 
/*			   modele.prelev_pat_n1				               	*/
/*			   modele.prelev_pat_n				               	*/
/*			   modele.csg_pat					               	*/
/* En sortie : modele.cotis_menage                             	*/
/****************************************************************/
/* REMARQUE : 													*/
/* On définit ici ce que sont les cotisations/contributions 	*/
/* assurantielles et redistributives. In fine, toutes les 		*/
/* cotisations sont assurantielles sauf les cotisations famille	*/
/* et la contribution de solidarité des fonctionnaires.			*/
/* Côté contributions, tout est redistributif sauf la part de 	*/
/* CSG affecté à la maladie.									*/
/****************************************************************/

%cumul(	basein=modele.cotis,
       	baseout=cotis,
       	varin= coMALs coMALp coFAs coFAp coACp coCHs coCHp coAGSp coREs coREp coMicro ContribExcSol coTAXp csgd csgi crdsi csg_mal casapr exo cice taxe_salaire taxe_75,
       	varout=coMALs coMALp coFAs coFAp coACp coCHs coCHp coAGSp coREs coREp coMicro ContribExcSol coTAXp csgd csgi crds_ar csg_mal casapr exo cice taxe_salaire taxe_75,
		varAgregation=ident);

%cumul(	modele.prelev_pat_n1,
		baseout=prelev_pat_n1,
		varin=  csgpatf csgdpatf crdspatf autrepspatf csgglof crdsglof autrepsglof crds_etr csg_etr contrib_sal,
		varout= csgpatm csgdpatm crdspatm autrepspatm csgglom crdsglom autrepsglom crds_etr csg_etr contrib_salm,
		varAgregation=ident);

%cumul(	modele.prelev_pat_n,
		baseout=prelev_pat_n,
		varin=  csgdivf crdsdivf autrepsdivf csgvalf crdsvalf autrepsvalf csgvalmob crdsvalmob autrepsvalmob,
		varout= csgdivm crdsdivm autrepsdivm csgvalm crdsvalm autrepsvalm csgvalmob crdsvalmob autrepsvalmob,
		varAgregation=ident);
   
proc sort data=modele.csg_pat; by ident; run;
data modele.cotis_menage
		(keep=	ident cotassu cotred coMicro coFAs coFAp tot_cotis Cotis_patro taxes_patro tot_cont contassu contred
				csgi csgd crds_ar casapr prelev_pat exo 
				tot_crdsm tot_csgm
				csgpatm crdspatm autrepspatm 
				csgvalmob crdsvalmob autrepsvalmob
				csgvalm crdsvalm autrepsvalm
				csgGlom crdsglom
				csgDivm crdsdivm autrepsdivm
				csg_etr crds_etr contrib_salm
				csgpat_im crdspat_im autrepsPat_im ContribExcSol CICE taxe_salaire taxe_75 charges_patro);
	merge 	cotis
			modele.csg_pat (keep= ident csgpat_im crdspat_im autrepsPat_im)
			prelev_pat_n
			prelev_pat_n1(in=b);
	by ident; 
	if not b then do; %Init_Valeur(csg_etr crds_etr); end; /*traitement des ménages EE_NRT comme dans l'ERFS */

	/* Cotisations */ 
	cotassu		=sum(0,coMals,coMAlp,coCHs,coCHp,coAGSp,coREs,coREp,coACp);
	cotred		=sum(0,coFAs,coFAp); 
	tot_cotis	=sum(0,cotassu,cotred,coMicro);
	Cotis_patro	=sum(0,coMALp,coFAp,coACp,coCHp,coAGSp,coREp);
	taxes_patro	=sum(0,coTAXp,taxe_salaire,-CICE, taxe_75);
	charges_patro=cotis_patro+taxes_patro;

	/* Contributions sociales */
	prelev_pat	=sum(0,csgpatm,crdspatm,autrepspatm,csgvalmob,crdsvalmob,autrepsvalmob,csgvalm,crdsvalm,autrepsvalm,
				 csgpat_im,crdspat_im,autrepspat_im);
	*prelev_pat=prelev_pat+csgglom+csgdivm+contrib_salm; /*a décommenter si on rajoute les revenus exceptionnels au revenu disponible */ 
	contassu	=sum(0,csg_mal,csg_etr*&Tcsg_mal./(&Tcsgd.+&Tcsgi.),sum(csgpatm,csgvalmob,csgvalm,csgpat_im)*&csg_pat_mal./&csg_pat_moy.);
	tot_cont	=sum(0,csgi,csgd,csg_etr,crds_ar,crds_etr,casapr,prelev_pat,ContribExcSol);
	contred		=tot_cont-contassu;

	/* définition de la CSG et de la CRDS (hors presta)*/ 
	tot_csgm	=sum(0,csgi,csgd,csg_etr,csgpatm,csgvalmob,csgvalm,csgpat_im);
	tot_crdsm	=sum(0,crds_ar,crds_etr,crdspatm,crdsvalmob,crdsvalm,crdspat_im); 

	label   coMicro		=	"Cotisations et contributions des micro-entrepreneurs"
			cotassu		=	"Cotisations dites assurantielles (hors ME)"
			cotred		=	"Cotisations dites redistributives (hors ME)"
			tot_cotis	=	"Cotisations (y compris forfait micro-entrepreneurs)"
			cotis_patro =	"Cotisations patronales"
			taxes_patro	=	"Taxes patronales"
			prelev_pat	=	"Prelevements sur les revenus du patrimoine et crds sur les revenus étrangers"
			contassu	= 	"Contributions sociales assurantielles"
			contred		=	"Contributions sociales redistributives"
			tot_cont	=	"Contributions sociales (hors micro-entrepreneurs)"
			tot_csgm	=	"CSG totale"
			tot_crdsm	=	"CRDS totale sauf sur les prestations";
	run;


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

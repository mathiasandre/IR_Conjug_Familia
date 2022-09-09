/****************************************************/
/*          Programme Macros_OrgaCases				*/ 
/*			Organisation de cases fiscales			*/
/****************************************************/

/********************************************************************************/
/* En entrée : rien																*/
/* En sortie :des macrovariables (listes)										*/
/*																				*/
/* PLAN																			*/
/* 1\ Macro %ListeCasesAgregatsERFS												*/
/* 2\ Macro %ListeCasesIndividualisees											*/
/********************************************************************************/

/********************************************************************************/
/*	Ce programme organise les cases fiscales utilisées dans le code d'Ines. 	*/
/* A METTRE A JOUR CHAQUE ANNEE (en même temps qu'init_foyer)					*/
/*	Confer page Wiki pour plus de détails										*/
/*	Pour chaque case on définit ainsi : 										*/
/*	- à quel agrégat elle appartient, le cas échéant 							*/
/*		-> macro %ListeCasesAgregatsERFS										*/
/*	- à quel individu de la déclaration elle se réfère							*/
/*		-> macro %ListeCasesIndividualisees										*/
/*	Cette 2ème macro fait aussi la distinction entre les cases qui sont des 	*/
/* montants (donc à vieillir) et celles qui n'en sont pas (à cocher, heures...).*/
/*																				*/
/* Toutes les cases ne font pas partie d'un agrégat (première macro). 			*/
/* En revanche, toutes doivent comporter un type (deuxième macro). 				*/
/*																				*/
/* Les cases n'existant plus dans la brochure la plus récente (et donc plus 	*/
/* utilisées dans Ines), ont le type "Variable disparue". 						*/
/* Cela permet qu'aucun bug ne soit généré en utilisant des vieux millésimes. 	*/
/* CES MACROS-VARIABLES SERONT UTILISEES DANS FOYERVARTYPE ET EVOL_REVENUS. 	*/
/********************************************************************************/


/************************************/
/* 1\ Macro %ListeCasesAgregatsERFS */
/************************************/

%Macro ListeCasesAgregatsERFS;
	/* Cette macro définit des macrovariables globales contenant la liste des cases définissant les différents agrégats de l'ERFS. 
	Objectif : recréer des agrégats au niveau du foyer pour ne pas avoir à revenir toujours aux cases fiscales pour certains calculs où il n'est 
	pas nécessaire de le faire. Cela réduit légèrement le nombre de modifications à apporter lors de la mise à jour annuelle. 

	A chaque nouvelle ERFS N il faut mettre à jour ces agrégats en faisant comme si l'on travaillait sur l'ERFS N+1, 
	puisque dans init_foyer on crée les cases fiscales qui apparaissent dans la déclaration de l'IR N+2 sur les revenus de l'année N+1 
	(on n'aura ces cases dans l'ERFS que pour le millésime suivant). 
	La mise à jour de cette macro s'effectue sur la base du nouveau contour des agrégats transmis par RPM chaque année. 

	NB : Toutefois, comme les cases qu'on crée sont généralement vides, on ne fait pas trop d'erreur en se contentant de 
	mettre à jour avec les agrégats ERFS de l'année N (décrits dans le bilan de production). */
	%global zsalfP zchofP zrstfP zpifP zalrfP zrtofP zragfP zragfN cbicf_ zricfP zricfN cbncf_ zrncfP zrncfN zvalfP zavffP
			zvamfP zvamfN zfonfP zfonfN caccf_ zracfP zracfN zetrfP zalvfP zglofP zquofP zdivfP zdivfN;

	/* 1. Revenus d'activité et de remplacement */
	/* 1.a. Traitements et salaires au sens large */
	%let zsalfP=_1aj _1bj _1cj _1dj _1ej _1fj
				_1af _1bf _1cf _1df _1ef _1ff
				_1ag _1bg _1cg _1dg _1eg _1fg
				_1aq _1bq _8by _8cy _1tp _1up
				_1nx _1ox _1pm _1qm;			/* traitements et salaires */ 

	%let zchofP=_1ap _1bp _1cp _1dp _1ep _1fp;	/* préretraites et revenus du chômage */

	/* 1.b. Pensions, retraites et rentes */
	%let zrstfP=_1as _1bs _1cs _1ds _1es _1fs _1at _1bt /* retraites au sens stricte */ 
				_1al _1bl _1cl _1dl _1el _1fl /* retraites au sens stricte - etranger */ 
				_1am _1bm _1cm _1dm _1em _1fm;	/* Autres penstion - etranger*/
	%let zpifP=_1az _1bz _1cz _1dz _1ez _1fz;				/* pensions d'invalidité */
	%let zalrfP=_1ao _1bo _1co _1do _1eo _1fo;				/* pensions alimentaires recues */ 
	%let zrtofP=_1aw _1bw _1cw _1dw						/* rentes viagères à titre onéreux */ 
				_1ar _1br _1cr _1dr;					/* rentes viagères à titre onéreux - Etranger*/ 


	/* 1.c. Revenus des professions non-salariées */
			/* Revenus agricoles */
	%let zragfP=_5xa _5ya _5za _5xb _5yb _5zb				/* régime du forfait */ 
				_5hd _5id _5jd	 							/* revenu cadastral des exploitations forestières */ 
				_5hb _5hh _5ib _5ih _5jb _5jh
				_5hc _5hi _5ic _5ii _5jc _5ji
				_5ak _5bk _5ck _5al _5bl _5cl
				_5xt _5xv _5xu _5xw							/* régime du bénéfice réel */ 
				_5hm _5hz _5im _5iz _5jm _5jz;				/* revenu non imposable pour les jeunes agriculteurs */ 
	%let zragfN=_5hf _5hl _5if _5il _5jf _5jl;				/* déficits de l'année d'imposition */ 

			/* Abattement forfaitaire pour les revenus industriels et commerciaux professionnels */ 
	%let cbicf_= _5ko _5kp _5lo _5lp _5mo _5mp _5ta _5tb _5ua _5ub _5va _5vb;
		
			/* Revenus industriels et commerciaux professionnels */ 
	%let zricfP=_5ta _5ua _5va
				_5tb _5ub _5vb	 							/* régime de l'auto-entrepreneur */ 
				_5kn _5ln _5mn								/* revenus nets exonérés du régime micro-entreprise */
				_5ko _5lo _5mo _5kp _5lp _5mp				/* chiffres d'aff. bruts du régime micro-entreprise */
				_5kb _5kh _5lb _5lh _5mb _5mh
				_5kc _5ki _5lc _5li _5mc _5mi
				_5df _5dg _5ef _5eg _5ff _5fg				/* régime du bénéfice réel */
				_5ks _5ls _5ms; 							/* revenus non imposables des artisans pêcheurs */
	%let zricfN=_5kf _5kl _5lf _5ll _5mf _5ml;				/* déficits de l'année d'imposition */

			/* Abattement forfaitaire pour les revenus non commerciaux professionnels */ 
	%let cbncf_=_5hq _5iq _5jq _5te _5ue _5ve;
				
		  	/* Revenus non commerciaux professionnels */ 
	%let zrncfP=_5te _5ue _5ve 						/* régime de l'auto-entrepreneur */ 
				_5hp _5ip _5jp 						/* revenus nets exonérés du régime micro BNC */ 
				_5hq _5iq _5jq 						/* recettes brutes du régime micro BNC */ 
				_5qb _5qh _5rb _5rh _5sb _5sh 
				_5qc _5xj _5qi _5xk _5rc _5yj _5ri _5yk _5sc _5zj _5si _5zk 		/* régime de la déclaration contrôlée */ 
				_5ql _5rl _5sl 						/* revenus non imposables des jeunes créateurs */
				_5qm _5rm    						/* indemnités des agents généraux d'assurances */
				_5tf _5ti _5uf _5ui _5vf _5vi;	 	/* prospection commerciale */
	%let zrncfN=_5qe _5qk _5re _5rk _5se _5sk;		/* déficits de l'année d'imposition */

	/* 2. Revenus du patrimoine */
	/* 2.a. Revenus des valeurs et capitaux mobiliers */
	%let zvalfP=_2ee _2dh;						/* Revenus de valeurs mob. soumis au prélèv. lib. */
	/* NB : l'agrégat ménage de l'ERFS n'inclut pas 2dh pour des raisons de double compte (cf bilan de production) mais il faut bien l'inclure ici */
	%let zavffP=_2ab _2ck _2bg _8ta _8vl _8vm _8wm _8um;			/* Crédits d'impôts */
	%let zvamfP=_2dc _2fu _2ch _2ts _2go _2tr _2fa _2dm _2tt;
	/* NB : l'agrégat ménage de l'ERFS n'inclut pas 2ch pour des raisons de double compte (cf bilan de production) mais il faut bien l'inclure ici */

	/* 2.b. Revenus fonciers */
	%let zfonfP=_4ba _4be; /* TODO : si on veut faire comme l'agrégat ERFS, c'est 0.7*_4be et non 4be */
	%let zfonfN=_4bb _4bc;
	
	/* 3. Revenus accessoires et perçus à l'étranger */
	/* 3.a. Revenus accessoires */
			/* Abattement forfaitaire pour les loueurs en meublé non professionnel */
	%let caccf_=_5no _5ng _5nj _5np _5nd _5ku _5oo _5og _5oj _5op _5od _5lu _5po _5pg _5pj _5pp _5pd _5mu;
	%let zracfP=_5na _5ey _5nm _5nk _5ez _5km _5oa _5fy _5om _5ok _5fz _5lm _5pa _5gy _5pm _5pk _5gz _5mm 
				_5nn _5on _5pn 
				_5no _5ng _5nj _5oo _5og _5oj _5po _5pg _5pj 
				_5np _5nd _5op _5od _5pp _5pd 
				_5nb _5nh _5ob _5oh _5pb _5ph 
				_5nc _5ur _5ni _5us _5oc _5vr _5oi _5vs _5pc _5wr _5pi _5ws
				_5th _5uh _5vh 
				_5ku _5lu _5mu 
				_5hk _5ik _5jk _5kk _5lk _5mk 
				_5jg _5xs _5sn _5xx _5rf _5ys _5ns _5yx _5sf _5zs _5os _5zx 
				_5sv _5sw _5sx  
				_5tc _5uc _5vc; 	
	%let zracfN=_5ny _5nz _5oy _5oz _5py _5pz
				_5nf _5nl _5of _5ol _5pf _5pl			
				_5jj _5sp _5rg _5nu _5sg _5ou;

	/* 3.b. Revenus perçus à l'étranger */
	%let zetrfP=_8ti _1dy _1ey _1ac _1bc _1cc _1dc _1ah _1bh _1ch _1dh;
	/* /!\ A partir de l'ERFS 2015 faire attention au traitement des salaires à l'étranger et les prélèvements CSG/CRDS. */
	
	/* 4. pensions alimentaires versées */
	%let zalvfP=_6gi _6gj _6gk _6gl _6el _6em _6en _6eq _6gp _6gu;
	
	/* 5. Revenus exceptionnels non retenus pour l'enquête */
	%let zglofP=_1tx _1ux _1tt _1ut _1tz 
				_3vd _3vi _3vf _3vj _3vk; /* gains de levée d'options */
	%let zquofP=_0xx; 							/* revenus d'activité imposés au quotient */
	%let zdivfP=	/* Plus-values */
				_3vg _3vq _3se _3sg _3sl _3va _3vb _3vo _3vp
				_3vc _3vm _3sj _3sk _3vt
				_3we _3wm _3vz _3wg _3sb _3wd _3wi _3wj _3vw 
				_5hw _5iw _5jw _5hx _5ix _5jx _5he _5ie _5je _5kx _5lx _5mx _5kq _5lq _5mq
				_5ke _5le _5me _5nx _5ox _5px _5nq _5oq _5pq _5ne _5oe _5pe _5hv _5iv _5jv 
				_5hr _5ir _5jr _5qd _5rd _5sd _5ky _5ly _5my _5kv _5lv _5mv _5so _5nt _5ot _5hg _5ig;
	%let zdivfN=	/* Moins-values */
				_3vh _3vr _5kr _5lr _5mr _5kj _5lj _5mj _5nr _5or _5pr _5iu
				_5rz _5sz _5hs _5is _5js _5kz _5lz _5mz _5kw _5lw _5mw _5ju _5ld _5md
				_5xo _5yo _5zo _5xn _5yn _5zn;
	%Mend ListeCasesAgregatsERFS;


/***************************************/
/* 2\ Macro %ListeCasesIndividualisees */
/***************************************/

%macro ListeCasesIndividualisees;

	/* Plan de la macro : 
	- on établit un certain nombre de listes de cases fiscales en fonction de l'individu
		-- on considère 5 individus (vous, conj, pac1, pac2, foyer=non individualisable)
		-- pour chaque individu, on distingue les cases avec des montants des autres (à cocher, ou nombre d'heures ...)
		-- cas particuliers : VarAns, ListVarDisp, ListVarInconnues */

	/***************************************/
	/* COMMENT METTRE A JOUR CETTE MACRO ? */
	/***************************************/
	/* La mise à jour va de paire avec celle du programme init_foyer : lorsqu'une nouvelle case apparaît ou change de nom, il faut lui donner un type
	en l'ajoutant dans la liste idoine selon l'individu qu'elle concerne et le type de case (à cocher ou non). 

	De la même manière que la macro %ListeCasesAgregatsERFS, cette macro doit être mise à jour chaque année sur la base de la brochure fiscale la plus récente
	(anleg-1, égale à anr1 dans l'utilisation la plus classique où anleg=anref+2). 
	Etant donné le peu d'utilisations que l'on fait de ces deux macros, on accepte la perte de précision sur le passé. */

	/* TODO : Vérifier que les listes définies ici n'incluent bien que des variables de montants sommables, 
	et non d'autres quantités (type "nombre d'heures"). */

	%global
		ListVousRev ListVousAutres
		ListConjRev ListConjAutres
		ListPac1Rev ListPac1Autres
		ListPac2Rev ListPac2Autres ListPac3Rev ListPac3Autres ListPac4Rev
		ListNonIndivRev ListNonIndivAutres
		NomsExpliRev NomsExpliAutres
		listVarDisp listVarInconnues;

	/* VARIABLES DE 'VOUS' */
	%let ListVousRev=	_1aj _1ga _1af _1ag _1am _1al  _1ap _1ak _1as _1az _1ao _1aq _1at
						_1ac _1ae _1ah _1tp _1nx _1pm
						_1tx _1tt _1ny
						_5nn _5no _5np _5nx _5nq _5nr _5nb _5nc _5ur _5nd _5na _5ey _5nf _5ng _5ny 
						_5ne _5nh _5ni _5us _5nj _5nk _5ez _5nl _5nm _5nz 
						_5xa _5xb _5hd _5hw _5xo _5xn _5hx _5hb _5hh _5hc _5ak _5hi _5al _5hf _5hl _5he _5hm _5hp 
						_5hq _5hv _5hr _5hs _5hy _5hz _5hg
						_5ta _5tb _5tc _5te _5tf _5ti _5th 
						_5kn _5ko _5kp _5kx _5kq _5kr _5kb _5kh _5kc _5ki _5df _5dg _5kd _5kj _5kf 
						_5kl _5km _5ke _5ks _5ku _5ky _5kv _5kw 
						_5qb _5qc _5xj _5qe _5qd _5ql _5qm _5qh _5qi _5xk _5qk 
						_1dy _1sm _6rs _6ps _6qs _7ac _8by _5hk _5ik _5jg _5xs _5sn _5xx _5jj 
						_5sp _5so _5sv _5tc
						_5tj _5tk _5tl _5tm _5xt _5xv
						_5iu _5ju
						_5xd _5xe _5xf _5xg
						_5aq _5ar _5ay _5az _5dk _5dl _5dm _5dn _5ut _5uu _5uy _5uz _5xp _5xq _5xh _5xl _5xy _5xz _5vm _5vn;
	%let ListVousAutres=_1ai _8va _5ad _5db _5cd _5up _5xi _5xr _5af _5bf _5cf _5an _5ao _5xr _5xc _5ap;


	/* VARIABLES DE 'CONJ' */
	%let ListConjRev=	_1bj _1ha _1bf _1bg _1bm _1bl _1bp _1bk _1bs _1bz _1bo _1bq _1bt
						_1bc _1be _1bh _1up _1ox _1qm
						_1ux _1ut _1oy
						_5on _5oo _5op _5ox _5oq _5or _5ob _5oc _5vr _5od _5oa _5fy _5of _5og _5oy 
						_5oe _5oh _5oi _5vs _5oj _5ok _5fz _5ol _5om _5oz 
						_5ya _5yb _5id _5iw _5yo _5yn _5ix _5ib _5ih _5ic _5bk _5ii _5bl _5if _5il _5ie _5im _5ip 
						_5iq _5iv _5ir _5is _5iy _5iz _5ig 
						_5ua _5ub _5uc _5ue _5uf _5ui _5uh 
						_5ln _5lo _5lp _5lx _5lq _5lr _5lb _5lh _5lc _5li _5ef _5eg _5ld _5lj _5lf 
						_5ll _5lm _5le _5ls _5lu _5ly _5lv _5lw _5lz
						_5rb _5rc _5yj _5re _5rd _5rl _5rm _5rh _5ri _5yk _5rk
						_1ey _1dn _6rt _6pt _6qt _7ae _8cy _5jk _5kk _5rf _5ys _5ns _5yx _5rg 
						_5nu _5nt _5sw _5uc 
						_5uj _5uk _5ul _5um _5xu _5xw
						_5rz _5ld
						_5yd _5ye _5yf _5yg
						_5bq _5br _5by _5bz _5ek _5el _5em _5en _5vt _5vu _5vy _5vz _5yp _5yq _5yh _5yl _5yy _5yz _5wm _5wn;
	%let ListConjAutres=_1bi _8vb _5bd _5eb _5dd _5vp _5yi _5yr _5ai _5bi _5ci _5bn _5bo _5yr _5yc _5bp;

	/* VARIABLES DE 'PAC1' */
	%let ListPac1Rev=	_1cj _1ia _1cf _1cg _1cm _1cl  _1cp _1ck _1cs _1cz _1co 
						_1cc _1ce _1ch
						_6gi _6el _6ru _6pu _6qu 
						_7ag
						_5za _5zb _5jd _5jw _5zo _5zn _5jx _5jb _5jh _5jc _5ck _5ji _5cl _5jf _5jl _5je _5jm _5va _5vb _5mn 
						_5mo _5mp _5mx _5mq _5mr _5mb _5mh _5mc _5mi _5ff _5fg _5mj _5mf _5ml _5mm 
						_5me _5ms _5vc _5pn _5po _5pp _5px _5pq _5pr _5pb _5ph _5pc _5wr _5pi _5ws _5pd _5pj _5pa _5gy 
						_5pk _5gz _5pf _5pl _5pg _5pm _5py _5pz _5pe _5ve _5jp _5jq _5jv _5jr _5js _5sb _5sh _5sc _5zj _5si _5zk
						_5se _5sk _5sd _5sl _5vf _5vi _5vh _5mu _5my _5mv _5mw _5mz _5lk _5mk _5sf _5zs _5os _5zx _5sg 
						_5ou _5ot _5sx _5jy _5jz _5vc _5sz _5md
						_5zd _5ze _5zf _5zg;
	%let ListPac1Autres=_1ci _5zc;

	/* VARIABLES DE 'PAC2','PAC3' et 'PAC4' */
	 %let ListPac2Rev=	_1df _1dg _1dm _1dl 
						_6gj _6em _1dj _1ja _1dp _1dk _1ds _1dz _1do _1dc _1dd _1de _1dh
						_1dc _1de _1dh;
	 %let ListPac2Autres=_1di _ndj _rdj;
	 %let ListPac3Rev= _1ef _1eg _1em _1el  _1ej _1ka _1eu _1ep _1ek _1es _1eo _1ez _6gk _6en;
	 %let ListPac3Autres=_1ei _rej;
	 %let ListPac4Rev=_1fj _1la _1ff _1fg _1fm _1fl  _1fu _1fz _6gl _6eq;

	/* VARIABLES DE FOYER NON INDIVIDUALISEES */
	%let ListNonIndivRev=_1aw _1bw _1cw _1dw _1tz _1uz _1vz _1ar _1br _1cr _1dr  _1er _1fr
					_2ck _2dh _2ee _2dc _2fu _2ch _2ts _2go _2tr _2fa _2cg _2bh _2ca _2ab _2bg _2dm _2tt _2tu
					_3sb _3sa _3se _3sl 
					_3vg _3vh _3sg _3vd _3vi _3vf _3vj _3vk _3vn _3sj _3sk _3ve _3vm _3vc _3ub _3uo _3up
					_3va _3vb _3vq _3vr _3vt _3vu _3vw _3vz _3wa _3ta _3wb _3tb _3wd _3ua _3vo _3vp
					_3we _3wh _3wm _3wn _3wo _3wg _3wj _3wi _3wp _3wq _3wr _3ws _3wt _3wu _3tz _3uz
					_4be _4bk _4ba _4bl _4bb _4bc _4bd _4bf _4by _4bh
					_5kz
					_5ga _5gb _5gc _5gd _5ge _5gf _5gg _5gh _5gi _5gj
					_6ev _6eu _6cb _6gh
					_7aa _7ad _7af _7ah _7ak _7al _7am _7an _7aq _7ar _7av _7ax _7ay _7az _7bb _7bc _7bd _7be _7bf _7cb _7bm
					_7db _7df _7dd
					_7cd _7ce _7cf _7cl _7cm _7cn _7cc _7cu _7cq _7cr _7cv _7cy _7dy _7cx _7ey
					_7ff _7fg _7fh _7fq _7fl _7fm _7fn
					_7gj _7gl
					_7gz _7gn _7gs
					_7ha _7hd _7hf 
					_7ja _7jf _7jk _7jo _7jb _7jg _7jl _7jp	_7jd _7jh _7jm _7jq _7je _7jj _7jn _7jr
					_7jt _7ju _7jv _7jw _7jx _7jy _7iy
					_7sy _7sx 
					_7fa _7fb _7fc _7fd 
					_7gh _7gi _7el _7ek
					_7qd _7qc _7qb _7qa
					_7ai _7bi _7ci _7di 
					_7bz _7cz _7dz _7ez
					_7fi _7fk _7fr
					_7qe _7qf _7qg _7qh
					_7qi _7qj _7qk _7ql
					_7na _7nf _7nk _7np _7nb _7ng _7nl _7nq _7nc _7nh _7nm _7nr
					_7nd _7ni _7nn _7ns _7ne _7nj _7no _7nt
					_7hj _7hk _7hn _7ho _7hr _7hs _7hv _7hw _7hx _7hz _7ht _7hu
					_7ij _7il _7id _7ie _7im _7ik _7iu _7ix
					_7in _7iv _7if _7ig _7iw _7ip _7iq  _7ir _7ia _7ib _7ic _7it _7ih _7iz _7ji
					_7kb _7kc _7kd _7ke
					_7lb _7lc _7le _7ld _7lf _7lm _7ls _7ln _7lt _7lx _7lz
					_7mh _7mg
					_7nz
					_7oa _7ob _7oc _7od _7oe _7ou 
					_7pa _7pb _7pc _7pd _7pe 
					_7gq
					_7re _7rf
					_7bh _7bk _7bl
					_7va _7vb _7vc _7vd
					_7td  
					_7ua _7ub _7ui _7ut _7ud _7uf _7ug _7um _7un _7uo _7up _7uq _7ul _7uc _7uh _7uk _7us _7te _7uu _7uv _7tf
					_7vm _7tm _7vn _7to
					_7tg _7ux _7th _7ti _7vp _7tk _7tj
					_7vx _7vz _7vt
					_7wj _7wl _7wm _7wn _7wo _7wp
					_7xl _7xp _7xq _7xn _7xv _7uy _7uz 
					_7yb _7yd _7yf _7yh _7yj _7yk _7yl
					_7ym _7yn _7yo _7yp _7yq _7yr _7ys
					_7yt _7yu _7yv _7yw _7yx _7yy _7yz
					_7lg _7lh _7li _7lj
					_7lk _7ll _7lo _7lp
					_8sa _8sb
					_8ut _8ti _8tk _8ta _8th _8vl _8vm _8wm _8um
					_8tm _8tn _8tf _8te _8tg _8ts _8to _8tp _8tq _8tr _8tv _8tw _8tx _8tb _8tc _8wr _8wt _8wu _8uy
					_8tz _8uz _8wb _8wa _8wc _8wd _8we
					_6de _6gp _6gu _6dd
					_0xx
					_haa _hab _hac _hae _haf _hag _hah _haj _hak _hal _ham _hao _hap
					_haq _har _hat _hau _hav _haw _hay _hba _hbb _hbe _hbg
					_hra _hrb _hrc _hrd _hqc _hqd _hsz _hta _htb _htd
					_huo _hup _huq _hur _hus _hut _huu
					_hxl _hxm _hxn _hxo _hxp
					_hci _hcj _hcn _hco _hck _hcp _hcl _hcq _hcm _hcr _hcs _hct _hcu _hcv _hcw
					_hnu _hnv _hnw _hny _hoa _hob _hoc _hod _hoe _hof _hog _hoh
					_hoi _hoj _hok _hol _hom _hon _hoo _hop _hoq _hor _hos _hot _hou
					_hov _how _hox _hoy _hoz _hpa _hpb _hpd _hpe _hpf _hph _hpi _hpj
					_hpl _hpm _hpn _hpo _hpp _hpr _hps _hpt _hpu _hpw _hpx _hpy
					_hqb _hqe _hqf _hqg _hqi _hqj _hqk _hql _hqm _hqn _hqo
					_hqp _hqr _hqs _hqt _hqu _hqv _hqw _hqx
					_hrg _hri _hrj _hrk _hrl _hrm _hro _hrp _hrq _hrr _hrt _hru _hrv
					_hrw _hry _hsa _hsb _hsc _hse _hsf _hsg _hsh _hsj _hsk
					_hsl _hsm _hso _hsp _hsq _hsr _hst _hsu _hsv _hsw _hsy
					_hua _hub _huc _hud _hue _huf _hug
					_hxa _hxb _hxc _hxe
					_huh _hui _huj _huk _hul _hum _hun _hxf _hxg _hxh _hxi _hxk _hja
					_hbi _hbj _hbn _hbo _hbk _hbp _hbm _hbr _hbs _hbt _hbx _hby _hbu _hbz _hbw _hcb _hcc _hcd _hce _hcg
					_7qj _7qs _7qw _7qx
					_7gu _7gv _7gw _7gx _7jc _7js
					_8tl _8uw
					_9fg _9hi _9pv _9mx _9na _9nc _9ne _9nf _9ng _9rs
					_7ga _7gb _7gc _7ge _7gf _7gg
					_2aa _2al _2am _2an _2aq _2ar
					_4tq
					_5qf _5qg _5qn _5qo _5qp _5qq
					_5rn _5ro _5rp _5rq _5rr _5rw 
					_5ht _5it _5jt _5kt _5lt _5mt
					_6fa _6fb _6fc _6fd _6fe _6fl
					_6hj _6hk _6hl _6hm _6hn _6ho _6hp
					_7xs _7xt _7xu _7xw _7xy
					_7ql _7qt
					_7ok _7ol _7om _7on _7oo
					_7ov _7ow
					_7of _7og _7oh _7oi _7oj 
					_7pf _7pg _7ph _7pi _7pj
					_7pk _7pl _7pm _7pn _7po
					_7wr _7ls
					_7nu _7nv _7nw _7nx _7ny
					_8sc _8sw _8sx
					_7bx _7by _7mx _7my
					_7za _7zb _7zc _7zd
					_7zw _7zx _7zy _7zz;
	%let ListNonIndivAutres=	_4bz _6qr _6qw _7dq _7dg _7dl _7we _7xd _7xe _hqa _7ii 
								_8fv _8tt _8uu _9gl _9gm _7wg _7vo _8td
								_7ea _7ec _7ef _7eb _7ed _7eg
								_4bn
								_0wa _2p3wg _8ru _8rv _8ww _8xi _8xj _8xl _8yp _9yf _9yh _9za	;

	 /* CAS PARTICULIERS */

	/* Noms explicites : cases disparues un jour mais dont on a voulu garder l'information
	(si l'on souhaite garder la possibilité de simuler le dispositif sur des vieilles législations) */
	/* Attention rappel : tout doit être en minuscules. */

	/* Cases représentant des montants */
	%let NomsExpliRev=	
				/* 2006 */	_interet_pret_conso _credformation _glovsup4ansvous _glovsup4ansconj
				/* 2007 */	_relocalisation _perte_capital _perte_capital_passe
				/* 2009 */	_cirechant _cinouvtechn _demenage_emploivous _demenage_emploiconj _demenage_emploipac1 _demenage_emploipac2
				/* 2010 */	_epargnecodev _revpea _ciformationsalaries
				/* 2011 */	_invdomaut1 _invdomaut2
				/* 2012 */ 	_pvcessiondom /* plus-values */ _dep_devldura_loc1 _dep_devldura_loc2 _dep_devldura_loc3 _dep_devldura_loc4
							_souscsofipeche _revimpcrds
				/* 2013 */ 	_depinvloctour_2011_1 _depinvloctour_2011_2 _depinvloctour_ap2011_1 _depinvloctour_ap2011_2
							_depinvloctour_av2011_1 _depinvloctour_av2011_2 _dep_asc_traction _ci_debitant_tabac 
							_pvcession_entrepreneur /* plus-values */ _hsupvous _hsupconj _hsuppac1 _hsuppac2 _glo_txfaible _glo_txmoyen
				/* 2014 */ 	_1annui_lgtneuf _1annui_lgtancien _protect_patnat _cred_loc
				/* 2015 */ 	_1annui_lgtneufnonbbc _abatt_moinsval _abatt_moinsval_renfor _abatt_moinsval_dirpme
							_impot_etr_dec1 _impot_etr_dec2 _impot_etr_pac1 _impot_etr_pac2
							_rsa_compact_ppe_f _rsa_compact_ppe_pac1 _rsa_compact_ppe_pac2
							_deduc_invest_loc2009 _rachatretraite_vous _rachatretraite_conj
				/* 2016 */  _glo1_2ansvous _glo1_2ansconj _glo2_3ansvous _glo2_3ansconj _nonbbc_2010
							;							  
							
	/* Autres cases (nombres, années, cases à cocher) qui ne doivent pas être vieillies */
	%let NomsExpliAutres=	/* Nombres */	_nb_vehicpropre_simple _nb_vehicpropre_destr _nb_convention _nb_convention_hand 
							  	_nbheur_ppe_dec1 _nbheur_ppe_dec2 _nbheur_ppe_pac1 _nbheur_ppe_pac2
							   	_pro_act_jour_dec1 _pro_act_jour_dec2 _pro_act_jour_pac
							  	/* Cases à cocher */ 
							  	_bouquet_travaux _maison_indivi _tpsplein_ppe_dec1 _tpsplein_ppe_dec2 _tpsplein_ppe_pac1 _tpsplein_ppe_pac2
							  	_pro_act_annee_dec1 _pro_act_annee_dec2 _pro_act_annee_pac
							  	_report_ri_dom_entr /* Montant mais variable disparue (information réapparue dans une case fiscale) */
							  	_moit_fenetres _moit_murs _moit_toits _sinistre /* Indicatrices créées temporairement pour traiter correctement d'autres cases, mais sont ensuite supprimées */ 						
								;

/* 	Liste des variables qui n'existent pas dans la version la plus récente de la brochure pratique mais qui ont existé par le passé
		Objectif de cette liste : pour que ça n'affiche pas d'erreurs quel que soit le millésime utilisé. 
		De plus sa constitution permet de repérer beaucoup de bugs. */
	%let listVarDisp=	
			/* 2005 */ 	_1fk _1fi _1rx _1rv
			/* 2007 */ 	_1qx _1qv _4bl _1er
			/* 2008 */ 	
			/* 2009 */  _6eh _7ur /*_1ar _1br _1cr _1dr*/
			/* 2010 */ 	_2gr _8ws _8wx _5kg _5lg _5md _5mg _5td _5tg _5ud _5ug _5vd _5vg
			/* 2012 */ 	_5hu _7fy _7gy _7hy _7ky  _7qq _7pg _7pk _7oz _9mn _9mo
			/* 2013 */ 	_1ty _1uy _2da _7wq _7kh _7ki
						_7qn _7qu _7qk _7qy _7qm 
						_7op _7oq _7or _7os _7ot
						_7pm _7pn _7po _7pp _7pq _7pr _7ps _7pt _7pu _7pv _7pw _7px _7py _7ry
						_7pz _7qz _7mm _7ma
						_7ks _7mn _7mb _7kt _7mc _7ku _7qv _7qo _7qp _7qr _7qi
						_7pl _7wf _7ws _7wx _7wa _7ve _7vf
						_8wv _7xg _7xa _7xx _7xh _7xz _3vs _3ss _3so
						_7kg
						_3wc
						_7tu _7ue _7ug
			/* 2014 */	_3vv _1au _1bu _1cu _1du _7vy _7vw _3vl _3vp _3vy _3uv _3wf
						 _7xf _7xm _1lz _1mz _7xo _7ka _hsd _hsi _hsn _hss _hsx _htc _hqz _1fc
			/* 2015 */  _3sd _3si _3sf _3sn _2la _2lb _3sh _3sm _1ad _1bd _1cd _1dd _1ax _1bx _1cx _1dx _1ex _1fx
						_1av _1bv _1cv _1dv _1ev _1fv _1bl _1cb _1dq /*_1ag _1bg _1cg _1dg*/ _5nw _5ow _5pw _5nv _5ov _5pv
						_hkg _hmm _hlg _hma _hks _had _hai _han _has _hax _hbf _7wk _7rx
						_7ya _7yc _7ye _7yg _7yi _7gk _7gp _7gt _7hb _7he _7xk
						_6ss _6st _6su _7vu _7ly _7my _7nm
			/*2016*/    _1tv _1tw _1uv _1uw _3sc
						_5ha _5ka _5ia _5la _5ja _5ma _5qa _5qj _5ra _5rj _5sa _5sj
						_5hn _5in _5jn _5ho _5io _5jo 
						_7sd _7sa _7ta
					    _7se _7sb _7tb
					    _7sf _7sc _7tc
					    _7wc _7wb _7xb
					    _7sg _7rg _7xc
					    _7vg _7vh _7wh
					    _7sh _7rh _7wi
					    _7si _7ri _7vi
					    _7wt _7wu _7wv
					    _7sj _7rj _7ww
					    _7sk _7rk _7vk
					    _7sl _7rl _7vl
					    _7sn _7rn _7tn
					    _7sp _7rp _7tp
					    _7sr _7rr _7tr
					    _7ss _7rs _7ts
					    _7sq _7rq _7tq
					    _7st _7rt _7tt
					    _7sv _7tv _7tx
					    _7sw _7tw _7ty
					 	     _7rv _7ru
					 	     _7rw _7su
					 	     _7rm _7sm
					 	     _7ro _7so
					 	     _7rz _7sz
						_7vv _7hl _7hm _7hg _7hh _7la _7io _7is
						_7rd _7rb _7rc _7ra _7xi _7xj _7xr _7uw
						_hmn _hlh _hmb _hkt _hli _hmc _hku
						_hbl _hbq _hbv _hca _hcf _hkh _hki
			;										

	/* Liste des variables qui ont été livrées pour une raison inconnue à partir de l'ERFS 2013 (absentes de la brochure fiscale) */
	/* Piste : cases de la 2042-Mayotte ? */
	%let listVarInconnues=
					_2ctjcj _2ctjpc _2ctjvs _2ctpcj _2ctppc _2ctpvs _2dbarf _2dcrc _2dcrp _2dcrv _2diarf _2iavet _2ibaet _2icr _2ics
					_2ifire _2ifr _2imisp _2inrro _2ipsde _2ipsrf _2irmpo _2irpni _2irsba _2isfga _2iso _2iti1 _2iti2 _2p19sp _2pautr
					_2pbssp _2pgnab _2pimmo _2prcm _2prnnx _2prrts _2punim _2pvnab _2pvnah _2pvnai _2pvnaj _2pwng _2tbes _2tbesc 
					_2tshc1 _2tshcj _2tshvs _2tspc1 _2tspcj _2tspvs
					_cic _cii _cjc _daj _dbj _eaj _ebj
					_naw _nbo _nbw _ncj _ncp _ndo _nes _nfs _ngo _raw _rbo _rbw _rcj _rcp _rdo _res _rfs _rgo
					_1fd _29yd
					_7gm _7wd
					_8pa
					_8uv _8ux _8vv _8vw _8vx _8xf _8xg _8xh _8xk _8xv _8yd _8ye _8yf _8yh _8yj _8yk _8yl _8yt _8yz _8zb _8zh _8zi _8zo _8zt _8zu
					_9yt _9yu _9yz
					_29yr /* (date de retour en france) : finalement livrée dans l'ERFS 2014 mais dont on ne se sert pas et qu'on a jamais eu avant */ 
					/* cases n'existant pas mais dont on a besoin dans Ines (pàc 4 ...) */
				 	_1fp _1fs _1fo
					/*ERFS 2015 : bcp de cases livrées sans documentation ou obsolète. */
					_0ra /* pour info :  contribution à l'audiovisuel public  (vaut 1 si on coche la case) */	
					_0ta 	_0sa	_0va	_1ec	_1ee	/*_1ef	_1eg*/   _1eh		_1et	_1ed	_1fh	_2ics75	_2p3sc								
					_3vx	_7gd	_7wy	_7wz	_8tj	_8tu	_8ty	_8xa	_8xb	_8xc	_8xd	_8xe	_8xp	
					_8xq	_8xr	_8xt	_8xy	_8ya	_8yb	_8yc	_8yi	_8ym	_8yn	_8yo	_8yq	_8yr	
					_8ys	_8yu	_8yw	_8yx	_8yy	_8za	_8zf	_8zg	_8zj	_8zk	_8zl	_8zm	_8zn	
					_8zp	_8zr	_8zs	_8zv	_8zw	_8zx	_8zz	_9yd	_9yi	_9yp	_9yr	_9zu	_9zv	
					_aps	_apt	_apu	_bps	_bpt	_bpu	_chc	_chi	_cps	_cpt	_cpu	_dps	_dpt	
					_dpu	_fas	_fat	_fbs	_fbt	_naj	_nao	_nap	_nas	_naz	_nba	_nbj	_nbp	
					_nbs	_nbz	_nch	_nco	_ncs	_ncw	_ncz	_ndc	_nds	_ndw	_nfu	_ntr	_nts	
					_nvg	_raj	_rao	_rap	_ras	_raz	_rba	_rbj	_rbp	_rbs	_rbz	_rch	_rco	
					_rcs	_rcw	_rcz	_rdc	_rds	_rdw	_rfu	_rtr	_rts	_rvg	_sba	_tba	_zza	_zzb;

	%Mend ListeCasesIndividualisees;

/* Exécution des macros */
%ListeCasesAgregatsERFS;
%ListeCasesIndividualisees;


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

-----------------------
-----------------------

Readme for logparse.zip

-----------------------
-----------------------


This ZIP archive contains the SAS files logparse.sas, and passinfo.sas,
for SAS 9.3 and later releases.  See the section
"Using the Files in this Archive" below for information about how
to use these files.  See the section "Syntax of %LOGPARSE()"
below for descriptions of the arguments to the %LOGPARSE() macro.

The logparse.sas file defines the %LOGPARSE() macro.

   The %LOGPARSE() macro reads performance statistics from a SAS log
   and stores them in a SAS data file.  To create those performance
   statistics, specify the FULLSTIMER option when you execute the
   program whose performance you want to report or analyze.

   Steps in a SAS program following the %LOGPARSE() macro invocation
   can be used to subset, summarize, analyze, and report on the
   performance statistics that were extracted by %LOGPARSE().

The passinfo.sas file defines the %PASSINFO() macro.

   Use of %PASSINFO() is optional, but it includes information in the
   SAS log that vastly improves the output of %LOGPARSE().


-------------------------------
Using the Files in this Archive
-------------------------------

In the following instructions, myprogram.sas is the program whose
performance statistics you want to measure.

1. Save logparse.sas, and passinfo.sas to a directory
   on your computer.

2. Specify the FULLSTIMER option in an OPTIONS statement at the
   beginning of myprogram.sas, or on the command line.

3. Add these statements to define and invoke %PASSINFO() at the
   beginning of myprogram.sas :

   %include passinfo;
   %passinfo;

4. Create a new SAS program ("readlog.sas" in this example) that calls
   the %LOGPARSE() macro.

   For example, the following code could be contained in a readlog.sas
   program that runs in batch under Windows to report performance data
   from myprogram.log file that was created on a UNIX system:

   %include logparse;
   %logparse( myprogram.log, myperfdata, OTH );
   proc print data=myperfdata;
   run;
   /* Add subsetting, analysis, and reporting here. */

5. Run myprogram.sas and save the log in the file myprogram.log.

6. Run readlog.sas to collect and print the performance statistics.


----------------------
Syntax of %LOGPARSE()
----------------------

   %logparse(saslog, outds, system, pdsloc, append=no)

where:

   saslog  = SAS log file (for MVS, see "pdsloc" below).
   outds   = output SAS data set for results (optional):
             - if not specified, WORK.DATAn is created, where n is
               the smallest integer that makes the name unique (same
               behavior as "data; x = 1; run;").
             - if specified, names the data set created by
               this invocation of %logparse().
             - if specified and append=yes is specified, see
               documentation of the append= parameter, below.
   system  = 3-character operating system code. This parameter is
             optional; the default value is the sysem on which
             %logparse() is run. Valid codes are:
              z/OS, OS/390, or MVS    = MVS or OS
              OpenVMS Alpha           = ALP
              OpenVMS VAX             = VMS
              All other OSs           = OTH
             For more information, see "SYSSCP and SYSSCPL Automatic
             Macro Variables" in SAS Macro Language: Reference:
             Macro Language Dictionary in the SAS online documentation.
   pdsloc  = When %logparse() is executed on an MVS system and the SAS
             log file to be analyzed is stored in a partitioned data
             set (PDS), "pdsloc" partially names the PDS and "saslog"
             names the member.  The PDS name is generated with a
             leading period (making your userid the first level of the
             name) and the lowest level LOGS.
             Example:  SAS log is MYACCT.PRJ5.GRP24.LOGS(TEST47)
                       %logparse(test47, , , prj5.grp24);
   append  = create or append to the output data set (see the
             "outds" parameter, above).  This parameter is optional;
             the default value is NO.  Valid values are YES and NO:
             NO  = %logparse() creates a new SAS file according to the
                   rules for the outds parameter, above.
             YES = %logparse() appends its output to the file named by
                   the outds parameter (the file is created if it does
                   not already exist).
             Example:  %logparse(mypgm.log, lpout, VMS, append=yes);


----------
References
----------

For more information about FULLSTIMER, see "Optimizing System
Performance" in SAS Language Reference: Concepts: SAS System Concepts
in the SAS online documentation.


----------
Disclaimer
----------

THIS DOCUMENTATION IS PROVIDED "AS IS" WITHOUT WARRANTY
OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE, OR NON-INFRINGEMENT. The Institute shall not be
liable whatsoever for any damages arising out of the use of this
documentation, including any direct, indirect, or consequential
damages. The Institute reserves the right to alter or abandon use of
this documentation at any time. In addition, the Institute will
provide no support for the materials contained herein.


Copyright (c) 2008, SAS Institute Inc., Cary, NC, USA. All rights reserved.

RESTRICTED RIGHTS LEGEND 	
Use, duplication, or disclosure by the U.S. Government is subject to
restrictions as set forth in subparagraph (c)(1)(ii) of the Rights in
Technical Data and Computer Software clause at DFARS 252.227-7013.
SAS INSTITUTE INC., SAS CAMPUS DRIVE, CARY, NORTH CAROLINA USA 27513


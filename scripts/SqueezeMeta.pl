#!/usr/bin/perl

# (c) Javier Tamames, CNB-CSIC

$|=1;

my $commandline=$0 . " ". (join " ", @ARGV);

use Time::Seconds;
use Cwd;
use Getopt::Long;
use Tie::IxHash;
use lib ".";
use strict;

my $version="0.5.0, Feb 2019";
my $start_run = time();

###scriptdir patch, Fernando Puente-Sánchez, 29-V-2018
use File::Basename;
our $scriptdir = dirname(__FILE__);
our $installpath = "$scriptdir/..";
###

our $pwd=cwd();
our($nocog,$nokegg,$nopfam,$opt_db,$nobins,$nomaxbin,$nometabat,$lowmem,$minion,$doublepass)="0";
our($numsamples,$numthreads,$canumem,$mode,$mincontiglen,$assembler,$mapper,$project,$equivfile,$rawfastq,$blocksize,$evalue,$miniden,$assembler_options,$cleaning,$cleaningoptions,$ver,$hel);
our($databasepath,$extdatapath,$softdir,$basedir,$datapath,$interdir,$resultpath,$tempdir,$interdir,$mappingfile,$contigsfna,$contigslen,$mcountfile,$rnafile,$gff_file,$aafile,$ntfile,$daafile,$taxdiamond,$cogdiamond,$keggdiamond,$pfamhmmer,$fun3tax,$fun3kegg,$fun3cog,$fun3pfam,$allorfs,$alllog,$mapcountfile,$contigcov,$contigtable,$mergedfile,$bintax,$bincov,$bintable,$contigsinbins,$coglist,$kegglist,$pfamlist,$taxlist,$nr_db,$cog_db,$kegg_db,$lca_db,$bowtieref,$pfam_db,$metabat_soft,$maxbin_soft,$spades_soft,$barrnap_soft,$bowtie2_build_soft,$bowtie2_x_soft,$bwa_soft,$minimap2_soft,$bedtools_soft,$diamond_soft,$hmmer_soft,$megahit_soft,$prinseq_soft,$prodigal_soft,$cdhit_soft,$toamos_soft,$minimus2_soft,$canu_soft,$trimmomatic_soft,$dastool_soft);
our(%bindirs,%dasdir);  

#-- Define help text

my $helptext = <<END_MESSAGE;
Usage: SqueezeMeta.pl -m <mode> -p <projectname> -s <equivfile> -f <raw fastq dir> <options>

Arguments:

 Mandatory parameters:
   -m: Mode (sequential, coassembly, merged) (REQUIRED)
   -s|-samples: Samples file (REQUIRED)
   -f|-seq: Fastq read files' directory (REQUIRED)
   -p: Project name (REQUIRED in coassembly and merged modes)
   
 Filtering: 
   --cleaning: Filters with Trimmomatic (Default: No)
   -cleaning_options: Options for Trimmomatic (Default:LEADING:8 TRAILING:8 SLIDINGWINDOW:10:15 MINLEN:30)
   
 Assembly: 
   -a: assembler [megahit,spades,canu] (Default: megahit)
   -assembly_options: Options for required assembler
   -c|-contiglen: Minimum length of contigs (Default: 200)
   
 Mapping: 
   -map: mapping software [bowtie,bwa,minimap2-ont,minimap2-pb,minimap2-sr] (Default: bowtie) 

 Annotation:  
   --nocog: Skip COG assignment (Default: no)
   --nokegg: Skip KEGG assignment (Default: no)
   --nopfam: Skip Pfam assignment  (Default: no)
   --extdb: Annotations for user-provided databases (must contain a list of databases)
   -b|-block-size: block size for diamond against the nr database (Default: 8)
   -e|-evalue: max evalue for discarding hits diamond run  (Default: 1e-03)
   -miniden: identity perc for discarding hits in diamond run  (Default: 50)
   -D|--doublepass: First pass looking for genes using gene prediction, second pass using BlastX  (Default: no)
   
 Binning:
   --nobins: Skip all binning  (Default: no)
   --nomaxbin: Skip MaxBin binning  (Default: no)
   --nometabat: Skip MetaBat2 binning  (Default: no)
   
 Performance:
   -t: Number of threads (Default: 12)
   -canumem: memory for canu in Gb (Default: 32)
   --lowmem: run on less than 16Gb of memory (Default:no)

 Other:
   --minion: Run on MinION reads (use canu and minimap2) (Default: no)
   
 Information:
   -v: Version number  
   -h: This help 
     
END_MESSAGE

#-- Handle variables from command line

my $result = GetOptions ("t=i" => \$numthreads,
                     "lowmem" => \$lowmem,
		     "canumem=i" => \$canumem,
                     "m|mode=s" => \$mode,
                     "c|contiglen=i" => \$mincontiglen,
                     "a=s" => \$assembler,
                     "map=s" => \$mapper,
                     "p=s" => \$project,
                     "s|samples=s" => \$equivfile,
                     "f|seq=s" => \$rawfastq, 
		     "nocog" => \$nocog,   
		     "nokegg" => \$nokegg,   
		     "nopfam" => \$nopfam,  
		     "extdb=s" => \$opt_db, 
		     "nobins" => \$nobins,   
		     "nomaxbin" => \$nomaxbin,   
		     "nometabat" => \$nometabat,  
		     "D|doublepass" => \$doublepass, 
		     "b|block_size=i" => \$blocksize,
		     "e|evalue=f" => \$evalue,   
		     "minidentity=f" => \$miniden,   
		     "assembly_options=s" => \$assembler_options,
		     "cleaning" => \$cleaning,
		     "cleaning_options=s" => \$cleaningoptions,
                     "minion" => \$minion,
		     "v" => \$ver,
		     "h" => \$hel
		    );

#-- Set some default values

if(!$numthreads) { $numthreads=12; }
if(!$canumem) { $canumem=32; }
if(!$mincontiglen) { $mincontiglen=200; }
if(!$assembler) { $assembler="megahit"; }
if(!$mapper) { $mapper="bowtie"; }
if(!$blocksize) { $blocksize=8; }
if(!$evalue) { $evalue=1e-03; }
if(!$miniden) { $miniden=50; }
if(!$nocog) { $nocog=0; }
if(!$nokegg) { $nokegg=0; }
if(!$nopfam) { $nopfam=0; }
if(!$doublepass) { $doublepass=0; }
if(!$nobins) { $nobins=0; }
if(!$nomaxbin) { $nomaxbin=0; }
if(!$nometabat) { $nometabat=0; }
if(!$cleaningoptions) { $cleaningoptions="LEADING:8 TRAILING:8 SLIDINGWINDOW:10:15 MINLEN:30"; }
if(!$cleaning) { $cleaning=0; $cleaningoptions=""; } 

#-- Override settings if running on lowmem or MinION mode.
if($lowmem) { $blocksize=3; $canumem=15; }

if($minion) { $assembler="canu"; $mapper="minimap2-ont"; }

#-- Check if we have all the needed options


print "\nSqueezeMeta v$version - (c) J. Tamames, F. Puente-Sánchez CNB-CSIC, Madrid, SPAIN\n\nPlease cite: Tamames & Puente-Sanchez, Frontiers in Microbiology 10.3389 (2019). doi: https://doi.org/10.3389/fmicb.2018.03349\n\n";

my $dietext;
if($ver) { exit; }
if($hel) { die "$helptext\n"; } 
if(!$rawfastq) { $dietext.="MISSING ARGUMENT: -f|-seq: Fastq read files' directory\n"; }
if(!$equivfile) { $dietext.="MISSING ARGUMENT: -s|-samples: Samples file\n"; }
if(!$mode) { $dietext.="MISSING ARGUMENT: -m: Run mode (sequential, coassembly, merged)\n"; }
if(($mode!~/sequential/i) && (!$project)) { $dietext.="MISSING ARGUMENT: -p: Project name\n"; }
if(($mode=~/sequential/i) && ($project)) { $dietext.="Please DO NOT specify project name in sequential mode. The name will be read from the samples in the samples file $equivfile\n"; }
if($mode!~/sequential|coassembly|merged/i) { $dietext.="UNRECOGNIZED run mode $mode\n"; }
if($mapper!~/bowtie|bwa|minimap2-ont|minimap2-pb|minimap2-sr/i) { $dietext.="UNRECOGNIZED mapper $mapper\n"; }
if($rawfastq=~/^\//) {} else { $rawfastq="$pwd/$rawfastq"; }

if($dietext) { die "$dietext\n$helptext\n"; }

my $currtime=timediff();
print "Run started ",scalar localtime," in $mode mode\n";


#--------------------------------------------------------------------------------------------------
#----------------------------------- SEQUENTIAL MODE ----------------------------------------------

if($mode=~/sequential/i) { 

	my(%allsamples,%ident,%noassembly);
	my($sample,$file,$iden,$mapreq);
	tie %allsamples,"Tie::IxHash";

	#-- Reading the sample file given by the -s option, to locate the sample files

	print "Now reading samples\n";
	open(infile1,$equivfile) || die "Cannot open samples file (-s) in $equivfile. Please check if that is the correct file, it is present tin that location, and you have reading permissions\n";
	while(<infile1>) {
		chomp;
		next if(!$_ || ($_=~/^\#/));
		($sample,$file,$iden,$mapreq)=split(/\t/,$_);
		if((!$sample) || (!$file) || (!$iden)) { die "Bad format in samples file $equivfile\n"; }
		$allsamples{$sample}{$file}=1;
		$ident{$sample}{$file}=$iden;
		if($mapreq && ($mapreq=~/noassembly/i)) { $noassembly{$file}=1; }   #-- Files marked for no assembly (but they will be mapped)
	}
	close infile1;

	my @nmg=keys %allsamples;
	$numsamples=$#nmg+1;
	print "$numsamples metagenomes found";
	print "\n";

	open(outfile1,">$pwd/global_progress") || die "Cannot write in directory $pwd\n";  	#-- An index indicating where are we and which parts of the method finished already. For the global process
	open(outfile2,">$pwd/global_syslog") || die "Cannot write in directory $pwd\n"; 		 #-- A log file for the global proccess
	print outfile2 "\nSqueezeMeta v$version - (c) J. Tamames, F. Puente-Sánchez CNB-CSIC, Madrid, SPAIN\n\nPlease cite: Tamames & Puente-Sanchez, Frontiers in Microbiology 10.3389 (2019). doi: https://doi.org/10.3389/fmicb.2018.03349\n\n";
	print outfile2 "Run started ",scalar localtime," in SEQUENTIAL mode (it will proccess all metagenomes sequentially)\n";
	print outfile2 "Command: $commandline\n"; 
	print outfile2 "Options: threads=$numthreads; contiglen=$mincontiglen; assembler=$assembler; sample file=$equivfile; raw fastq=$rawfastq\n";

	#-- Now we start processing each sample individually

	foreach my $thissample(keys %allsamples) {

		#-- We start creating directories, progress and log files

		$project=$thissample;
		my $projectdir="$pwd/$thissample";
		if (-d $projectdir) { die "Project name $projectdir already exists. Please remove it or change the project name\n"; } else { system("mkdir $projectdir"); }
		print "Working with $thissample\n";
		print outfile1 ">$thissample\n";
	
		open(outfile3,">$projectdir/progress") || die "Cannot write in directory $projectdir. Wrong permissions, or out of space?\n";  #-- An index indicating where are we and which parts of the method finished already. For the global process
		open(outfile4,">$projectdir/syslog") || die "Cannot write in directory $projectdir. Wrong permissions, or out of space?\n";  	#-- A log file for the global proccess
		$currtime=timediff();
		print outfile4 "Run started ",scalar localtime," in SEQUENTIAL mode (it will proccess all metagenomes sequentially)\n";
		print "Run started ",scalar localtime," in SEQUENTIAL mode\n";
		my $params = join(" ", @ARGV);
		print outfile2 "$0 $params\n";
		print outfile2 "Run started for $thissample, ",scalar localtime,"\n";
		print outfile4 "Project: $project\n";
		print outfile4 "Map file: $equivfile\n";
		print outfile4 "Fastq directory: $rawfastq\n";
		print outfile4 "[",$currtime->pretty,"]: STEP0 -> SqueezeMeta.pl\n";
		print outfile2 "[",$currtime->pretty,"]: STEP0 -> SqueezeMeta.pl\n";
		print "Now creating directories\n";
		open(infile2,"$scriptdir/SqueezeMeta_conf.pl") || die "Cannot open conf file $scriptdir/SqueezeMeta_conf.pl";
	
		#-- Creation of the new configuration file for this sample
	
		open(outfile5,">$projectdir/SqueezeMeta_conf.pl") || die "Cannot write in directory $projectdir. Out of space?\n";

		print outfile5 "\$mode=\"$mode\";\n\n";
		print outfile5 "\$installpath=\"$installpath\";\n";

		while(<infile2>) {
			chomp;
			next if !$_;
			if($_=~/^\$basedir/) { print outfile5 "\$basedir=\"$pwd\";\n"; }
			elsif($_=~/^\$projectname/) { print outfile5 "\$projectname=\"$project\";\n"; }
			elsif($_=~/^\$blocksize/) { print outfile5 "\$blocksize=$blocksize;\n"; }
			elsif($_=~/^\$evalue/) { print outfile5 "\$evalue=$evalue;\n"; }
			elsif($_=~/^\$miniden/) { print outfile5 "\$miniden=$miniden;\n"; }
			elsif($_=~/^\$nocog/) { print outfile5 "\$nocog=$nocog;\n"; }
			elsif($_=~/^\$nokegg/) { print outfile5 "\$nokegg=$nokegg;\n"; }
			elsif($_=~/^\$nopfam/) { print outfile5 "\$nopfam=$nopfam;\n"; }
			elsif($_=~/^\$doublepass/) { print outfile5 "\$doublepass=$doublepass;\n"; }
			elsif($_=~/^\$nobins/) { print outfile5 "\$nobins=$nobins;\n"; }
			elsif($_=~/^\$nomaxbin/) { print outfile5 "\$nomaxbin=$nomaxbin;\n"; }
			elsif($_=~/^\$nometabat/) { print outfile5 "\$nometabat=$nometabat;\n"; }
			elsif($_=~/^\$mapper/) { print outfile5 "\$mapper=\"$mapper\";\n"; }
			elsif($_=~/^\$cleaning\b/) { print outfile5 "\$cleaning=$cleaning;\n"; }
			elsif($_=~/^\$cleaningoptions/) { print outfile5 "\$cleaningoptions=\"$cleaningoptions\";\n"; }
			else { print outfile5 "$_\n"; }
		}
	 	close infile2; 

		print outfile5 "\n#-- Options\n\n\$numthreads=$numthreads;\n\$mincontiglen=$mincontiglen;\n\$assembler=\"$assembler\";\n\$canumem=$canumem;\n";
		if($assembler_options) { print outfile5 "\$assembler_options=\"$assembler_options\"\n"; }
		if($opt_db) { print outfile5 "\$opt_db=\"$opt_db\"\n"; }
		close outfile5;

		#-- Creation of directories
 
		print "Reading configuration from $projectdir/SqueezeMeta_conf.pl\n";
		do "$projectdir/SqueezeMeta_conf.pl";
		system ("mkdir $datapath");
 		system ("mkdir $resultpath");
 		system ("mkdir $tempdir");
 		system ("mkdir $datapath/raw_fastq"); 
 		system ("mkdir $datapath/ext_tables"); 
		system ("mkdir $interdir");
	
		#-- Linkage of files to put them into our data directories
	
		print "Now linking read files\n";
 		foreach my $file(sort keys %{ $allsamples{$thissample} }) {
 			 if(-e "$rawfastq/$file") { 
  				my $tufile="$datapath/raw_fastq/$file";
 				# system("cp $rawfastq/$file $tufile");
 				 system("ln -s $rawfastq/$file $tufile");
 				# if($tufile!~/\.gz$/) { system("gzip $datapath/raw_fastq/$file"); }
			}
 			 else { die "Cannot find read file $file (Sample $sample). Please check if it exists\n"; }

	system("cp $equivfile $mappingfile");
	
		}

		#-- Preparing the files for the assembly, merging all files corresponding to each pair

 		my($par1files,$par2files)=0;
		my($par1name,$par2name);
 		print "Now preparing files\n";
 		my($ca1,$ca2)="";
 		foreach my $afiles(sort keys %{ $ident{$thissample} }) {
 			next if($noassembly{$afiles});
  			my $gzfiles=$afiles;
  			#if($gzfiles!~/gz$/) { $gzfiles.=".gz"; }
 			if($ident{$thissample}{$afiles} eq "pair1") { $ca1.="$datapath/raw_fastq/$gzfiles "; $par1files++; } 
			else { $ca2.="$datapath/raw_fastq/$gzfiles "; $par2files++; } 
			if($gzfiles=~/gz$/) { $par1name="$datapath/raw_fastq/par1.fastq.gz"; $par2name="$datapath/raw_fastq/par2.fastq.gz"; }  # Fixed bug 30/10/2018 JT
			else { $par1name="$datapath/raw_fastq/par1.fastq"; $par2name="$datapath/raw_fastq/par2.fastq"; }
		}
		if($par1files>1) { 
			my $command="cat $ca1 > $par1name"; 
			print "$command\n"; 
			system($command); 
		} 
		else {
			#my $command="cp $ca1 $par1name"; 
			my $command="ln -s $ca1 $par1name";
			print "$command\n";
			system($command);
 
		}
 		if($par2files>1) { system("cat $ca2 > $par2name"); } 
		elsif ($par2files==1) { system("ln -s $ca2 $par2name"); }    #-- Support for single reads
		#else { system("cp $ca2 $par2name"); }
		#-- CALL TO THE STANDARD PIPELINE
		
		pipeline();
		
		
 		close outfile4;		#-- Closing log file for the sample
 		close outfile3;		#-- Closing progress file for the sample
							       
	}    #-- End of this sample, go for the next

}            #-- END


#-----------------------------------------------------------------------------------------------------
#----------------------------------- COASSEMBLY AND MERGED MODES -------------------------------------

else {

	my $projectdir="$pwd/$project";
	if (-d $projectdir) { die "Project name $projectdir already exists. pLease remove it or change project name\n"; } else { system("mkdir $projectdir"); }
		
	#-- We start creating directories, progress and log files

	open(outfile3,">$pwd/$project/progress") || die "Cannot write in $pwd/$project. Wrong permissions, or out of space?\n";  #-- Un indice que indica en que punto estamos (que procedimientos han terminado)
	open(outfile4,">$pwd/$project/syslog") || die "Cannot write in $pwd/$project. Wrong permissions, or out of space?\n";
	my $params = join(" ", @ARGV);
	print outfile4 "$0 $params\n";
	print outfile4 "Run started ",scalar localtime," in $mode mode\n";
	print outfile4 "Command: $commandline\n"; 
	print outfile4 "Project: $project\n";
	print outfile4 "Map file: $equivfile\n";
	print outfile4 "Fastq directory: $rawfastq\n";
	print outfile4 "Options: threads=$numthreads; contiglen=$mincontiglen; assembler=$assembler; mapper=$mapper; evalue=$evalue; miniden=$miniden;";
	if(!$nocog) { print outfile4 " COGS;"; }
	if(!$nokegg) { print outfile4 " KEGG;"; }
	if(!$nopfam) { print outfile4 " PFAM;"; }
	if($opt_db) { print outfile4 " EXT_DB: $opt_db;"; }
	if($doublepass) { print outfile4 " DOUBLEPASS;"; }
	if($lowmem) { print outfile4 " LOW MEMOERY;"; }
	print outfile4 "\n";
	print outfile4 "[",$currtime->pretty,"]: STEP0 -> SqueezeMeta.pl\n";

	print "Now creating directories\n";
	
	#-- Creation of the new configuration file for this sample
	open(infile3,"$scriptdir/SqueezeMeta_conf.pl") || die "Cannot open $scriptdir/SqueezeMeta_conf.pl\n";
	open(outfile6,">$projectdir/SqueezeMeta_conf.pl") || die "Cannot write in directory $projectdir. Wrong permissions, or out of space?\n";

	print outfile6 "\$mode=\"$mode\";\n\n";
	print outfile6 "\$installpath=\"$installpath\";\n";
	while(<infile3>) {
		if($_=~/^\$basedir/) { print outfile6 "\$basedir=\"$pwd\";\n"; }
		elsif($_=~/^\$projectname/) { print outfile6 "\$projectname=\"$project\";\n"; }
		elsif($_=~/^\$blocksize/) { print outfile6 "\$blocksize=$blocksize;\n"; }
		elsif($_=~/^\$evalue/) { print outfile6 "\$evalue=$evalue;\n"; }
		elsif($_=~/^\$miniden/) { print outfile6 "\$miniden=$miniden;\n"; }
		elsif($_=~/^\$nocog/) { print outfile6 "\$nocog=$nocog;\n"; }
		elsif($_=~/^\$nokegg/) { print outfile6 "\$nokegg=$nokegg;\n"; }
		elsif($_=~/^\$nopfam/) { print outfile6 "\$nopfam=$nopfam;\n"; }
		elsif($_=~/^\$nobins/) { print outfile6 "\$nobins=$nobins;\n"; }
		elsif($_=~/^\$nomaxbin/) { print outfile6 "\$nomaxbin=$nomaxbin;\n"; }
		elsif($_=~/^\$nometabat/) { print outfile6 "\$nometabat=$nometabat;\n"; }
		elsif($_=~/^\$doublepass/) { print outfile6 "\$doublepass=$doublepass;\n"; }
		elsif($_=~/^\$mapper/) { print outfile6 "\$mapper=\"$mapper\";\n"; }
		elsif($_=~/^\$cleaning\b/) { print outfile6 "\$cleaning=$cleaning;\n"; }
		elsif($_=~/^\$cleaningoptions/) { print outfile6 "\$cleaningoptions=\"$cleaningoptions\";\n"; }
		elsif(($_=~/^\%bindirs/) && ($nomaxbin)) { print outfile6 "\%bindirs=(\"metabat2\",\"\$resultpath/metabat2\");\n"; }
		elsif(($_=~/^\%bindirs/) && ($nometabat)) { print outfile6 "\%bindirs=(\"maxbin\",\"\$resultpath/maxbin\");\n"; }
		else { print outfile6 $_; }
	 }
	close infile3;

 	print outfile6 "\n#-- Options\n\n\$numthreads=$numthreads;\n\$mincontiglen=$mincontiglen;\n\$assembler=\"$assembler\";\n\$canumem=$canumem;\n";
	if($assembler_options) { print outfile6 "\$assembler_options=\"$assembler_options\""; }
	if($opt_db) { print outfile6 "\$opt_db=\"$opt_db\"\n"; }
	close outfile6;

	print "Reading configuration from $projectdir/SqueezeMeta_conf.pl\n";
	do "$projectdir/SqueezeMeta_conf.pl" || die "Cannot write in directory $projectdir. Wrong permissions, or out of space?\n";

	
	#-- Creation of directories
	
	system ("mkdir $datapath");
	system ("mkdir $resultpath");
	system ("mkdir $tempdir");
	system ("mkdir $datapath/raw_fastq"); 
 	system ("mkdir $datapath/ext_tables"); 
	system ("mkdir $interdir");
 
	#-- Preparing the files for the assembly
	   
	moving();
	
	#-- CALL TO THE STANDARD PIPELINE
	
	pipeline();
	
	close outfile4;  #-- Closing log file for the sample
	close outfile3;	  #-- Closing progress file for the sample

}                        #------ END


#----------------------------PREPARING FILES FOR MERGING AND COASSEMBLY MODES-------------------------------------------

sub moving {

	print "Now moving read files\n";
	
	#-- Reading samples from the file specified with -s option
	
	my(%allsamples,%ident,%noassembly);
	open(infile4,$equivfile) || die "Cannot open samples file (-s) in $equivfile. Please check if that is the correct file, it is present tin that location, and you have reading permissions\n";
	while(<infile4>) {
 		chomp;
 		next if(!$_ || ($_=~/^\#/));
		my ($sample,$file,$iden,$mapreq)=split(/\t/,$_);
		if((!$sample) || (!$file) || (!$iden)) { die "Bad format in samples file $equivfile. Please check that all entries have sample ID, file name and pair number\n"; }
		$allsamples{$sample}=1;
		$ident{$file}=$iden;
		if(($mapreq) && ($mapreq=~/noassembly/i)) { $noassembly{$file}=1; }    #-- Files flagged for no assembly (but they will be mapped)
		if(-e "$rawfastq/$file") { 
			my $tufile="$datapath/raw_fastq/$file";
			# system("cp $rawfastq/$file $tufile");
			system("ln -s $rawfastq/$file $tufile");
			# if($tufile!~/\.gz$/) { system("gzip $datapath/raw_fastq/$file"); }
		}
		else { die "Cannot find read file $file (Sample $sample)\n"; }
	}
	close infile4;

	#-- Setting number of samples for running binning or not

	my @nmg=keys %allsamples;
	$numsamples=$#nmg+1;
	print outfile3 "Samples:$numsamples\nMode:$mode\n0\n";
	if($numsamples==1) { print "$numsamples sample found: Skipping all binning methods\n"; }
	else { print "$numsamples samples found\n"; }

	system("cp $equivfile $mappingfile");

	#-- For coassembly mode, we merge all individual files for each pair

	if($mode=~/coassembly/) {
		print "Now merging files\n";
		my($par1name,$par2name,$par1files,$par2files,$ca1,$ca2);
		foreach my $afiles(sort keys %ident) {
			next if($noassembly{$afiles});
			my $gzfiles=$afiles;
			# if($gzfiles!~/gz$/) { $gzfiles.=".gz"; }
			if($gzfiles=~/gz$/) { $par1name="$datapath/raw_fastq/par1.fastq.gz"; $par2name="$datapath/raw_fastq/par2.fastq.gz"; }
			else { $par1name="$datapath/raw_fastq/par1.fastq"; $par2name="$datapath/raw_fastq/par2.fastq"; }
			if($ident{$afiles} eq "pair1") { $ca1.="$datapath/raw_fastq/$gzfiles "; $par1files++; } else { $ca2.="$datapath/raw_fastq/$gzfiles "; $par2files++; } 
		}
  
		if($par1files>1) { system("cat $ca1 > $par1name"); } else { system("ln -s $ca1 $par1name"); }
		if($par2files>1) { system("cat $ca2 > $par2name"); } elsif($par2files==1) { system("ln -s $ca2 $par2name"); }  #-- Support for single reads
	}
}               #-- END


#---------------------------------------- TIME CALCULATIONS --------------------------------

sub timediff {
	my $end_run = time();
	my $run_time = $end_run - $start_run;
	my $timesp = Time::Seconds->new( $run_time );
	return $timesp;
}

#---------------------------------------- PIPELINE --------------------------------

sub pipeline {

	if(-e "$tempdir/$project.log") { system("rm $tempdir/$project.log"); }
	my $rpoint=0;
	my $DAS_Tool_empty=0;


    #-------------------------------- STEP1: Run assembly

		#-- In coassembly mode

	if($mode=~/coassembly/) {
		my $scriptname="01.run_assembly.pl";
		print outfile3 "1\t$scriptname ($assembler)\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP1 -> $scriptname ($assembler)\n";
		print "[",$currtime->pretty,"]: STEP1 -> RUNNING CO-ASSEMBLY: $scriptname ($assembler)\n";
		my $ecode = system("perl $scriptdir/$scriptname $project ");
		if($ecode!=0)        { die "Stopping in STEP1 -> $scriptname ($assembler)\n"; }
		my $wc=qx(wc -l $contigsfna);
		my($wsize,$rest)=split(/\s+/,$wc);
		if($wsize<2)         { die "Stopping in STEP1 -> $scriptname ($assembler). File $contigsfna is empty!\n"; }
	}

		#-- In merged mode. Includes merging assemblies

	elsif($mode=~/merged/) {
		my $scriptname="01.run_assembly_merged.pl";
		print outfile3 "1\t$scriptname\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP1 -> $scriptname ($assembler)\n";
		print "[",$currtime->pretty,"]: STEP1 -> RUNNING ASSEMBLY: $scriptname ($assembler)\n";
		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)        { die "Stopping in STEP1 -> $scriptname ($assembler). File $contigsfna is empty!\n"; }
	
			#-- Merging individual assemblies
 
		my $scriptname="01.merge_assemblies.pl";
		print outfile3 "1.5\t$scriptname\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP1.5 -> $scriptname\n";
		print "[",$currtime->pretty,"]: STEP1.5 -> MERGING ASSEMBLIES: $scriptname\n";
		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)        { die "Stopping in STEP1.5 -> $scriptname\n"; }
		my $wc=qx(wc -l $contigsfna);
		my($wsize,$rest)=split(/\s+/,$wc);
		if($wsize<2)         { die "Stopping in STEP1.5 -> $scriptname. File $contigsfna is empty!\n"; }
	}
	
		#-- In sequential mode. 

	elsif($mode=~/sequential/) {
		my $scriptname="01.run_assembly.pl";
 		print outfile3 "1\t$scriptname\n";
 		$currtime=timediff();
 		print outfile4 "[",$currtime->pretty,"]: STEP1 -> $scriptname ($assembler)\n";
 		print "[",$currtime->pretty,"]: STEP1 ->  RUNNING ASSEMBLY: $scriptname ($assembler)\n";
 		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)        { die "Stopping in STEP1 -> $scriptname ($assembler)\n"; }
		my $wc=qx(wc -l $contigsfna);
		my($wsize,$rest)=split(/\s+/,$wc);
		if($wsize<2)         { die "Stopping in STEP1 -> $scriptname ($assembler). File $contigsfna is empty!\n"; }
	}		
			
    #-------------------------------- STEP2: Run RNA prediction

	if($rpoint<=2) {
		my $scriptname="02.run_barrnap.pl";
		print outfile3 "2\t$scriptname\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP2 -> $scriptname\n";
		print "[",$currtime->pretty,"]: STEP2 -> RNA PREDICTION: $scriptname\n";
		my $ecode = system("perl $scriptdir/$scriptname $project");
		my $masked="$interdir/02.$project.maskedrna.fasta";
		if($ecode!=0)        { die "Stopping in STEP2 -> $scriptname\n"; }
		my $wc=qx(wc -l $masked);
		my($wsize,$rest)=split(/\s+/,$wc);
 		if($wsize<2)         { die "Stopping in STEP2 -> $scriptname. File $masked is empty!\n"; }
	}
			
    #-------------------------------- STEP3: Run gene prediction

	if($rpoint<=3) {
		my $scriptname="03.run_prodigal.pl";
 		print outfile3 "3\t$scriptname\n";
 		$currtime=timediff();
 		print outfile4 "[",$currtime->pretty,"]: STEP3 -> $scriptname\n";
 		print "[",$currtime->pretty,"]: STEP3 -> ORF PREDICTION: $scriptname\n";
 		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)        { die "Stopping in STEP3 -> $scriptname\n"; }
		my $wc=qx(wc -l $aafile);
		my($wsize,$rest)=split(/\s+/,$wc);
		if($wsize<2)         { die "Stopping in STEP3 -> $scriptname. File $aafile is empty!\n"; }
	}
			
    #-------------------------------- STEP4: Run Diamond for taxa and functions

	if($rpoint<=4) {
		my $scriptname="04.rundiamond.pl";
		print outfile3 "4\t$scriptname\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP4 -> $scriptname\n";
		print "[",$currtime->pretty,"]: STEP4 -> HOMOLOGY SEARCHES: $scriptname\n";
		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)        { die "Stopping in STEP4 -> $scriptname\n"; }
		my $wc=qx(wc -l $taxdiamond);
		my($wsize,$rest)=split(/\s+/,$wc);
		if($wsize<1)         { die "Stopping in STEP4 -> $scriptname. File $taxdiamond is empty!\n"; }
	}
			
    #-------------------------------- STEP5: Run hmmer for PFAM annotation

	if($rpoint<=5) {
		if(!$nopfam) {
			my $scriptname="05.run_hmmer.pl";
			print outfile3 "5\t$scriptname\n";
			$currtime=timediff();
			print outfile4 "[",$currtime->pretty,"]: STEP5 -> $scriptname\n";
			print "[",$currtime->pretty,"]: STEP5 -> HMMER/PFAM: $scriptname\n";
			my $ecode = system("perl $scriptdir/$scriptname $project");
			if($ecode!=0){ die "Stopping in STEP5 -> $scriptname\n"; }
			my $wc=qx(wc -l $pfamhmmer);
			my($wsize,$rest)=split(/\s+/,$wc);
			if($wsize<4) { die "Stopping in STEP5 -> $scriptname. File $pfamhmmer is empty!\n"; }
		}
	}
			
    #-------------------------------- STEP6: LCA algorithm for taxa annotation

	if($rpoint<=6) {
		my $scriptname="06.lca.pl";
		print outfile3 "6\t$scriptname\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP6 -> $scriptname\n";
		print "[",$currtime->pretty,"]: STEP6 -> TAXONOMIC ASSIGNMENT: $scriptname\n";
		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)        { die "Stopping in STEP6 -> $scriptname\n"; }
		my $wc=qx(wc -l $fun3tax);
		my($wsize,$rest)=split(/\s+/,$wc);
		if($wsize<2)         { die "Stopping in STEP6 -> $scriptname. File $fun3tax is empty!\n"; }
	}
			
    #-------------------------------- STEP7: fun3 for COGs, KEGG and PFAM annotation

	if($rpoint<=7) {
		my $scriptname="07.fun3assign.pl";
		if((!$nocog) || (!$nokegg) || (!$nopfam) || ($opt_db)) {
			print outfile3 "7\t$scriptname\n";
			$currtime=timediff();
			print outfile4 "[",$currtime->pretty,"]: STEP7 -> $scriptname\n";
			print "[",$currtime->pretty,"]: STEP7 -> FUNCTIONAL ASSIGNMENT: $scriptname\n";
			my $ecode = system("perl $scriptdir/$scriptname $project");
			if($ecode!=0)   { die "Stopping in STEP7 -> $scriptname\n"; }
			my($wsizeCOG,$wsizeKEGG,$wsizePFAM,$wsizeOPTDB,$rest);
			if(!$nocog) {
				my $wc=qx(wc -l $fun3cog);
				($wsizeCOG,$rest)=split(/\s+/,$wc);
				}
			if(!$nokegg) {
				my $wc=qx(wc -l $fun3kegg);
				($wsizeKEGG,$rest)=split(/\s+/,$wc);
				}
			if(!$nopfam) {
				my $wc=qx(wc -l $fun3pfam);
				($wsizePFAM,$rest)=split(/\s+/,$wc);
				}
			if($opt_db) {
				my $wc=qx(wc -l $resultpath/07.$project.fun3.opt_db);
				($wsizeOPTDB,$rest)=split(/\s+/,$wc);
				}
			if(($wsizeCOG<2) && ($wsizeKEGG<2) && ($wsizePFAM<2) && ($wsizeOPTDB<2)) {
				die "Stopping in STEP7 -> $scriptname. Files $fun3cog, $fun3kegg and $fun3pfam are empty!\n"; }
		}
	}
			
    #-------------------------------- STEP8: Blastx on the unannotated parts of the contigs
	
	if($rpoint<=8) {
		if($doublepass) {
			my $scriptname="08.blastx.pl";
			print " DOUBLEPASS: Now starting blastx analysis\n";
			print outfile3 "8\t$scriptname\n";
			$currtime=timediff();
			print outfile4 "[",$currtime->pretty,"]: STEP8 -> $scriptname\n";
			print "[",$currtime->pretty,"]: STEP8 -> Doublepass, Blastx analysis: $scriptname\n";
			my $ecode = system("perl $scriptdir/$scriptname $project");
			if($ecode!=0)  { die "Stopping in STEP8 -> $scriptname\n"; }
			my $wc=qx(wc -l $gff_file);
			my($wsize,$rest)=split(/\s+/,$wc);
			if($wsize<2)         { die "Stopping in STEP8 -> $scriptname. File $gff_file is empty!\n"; }
			}
	}
		

    #-------------------------------- STEP9: Taxonomic annotation for the contigs (consensus of gene annotations)


	if($rpoint<=9) {
		my $scriptname="09.summarycontigs3.pl";
		print outfile3 "9\t$scriptname\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP9 -> $scriptname\n";
		print "[",$currtime->pretty,"]: STEP9 -> CONTIG TAX ASSIGNMENT: $scriptname\n";
		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)        { die "Stopping in STEP9 -> $scriptname\n"; }
		my $wc=qx(wc -l $alllog);
		my($wsize,$rest)=split(/\s+/,$wc);
		if($wsize<2)         { die "Stopping in STEP9 -> $scriptname. File $alllog is empty!\n"; }
	}
			
    #-------------------------------- STEP10: Mapping of reads onto contigs for abundance calculations
	
	if($rpoint<=10) {
		my $scriptname="10.mapsamples.pl";
		print outfile3 "10\t$scriptname\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP10 -> $scriptname\n";
		print "[",$currtime->pretty,"]: STEP10 -> MAPPING READS: $scriptname\n";
		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)        { die "Stopping in STEP10 -> $scriptname\n"; }
		my $wc=qx(wc -l $mapcountfile);
		my($wsize,$rest)=split(/\s+/,$wc);
		if($wsize<3)         { die "Stopping in STEP10 -> $scriptname. File $mapcountfile is empty!\n"; }
	}
			
    #-------------------------------- STEP11: Count of taxa abundances
	
	if($rpoint<=11) {
		my $scriptname="11.mcount.pl";
		print outfile3 "11\t$scriptname\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP11 -> $scriptname\n";
		print "[",$currtime->pretty,"]: STEP11 -> COUNTING TAX ABUNDANCES: $scriptname\n";
		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)        { die "Stopping in STEP11 -> $scriptname\n"; }
		my $wc=qx(wc -l $mcountfile);
		my($wsize,$rest)=split(/\s+/,$wc);
		if($wsize<2)         { die "Stopping in STEP11 -> $scriptname. File $mcountfile is empty!\n"; }
	}
			
    #-------------------------------- STEP12: Count of function abundances
	
	if(($rpoint<=12)) {
		my $scriptname="12.funcover.pl";
		if((!$nocog) || (!$nokegg) || (!$nopfam)) {
		print outfile3 "12\t$scriptname\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP12 -> $scriptname\n";
		print "[",$currtime->pretty,"]: STEP12 -> COUNTING FUNCTION ABUNDANCES: $scriptname\n";
		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)     { die "Stopping in STEP12 -> $scriptname\n"; }
		my $cogfuncover="$resultpath/12.$project.cog.funcover";
		my $keggfuncover="$resultpath/12.$project.kegg.funcover";
		my $wc=qx(wc -l $cogfuncover);
		my($wsizeCOG,$rest)=split(/\s+/,$wc);
		my $wc=qx(wc -l $keggfuncover);
		my($wsizeKEGG,$rest)=split(/\s+/,$wc);
		if(($wsizeCOG<3) && ($wsizeKEGG<3)) {
			die "Stopping in STEP12 -> $scriptname. Files $cogfuncover and/or $keggfuncover are empty!\n"; }
		}
	}
			
    #-------------------------------- STEP13: Generation of the gene table
		
	if($rpoint<=13) {
		my $scriptname="13.mergeannot2.pl";
		print outfile3 "13\t$scriptname\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP13 -> $scriptname\n";
		print "[",$currtime->pretty,"]: STEP13 -> CREATING GENE TABLE: $scriptname\n";
		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)        { die "Stopping in STEP13 -> $scriptname\n"; }
		my $wc=qx(wc -l $mergedfile);
		my($wsize,$rest)=split(/\s+/,$wc);
		if($wsize<3)         { die "Stopping in STEP13 -> $scriptname. File $mergedfile is empty!\n"; }
	}
			
    #-------------------------------- STEP14: Running Maxbin (only for merged or coassembly modes)		
	
	if(($mode!~/sequential/i) && ($numsamples>1) && (!$nobins)) {	       
		if(($rpoint<=14) && (!$nomaxbin)) {
			my $scriptname="14.bin_maxbin.pl";
			print outfile3 "14\t$scriptname\n";
			$currtime=timediff();
			print outfile4 "[",$currtime->pretty,"]: STEP14 -> $scriptname\n";
			print "[",$currtime->pretty,"]: STEP14 -> MAXBIN BINNING: $scriptname\n";
			my $ecode = system("perl $scriptdir/$scriptname $project >> $tempdir/$project.log");
			if($ecode!=0){ die "Stopping in STEP14 -> $scriptname\n"; }
			my $dirbin=$bindirs{maxbin};
			opendir(indir1,$dirbin);
			my @binfiles=grep(/maxbin.*fasta/,readdir indir1);
			closedir indir1;
			my $firstfile="$dirbin/$binfiles[0]";
			my $wc=qx(wc -l $firstfile);
			my($wsize,$rest)=split(/\s+/,$wc);
			if($wsize<2) { die "Stopping in STEP14 -> $scriptname. File $firstfile is empty!\n"; }
		}
			
    #-------------------------------- STEP15: Running Metabat (only for merged or coassembly modes)		
	
		if(($rpoint<=15) && (!$nometabat)) {
			my $scriptname="15.bin_metabat2.pl";
			print outfile3 "15\t$scriptname\n";
			$currtime=timediff();
			print outfile4 "[",$currtime->pretty,"]: STEP15 -> $scriptname\n";
			print "[",$currtime->pretty,"]: STEP15 -> METABAT BINNING: $scriptname\n";
			my $ecode = system("perl $scriptdir/$scriptname $project >> $tempdir/$project.log");
			if($ecode!=0){ die "Stopping in STEP15 -> $scriptname\n"; }
			my $dirbin=$bindirs{metabat2};
			opendir(indir2,$dirbin);
			my @binfiles=grep(/fa/,readdir indir2);
			closedir indir2;
			my $firstfile="$dirbin/$binfiles[0]";
			my $wc=qx(wc -l $firstfile);
			my($wsize,$rest)=split(/\s+/,$wc);
			if($wsize<2) { die "Stopping in STEP15 -> $scriptname. File $firstfile is empty!\n"; }
		}
 
    #-------------------------------- STEP16: DAS Tool merging of binning results (only for merged or coassembly modes)		
	
		if(($rpoint<=16)) {
			my $scriptname="16.dastool.pl";
			print outfile3 "16\t$scriptname\n";
			$currtime=timediff();
			print outfile4 "[",$currtime->pretty,"]: STEP16 -> $scriptname\n";
			print "[",$currtime->pretty,"]: STEP16 -> DAS_TOOL MERGING: $scriptname\n";
			my $ecode = system("perl $scriptdir/$scriptname $project >> $tempdir/$project.log");
			if($ecode!=0){ die "Stopping in STEP16-> $scriptname\n"; }
			my $dirbin=$dasdir{DASTool};
			opendir(indir2,$dirbin);
			my @binfiles=grep(/fa/,readdir indir2);
			closedir indir2;
			my $firstfile="$dirbin/$binfiles[0]";
			my $wc=qx(wc -l $firstfile);
			my($wsize,$rest)=split(/\s+/,$wc);
			if($wsize<2) {
				print("WARNING: File $firstfile is empty!. DAStool did not generate results\n");
				$DAS_Tool_empty = 1;
				}
		}
			
    #-------------------------------- STEP17: Taxonomic annotation for the bins (consensus of contig annotations)		
	
		if($rpoint<=17) {
			if(!$DAS_Tool_empty){
				my $scriptname="17.addtax2.pl";
				print outfile3 "17\t$scriptname\n";
				$currtime=timediff();
				print outfile4 "[",$currtime->pretty,"]: STEP17 -> $scriptname\n";
				print "[",$currtime->pretty,"]: STEP17 -> BIN TAX ASSIGNMENT: $scriptname\n";
				my $ecode = system("perl $scriptdir/$scriptname $project >> $tempdir/$project.log");
				if($ecode!=0){ die "Stopping in STEP17 -> $scriptname\n"; }
				my $wc=qx(wc -l $bintax);
				my($wsize,$rest)=split(/\s+/,$wc);
				if($wsize<1) { die "Stopping in STEP17 -> $scriptname. File $bintax is empty!\n"; }
			}
			else{ print("Skipping BIN TAX ASSIGNMENT: DAS_Tool did not predict bins.\n"); }
		}

			
    #-------------------------------- STEP18: Checking of bins for completeness and contamination (checkM)		
	
		if($rpoint<=18) {
			if(!$DAS_Tool_empty){
				my $scriptname="18.checkM_batch.pl";
				print outfile3 "17\t$scriptname\n";
				$currtime=timediff();
				print outfile4 "[",$currtime->pretty,"]: STEP18 -> $scriptname\n";
				print "[",$currtime->pretty,"]: STEP18 -> CHECKING BINS: $scriptname\n";
				my $ecode = system("perl $scriptdir/$scriptname $project >> $tempdir/$project.log");
				if($ecode!=0) { die "Stopping in STEP18 -> $scriptname\n"; }
				foreach my $binmethod(keys %dasdir) {
					my $checkmfile="$interdir/18.$project.$binmethod.checkM";
					my $wc=qx(wc -l $checkmfile);
					my($wsize,$rest)=split(/\s+/,$wc);
					if($wsize<4) {
						die "Cannot find $checkmfile\nStopping in STEP18 -> $scriptname\n"; }
					}
			}
			else { print("Skipping CHECKM: DAS_Tool did not predict bins.\n") ; }
		}

			
    #-------------------------------- STEP19: Make bin table		
	
		if($rpoint<=19) {
			if(!$DAS_Tool_empty){
				my $scriptname="19.getbins.pl";
				print outfile3 "19\t$scriptname\n";
				$currtime=timediff();
				print outfile4 "[",$currtime->pretty,"]: STEP19 -> $scriptname\n";
				print "[",$currtime->pretty,"]: STEP19 -> CREATING BIN TABLE: $scriptname\n";
				my $ecode = system("perl $scriptdir/$scriptname $project");
				if($ecode!=0){ die "Stopping in STEP19 -> $scriptname\n"; }
				my $wc=qx(wc -l $bintable);
				my($wsize,$rest)=split(/\s+/,$wc);
				if($wsize<3) { die "Stopping in STEP19 -> $scriptname. File $bintable is empty!\n"; }
			}
			else{ print("Skipping BIN TABLE CREATION: DAS_Tool did not predict bins.\n") ; }
		}
	}

    #-------------------------------- STEP20: Make contig table		

	if($rpoint<=20) {
		my $scriptname="20.getcontigs.pl";
		print outfile3 "20\t$scriptname\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP20 -> $scriptname\n";
		print "[",$currtime->pretty,"]: STEP20 -> CREATING CONTIG TABLE: $scriptname\n";
		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)        { die "Stopping in STEP20 -> $scriptname\n"; }
		my $wc=qx(wc -l $contigtable);
		my($wsize,$rest)=split(/\s+/,$wc);
		if($wsize<3)         { die "Stopping in STEP20 -> $scriptname. File $contigtable is empty!\n"; }
	}

    #-------------------------------- STEP21: Pathways in bins          

	if(($mode!~/sequential/i) && ($numsamples>1) && (!$nobins)) {	       
		if($rpoint<=21) {
			if(!$DAS_Tool_empty){
				my $scriptname="21.minpath.pl";
				print outfile3 "21\t$scriptname\n";
				$currtime=timediff();
				print outfile4 "[",$currtime->pretty,"]: STEP21 -> $scriptname\n";
				print "[",$currtime->pretty,"]: STEP21 -> CREATING TABLE OF PATHWAYS IN BINS: $scriptname\n";
				my $ecode = system("perl $scriptdir/$scriptname $project");
				if($ecode!=0){ die "Stopping in STEP21 -> $scriptname\n"; }
				my $minpathfile="$resultpath/21.$project.kegg.pathways";
				my $wc=qx(wc -l $minpathfile);
				my($wsize,$rest)=split(/\s+/,$wc);
				if($wsize<3) { die "Stopping in STEP21 -> $scriptname. File $minpathfile is empty!\n"; }
			}
			else{ print("Skipping MINPATH: DAS_Tool did not predict bins.\n") ; }
		}
	}


    #-------------------------------- STEP21: Make stats		

	if($rpoint<=22) {
		my $scriptname="22.stats.pl";
		print outfile3 "22\t$scriptname\n";
		$currtime=timediff();
		print outfile4 "[",$currtime->pretty,"]: STEP22 -> $scriptname\n";
		print "[",$currtime->pretty,"]: STEP22 -> MAKING FINAL STATISTICS: $scriptname\n";
		my $ecode = system("perl $scriptdir/$scriptname $project");
		if($ecode!=0)        { die "Stopping in STEP22 -> $scriptname\n"; }
		my $statfile="$resultpath/22.$project.stats";
		my $wc=qx(wc -l $statfile);
		my($wsize,$rest)=split(/\s+/,$wc);
		if($wsize<10)        { die "Stopping in STEP22 -> $scriptname. File $statfile is empty!\n"; }
	}

    #-------------------------------- END OF PIPELINE		

	print outfile3 "END\n";
	$currtime=timediff();
	print outfile4 "[",$currtime->pretty,"]: FINISHED -> Have fun!\n";
	print "[",$currtime->pretty,"]: FINISHED -> Have fun!\n";
}




#!/usr/bin/perl

#-- Part of SqueezeMeta distribution. 29/01/2019 Original version, (c) Javier Tamames, CNB-CSIC
#-- Last Common Ancestor (LCA) taxonomic assignment from a Diamond file. For blastx collapsed format 

$|=1;

use DBI;
use Tie::IxHash;
use Cwd;
use lib ".";
$pwd=cwd();

my $pwd=cwd();
my $project=$ARGV[0];
$project=~s/\/$//; 
if(-s "$project/SqueezeMeta_conf.pl" <= 1) { die "Can't find SqueezeMeta_conf.pl in $project. Please check that $project is the correct path to the project"; }
do "$project/SqueezeMeta_conf.pl";

our($datapath,$resultpath,$databasepath,$taxdiamond,$lca_db,$fun3tax,$evalue);

my $infile=$ARGV[1];

my @ranks=('species','genus','family','order','class','phylum','superkingdom');
my %idenrank=('species',85,'genus',60,'family',55,'order',50,'class',46,'phylum',42,'superkingdom',40);
my $scoreratio=0.8;   #-- Ratio first score/currsent score for the hit to be considered
my $diffiden=10;       #-- Maximim identity difference with the first
my $flex=0.2;           #-- Allows this PERCENTAGE (if less than one) or NUMBER (if grater than one) of hits from different taxa than LCA
my $minhits=1;        #-- Minimum number of hits for the taxa (if there is only one valid hit, this value sets to one automatically
my $noidentical=0;  #-- Drops the first 100% identical hit (for mock)
my $miniden=50;
my $verbose=0;
my $bhitforced=0;	#-- Forces that assignment cannot differ from best hit


#-- Prepare the LCA database (containing the acc -> tax correspondence)

my $dbh = DBI->connect("dbi:SQLite:dbname=$lca_db","","",{ RaiseError => 1}) or die $DBI::errstr;

my(%parents);
open(infile1,"$databasepath/LCA_tax/parents.txt") || die;
while(<infile1>) {
	chomp;
	next if !$_;
	my($tax,$par)=split(/\t/,$_);
	$parents{$tax}{wranks}=$par;
	my @m=split(/\;/,$par);
	foreach my $y(@m) {
		my($rt,$gtax)=split(/\:/,$y);
		$parents{$tax}{noranks}.="$gtax;"; 
		}
	chop $parents{$tax}{noranks};
	}
close infile1;

my $outname="08.$project.fun3.blastx.tax";
open(out,">$tempdir/$outname") || die "Cannot open output in $tempdir/$outname\n";
open(outc,">$resultpath/$outname.wranks") || die;
open(outnof,">$tempdir/$outname\_nofilter") || die;
open(outcnof,">$resultpath/$outname\_nofilter.wranks") || die;

my(%accum,%accumnofilter,%provhits,%providen,%giden);
my($validhits,$validhitsnofilter,$tothits,$skipidentical,$refscore,$refiden,$string,$posinit,$posend);
tie %provhits,"Tie::IxHash";
tie %accum,"Tie::IxHash";

if($infile=~/gz/) { open(infile2,"zcat $infile|") || die; }
else { open(infile2,$infile) || die "Cannot open m8 file $infile\n"; }
while(<infile2>) { 
	chomp;
	next if(!$_ || ($_=~/^\#/));	
	$_=~s/\;\_//g;
	my @fields=split(/\t/,$_);
	my $thisorf=$fields[0];
	if($thisorf) { 
		# print "!!! $thisorf $lastorf\n";
		query();
		(%accum,%accumnofilter,%provhits,%providen,%giden)=();
		($validhits,$validhitsnofilter,$tothits,$skipidentical)=0;
		$string="";
		$lastorf=$thisorf;	
		($refscore,$refiden)=0;	
		}
	if($noidentical && (!$skipidentical) && ($fields[2] eq "100.0")) { $skipidentical=1; next; }			   
	if(!$refscore) { $refscore=$fields[11]; }
	if(!$refiden) { $refiden=$fields[2]; }  
	$posinit=$fields[6];			   
	$posend=$fields[7];
 	if($fields[$#fields]>$provhits{$fields[1]}) { $provhits{$fields[1]}=$fields[$#fields]; }
 	if($fields[2]>$providen{$fields[1]}) { $providen{$fields[1]}=$fields[2]; }
	$tothits++;			   
	}
close infile2;
close out;
close outc;
close outnof;
close outcnof;
print "Tax assignment done! Result stored in file $outname.wranks\n";


sub query {
	my($refcc,$genocc,$unicc)=0; 
	# if($lastorf=~/NODE_1_length_433318_cov_12.8415_1/) { $verbose=1; } else { $verbose=0; }
	print "refscore: $refscore refiden: $refiden\n" if $verbose; 
	my (%giden,%bhit)=();
	my($besthit,$ratoscore,$idendiff,$lasttax, $nuquery);
	my $query="select * from taxid where (";
	foreach my $lhits(keys %provhits) {
		print ">*>$lhits $provhits{$lhits}\n" if $verbose;
		my @gh=split(/\;/,$lhits);
		foreach my $fhit(@gh) {
			my @e=split(/\|/,$fhit);
			my $thishit=$e[0];
			my $thisscore=$e[1];
			my $thisiden=$e[2];
			$giden{$thishit}=$thisiden;
			# print "  ----- $thishit $thisscore $refscore\n";
			if($refscore) { $ratioscore=$thisscore/$refscore; }
			next if($ratioscore<=$scoreratio);
                        $nuquery++;
                        last if($nuquery>=100);
			if($refiden) { $idendiff=$refiden-$thisiden; }
			next if($idendiff>$diffiden);    
			if($refcc) { $query.=" or "; }
 			else { $refcc=1; }
			$query.="id=\"$thishit\"";
			if(!$besthit) { $besthit=$thishit; }
			}
		}
				     
	$query.=");";	
	print "*$query*\n" if $verbose;			     
	if($refcc) {
		my $sth = $dbh->prepare($query);  
		$sth->execute();
		while(@list=$sth->fetchrow()) {
			print "$lastorf\t@list\n" if $verbose;
			for(my $pos=2; $pos<=8; $pos++) {
				my $rank=$ranks[$pos-2];
				my $tax=$list[$pos];
				print " $rank $tax $giden{$list[0]} $idenrank{$rank}\n" if $verbose;
				if($list[0] eq $besthit) { $bhit{$rank}=$tax; }
				if($giden{$list[0]}>=$idenrank{$rank}) { $accum{$rank}{$tax}++; }		#-- and add a count for that taxon in that rank
				$accumnofilter{$rank}{$tax}++; 		#-- Not considering identity filters for ranks
				}
			#if(($list[8]) && ($giden{$list[0]}>=$idenrank{'superkingdom'})) { $validhits++;  }			#-- Count the number of valid hits
			if(($list[2])) { $validhitsnofilter++; $validhits++; }			#-- Count the number of valid hits
			}
		}
	if($validhits==1) { $minreqhits=1; } else { $minreqhits=$minhits; }
	if($flex<1) { $required=$validhits-($flex*$validhits); } else { $required=$validhits-$flex; }
	print "$lastorf Hits: $tothits; Valid: $validhits; Min: $minreqhits; Required: $required\n" if $verbose;
	$lasttax="";			
	foreach my $k(@ranks) {
		print "   $k\n" if $verbose;
		foreach my $t(keys %{ $accum{$k} }) {
			print "      $t $accum{$k}{$t}\n" if $verbose;
			if(($accum{$k}{$t}>=$required) && ($accum{$k}{$t}>=$minreqhits)) { 
				next if(($t ne $bhit{$k}) && ($bhitforced));
				print "$k -> $t\n" if $verbose;
				$lasttax=$t; 
				#  if($t) { $string="$t;$string"; }
				}
			}
		last if($lasttax);		
		}
	
	if($validhitsnofilter==1) { $minreqhits=1; } else { $minreqhits=$minhits; }
	if($flex<1) { $required=$validhitsnofilter-($flex*$validhitsnofilter); } else { $required=$validhitsnofilter-$flex; }
	my $lasttaxnofilter="";			
	foreach my $k(@ranks) {
		foreach my $t(keys %{ $accumnofilter{$k} }) {
			if(($accumnofilter{$k}{$t}>=$required) && ($accumnofilter{$k}{$t}>=$minreqhits)) { $lasttaxnofilter=$t; }
			}

		last if($lasttaxnofilter);		
		}

 
	print out "$lastorf\t$parents{$lasttax}{noranks}\n";
	print outc "$lastorf\t$parents{$lasttax}{wranks}\n";		
	print outnof "$lastorf\t$parents{$lasttaxnofilter}{noranks}\n";
	print outcnof "$lastorf\t$parents{$lasttaxnofilter}{wranks}\n";		
	print "$lastorf\t$parents{$lasttax}{noranks}\n" if $verbose;	
       }

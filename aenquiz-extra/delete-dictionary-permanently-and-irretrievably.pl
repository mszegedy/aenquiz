#!/bin/perl

use strict;
use warnings;

open my $aeneid, "<", "aeneid-1.txt";
my %words = ();
while(!eof $aeneid) {
  my $line = readline $aeneid;
  my @naivewords = split(" ", $line);
  foreach my $word (@naivewords) {
    $word =~ s/[\.,;!\?"'`\(\)\[\]]//g;
    $words{$word} = 1;
  }
}
my $counter = 0;
my $len = scalar keys %words;
my %definitions = ();
my %seenverbs = ();
foreach my $word (sort keys %words) {
  print "\rDone with ".$counter."/".$len." words";
  my %wordforms = ($word => 1, lc $word => 1);
  if((substr $word, -2) eq "ve" || (substr $word, -2) eq "ne") {
    $wordforms{substr $word, 0, -2} = 1;
  }
  if(substr $word, -3 eq "que") {
    $wordforms{substr $word, 0, -3} = 1;
  }
  foreach my $wordform (sort keys %wordforms) {
    my @lines = split("\n", `dxy latin '$wordform'`);
    foreach my $line (@lines) {
      $line =~ s/^Latin\t|[\[\]]|\|lang=la//g;
      $line =~ s/&nbsp;/ /g;
      $definitions{$line} = 1;
      if($line =~ m/(conjugation|inflection|alternative form) of\|(\S+?)\|/) {
        $line =~ m/(conjugation|inflection|alternative form) of\|(\S+?)\|/;
        my $verb = $2;
        $verb =~ s/ā/a/g;
        $verb =~ s/ē/e/g;
        $verb =~ s/ī/i/g;
        $verb =~ s/ō/o/g;
        $verb =~ s/ū/u/g;
        if(!exists $seenverbs{$verb}) {
          $seenverbs{$verb} = 1;
          my @verblines = split("\n", `dxy latin '$verb'`);
          foreach my $verbline (@verblines) {
            $verbline =~ s/^Latin\t|[\[\]]|\|lang=la//g;
            $verbline =~ s/&nbsp;/ /g;
            $definitions{$verbline} = 1;
          }
        }
      }
    }
  }
  $counter += 1;
}
open my $dictionary, ">", "latin-small.tsv";
foreach my $line (sort keys %definitions) {
  print $dictionary $line."\n";
}

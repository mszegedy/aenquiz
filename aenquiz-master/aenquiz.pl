#!/bin/perl

# aenquiz v2.1.1. For memorizing words from the Aeneid.
# Copyright (C) 2014  Maria Szegedy
#
# This file is part of aenquiz.
#
# aenquiz is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# aenquiz is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with aenquiz.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
BEGIN {
  if ($^O eq "MSWin32") {
    require Win32::Console::ANSI;
    Win32::Console::ANSI->import();
  }
}
use Term::ANSIColor;

sub getknown {
  my $word = shift @_;
  if(!$word) {
    return 1;
  }
  my $result = open my $known, "<", "resources/known.csv";
  if(!$result) {
    return 1;
  }
  while(!eof $known) {
    my $line = readline $known;
    chomp $line;
    $line =~ m/^\s*([A-Za-z ]+?)\s*,\s*(\d+?)\s*$/;
    if($1 eq $word) {
      return $2;
    }
  }
  return 1;
}

sub getdefinition {
  my $word = shift @_;
  my @definitions = ();
  my $result = open my $dictionary, "<", "resources/latin-small.tsv";
  if(!$result) {
    print "Cannot open dictionary: ".$!."\n";
  }
  my $wasmatch = 0;
  while(!eof $dictionary) {
    my $line = readline $dictionary;
    chomp $line;
    if($line =~ m/^$word\t/) {
      $wasmatch = 1;
      $line =~ m/^(\S+)\t(\S+|Proper noun)\t# ?(.*)$/;
      if($2 && $3) {
        push @definitions, [$2,$3];
      }
    }
    elsif($wasmatch) {
      last;
    }
  }
  return @definitions;
}

sub getparts {
  my $word = shift @_;
  my $partofspeech = shift @_;
  my $result = open my $partsfile, "<", "resources/parts.tsv";
  if(!$result) {
    print "Cannot open parts.tsv: ".$!."\n";
  }
  my @parts = ();
  while(!eof $partsfile) {
    my $line = readline $partsfile;
    chomp $line;
    my @items = split("\t", $line);
    if($items[0] eq $word && $items[1] eq $partofspeech) {
      @parts = @items[2..(scalar @items)-1];
      last;
    }
  }
  return \@parts;
}

sub getresponse {
  my $flag = "";
  if(scalar @_) {
    $flag = shift @_;
  }
  my $response = <STDIN>;
  chomp $response;
  if($response eq "QUIT" && $flag ne "noquit") {
    exit 0;
  }
  else {
    return $response;
  }
}

sub quiz {
  my @words = @_;
  # Eliminate duplicates from @words
  print "Verifying words...\n";
  my %seen = ();
  my @wordscopy = ();
  foreach my $word (@words) {
    if(!exists $seen{$word}) {
      push @wordscopy, $word;
      $seen{$word} = 1;
    }
  }
  undef %seen;
  undef @words;
  my $wordcount = 0;
  my $wordslen = scalar @wordscopy;
  my %queries = ();
  foreach my $word (@wordscopy) {
    print "\rCopying definitions to memory... done with ".$wordcount."/".$wordslen." words.";
    my @definition = getdefinition($word);
    if(scalar @definition != 0) {
      $queries{$word} = \@definition;
    }
    if((substr $word, -3) eq "que") {
      $word = substr $word, 0, -3;
      my @definition = getdefinition($word);
      if(scalar @definition != 0) {
        $queries{$word} = \@definition;
      }
    }
    if((substr $word, -2) eq "ne" || (substr $word, -2) eq "ve") {
      $word = substr $word, 0, -2;
      my @definition = getdefinition($word);
      if(scalar @definition != 0) {
        $queries{$word} = \@definition;
      }
    }
    $wordcount += 1;
  }
  print "\rCopying definitions to memory... done with ".$wordcount."/".$wordslen." words.\n";
  # Build list of definitions
  my %toquiz = ();
  # Each word in %toquiz maps to an array that contains the score the user has
  # achieved for that word, and an array of definitions for that word.
  print "Gathering additional data about words...";
  $wordcount = 0;
  $wordslen = scalar keys %queries;
  foreach my $word (keys %queries) {
    print "\rGathering additional data about words... done with ".$wordcount."/".$wordslen." words.";
    my @definitionscopy = @{ $queries{$word} };
    my @definitions = ();
    my @parts = ();
    my %seenroots = ();
    my %seencombos = ();
    foreach my $definition (@definitionscopy) {
      push @definitions, $definition;
      if($definition->[1] =~ m/(conjugation|inflection|alternative form) of\|([A-Za-zāēīōū]+)/) {
        $definition->[1] =~ m/(conjugation|inflection|alternative form) of\|([A-Za-zāēīōū]+)/;
        my $root = removemacrons($2);
        if(!exists $seenroots{$root}) {
          $seenroots{$root} = 1;
          my @rootdefinitions = getdefinition($root);
          foreach my $rootdefinition (@rootdefinitions) {
            $rootdefinition->[1] = "\t".$rootdefinition->[1];
            if((scalar grep {$rootdefinition->[0] eq $_} qw(Adjective Noun Verb)) &&
               !exists $seencombos{$root."\t".$rootdefinition->[0]}) {
              $seencombos{$root."\t".$rootdefinition->[0]} = 1;
              my $partsref = getparts($root, $rootdefinition->[0]);
              if(scalar @{ $partsref }) {
                push @parts, $partsref;
              }
            }
          }
          push @definitions, @rootdefinitions;
        }
      }
    }
    foreach my $definition (grep {my $ch = $_;
                                  (scalar grep {$ch->[0] eq $_} qw(Adjective Noun Verb)) &&
                                  $ch->[1] !~ m/^\t/} @definitions) {
      if(!exists $seencombos{$word."\t".$definition->[0]}) {
        $seencombos{$word."\t".$definition->[0]} = 1;
        my $partsref = getparts($word, $definition->[0]);
        if(scalar @{ $partsref }) {
          push @parts, $partsref;
        }
      }
    }
    $toquiz{$word} = [0, 0, \@definitions, \@parts];
    $wordcount += 1;
  }
  print "\rGathering additional data about words... done with ".$wordslen."/".$wordslen." words.";
  $wordslen = scalar keys %toquiz;
  undef @wordscopy;
  undef $wordcount;
  # Begin quizzing
  my %currentwords = ();
  system $^O eq 'MSWin32' ? 'cls' : 'clear';
  while((scalar keys %currentwords) < 10 && scalar keys %toquiz > 0) {
    my $k = (keys %toquiz)[rand keys(%toquiz)];
    my $v = delete $toquiz{$k};
    if(rand() < 1/getknown($k)) {
      $currentwords{$k} = $v;
      showword($k, %currentwords);
    }
  }
  system $^O eq 'MSWin32' ? 'cls' : 'clear';
  while((scalar keys %currentwords) + (scalar keys %toquiz) > 0) {
    my $word = (keys %currentwords)[rand keys %currentwords];
    my $kind = 0;
    if(scalar @{ $currentwords{$word}->[3] }) {
      $kind = (0, 1)[((rand() < 0.5) && ($currentwords{$word}->[1] < 4)) ||
                     $currentwords{$word}->[0] >= 4];
    }
    print "What ".($kind == 0 ? "is the meaning" : "are the principle parts")." of \"".$word."\"?\n";
    my $response = getresponse("noquit");
    my $matchn = 0;
    if($kind == 0) {
      foreach my $phrase (split(",", $response)) {
        $phrase =~ m/^\s*(.+)\s*$/;
        if(grep {$_ =~ m/\Q$1\E/} map {$_->[1]} @{ $currentwords{$word}->[2] }) {
          $matchn += 1;
        }
      }
    }
    elsif($kind == 1) {
      my @answeredparts = split(",", $response);
      foreach my $answeredpart (@answeredparts) {
        $answeredpart =~ s/^\s+|\s+$//g;
      }
      foreach my $partsref (@{ $currentwords{$word}->[3] }) {
        my @parts = @{ $partsref };
        my @partscopy = @parts;
        foreach my $part (@partscopy) {
          $part = removemacrons($part);
        }
        $matchn += join(",", @answeredparts) eq join(",", @partscopy);
      }
    }
    if($response eq "QUIT") {
      print "Do you want to save your session? (Y/n)\n";
      $response = getresponse();
      if(((substr $response, 0, 1) eq "y") || ((substr $response, 0, 1) eq "Y") || $response eq "") {
        open my $save, ">", "resources/save";
        print $save join(", ", keys %toquiz, keys %currentwords);
      }
      print "You memorized ".($wordslen-((scalar keys %currentwords)+(scalar keys %toquiz)))."/".$wordslen." words.\n";
      return $wordslen-((scalar keys %currentwords)+(scalar keys %toquiz));
    }
    elsif((($kind == 0) && ($matchn == scalar split(",", $response)) && (length $response >= 1)) ||
          (($kind == 1) && ($matchn > 0))) {
      $currentwords{$word}->[$kind] += 1;
      if($currentwords{$word}->[0] >= 4 &&
         ($currentwords{$word}->[1] >= 4 || scalar @{ $currentwords{$word}->[3] } == 0)) {
        updateknown($word);
        delete $currentwords{$word};
        if(scalar keys %toquiz) {
          my $k;
          my $v;
          while((!$k || rand() > 1/getknown($k)) && scalar keys %toquiz) {
            $k = (keys %toquiz)[rand keys %toquiz];
            $v = delete $toquiz{$k};
          }
          $currentwords{$k} = $v;
          system $^O eq 'MSWin32' ? 'cls' : 'clear';
          showword($k, %currentwords);
          system $^O eq 'MSWin32' ? 'cls' : 'clear';
          open my $backup, ">", "resources/backup";
          print $backup join(", ", keys %toquiz, keys %currentwords);
        }
      }
    }
    else {
      if($currentwords{$word}->[$kind] > -2) {
        $currentwords{$word}->[$kind] -= 1;
      }
      system $^O eq 'MSWin32' ? 'cls' : 'clear';
      showword($word, %currentwords);
      system $^O eq 'MSWin32' ? 'cls' : 'clear';
    }
  }
  print "Congratulations. You memorized all ".$wordslen." words.\n";
  return $wordslen;
}

sub removemacrons {
  my $s = shift @_;
  my $scopy = $s;
  $scopy =~ s/ā/a/g;
  $scopy =~ s/ē/e/g;
  $scopy =~ s/ī/i/g;
  $scopy =~ s/ō/o/g;
  $scopy =~ s/ū/u/g;
  return $scopy;
}

sub showword {
  my $word = shift @_;
  my %currentwords = @_;
  my %colors;
  if($^O eq "darwin") {
    %colors = ("Noun"         => 'bold red',
               "Adjective"    => 'bold green',
               "Verb"         => 'bold blue',
               "Preposition"  => 'bold magenta',
               "Adverb"       => 'bold yellow',
               "Conjunction"  => 'bold cyan',
               "Proper noun"  => 'bold red',
               "Numeral"      => 'bold green',
               "Ordinal"      => 'bold green',
               "Interjection" => 'bold magenta',
               "Pronoun"      => 'bold yellow',
               "Determiner"   => 'bold yellow',
               "Participle"   => 'bold cyan');
  }
  else {
    %colors = ("Noun"         => 'bold red',
               "Adjective"    => 'bold green',
               "Verb"         => 'bold blue',
               "Preposition"  => 'bold magenta',
               "Adverb"       => 'bold yellow',
               "Conjunction"  => 'bold cyan',
               "Proper noun"  => 'bold bright_red',
               "Numeral"      => 'bold bright_green',
               "Ordinal"      => 'bold bright_green',
               "Interjection" => 'bold bright_magenta',
               "Pronoun"      => 'bold bright_yellow',
               "Determiner"   => 'bold bright_yellow',
               "Participle"   => 'bold bright_cyan');
  }
  print color 'bold';
  print $word.":\n";
  foreach my $partsref (@{ $currentwords{$word}->[3] }) {
    if(scalar @{ $partsref }) {
      print $^O eq "MSWin32" ? removemacrons(join(", ", @{ $partsref })."\n") : join(", ", @{ $partsref })."\n";
    }
  }
  foreach my $definition (@{ $currentwords{$word}->[2] }) {
    $definition->[1] =~ m/^(\s*)/;
    if($1 ne "\t") {
      print color $colors{$definition->[0]};
      print $^O eq "MSWin32" ? removemacrons($definition->[0]." ") : $definition->[0]." ";
    }
    if($definition->[1] =~ m/\{\{context\|[^}]*\}\}/) {
      $definition->[1] =~ m/(\{\{context\|[^}]*\}\})/;
      my $context = $1;
      $context =~ s/\{\{context\||\|*\}\}//g;
      $context =~ s/\|/, /g;
      $context = "(".$context.") ";
      $definition->[1] =~ s/\{\{context\|[^}]*\}\}//g;
      $definition->[1] =~ s/^(\s*)//;
      if($1) {
        print substr $1, 0, -1;
      }
      print color 'reset cyan';
      print $context;
    }
    print color 'reset';
    print $^O eq "MSWin32" ? removemacrons($definition->[1]."\n") : $definition->[1]."\n";
  }
  getresponse();
}

sub updateknown {
  my $word = shift @_;
  my $result = open my $inknown, "<", "resources/known.csv";
  my %timesknown = ();
  if($result) {
    while(!eof $inknown) {
      my $line = readline $inknown;
      chomp $line;
      $line =~ m/^\s*([A-Za-z ]+?)\s*,\s*(\d+?)\s*$/;
      $timesknown{$1} = $2;
    }
  }
  if(exists $timesknown{$word}) {
    $timesknown{$word} += 1;
  }
  else {
    $timesknown{$word} = 1;
  }
  close $inknown;
  open my $outknown, ">", "resources/known.csv";
  foreach my $k (sort keys %timesknown) {
    print $outknown $k.",".$timesknown{$k}."\n";
  }
  close $outknown;
}

system $^O eq 'MSWin32' ? 'cls' : 'clear';
my $beginning = <<END;
aenquiz v2.1.1, Copyright (C) 2014  Michael Szegedy
This program comes with ABSOLUTELY NO WARRANTY; for details type
`warranty'.
This is free software, and you are welcome to redistribute it
under certain conditions; type `conditions' for details.

Type `QUIT' at any time to quit. Type `help' for help.

END
print $beginning;
my @loaded = ();
my @allloaded = ();
my @loadsrun = ();
my $wordsmemorized = 0;
PROMPT:
while(1) {
  print "> ";
  my $response = getresponse();
  $response =~ s/^\s*|\s*$//g;
  my @responsewords = split(m/\s+/, $response);
  if(!scalar @responsewords) {
  }
  elsif($responsewords[0] eq "help") {
    my $doc;
    if(scalar @responsewords == 1) {
      $doc = <<END;
You can do various things by typing commands into the prompt and then pressing
Enter. Here are all of the commands you can use. Type `help' followed by the
name of the command to find out more about the command. If you don't know what
to do, you can try `load lines <range>' with a range followed by `quiz'.

    certify: Save a .txt summary of the session that should certify to
             Ms. McMillan that you have used the program.
 conditions: Show the conditions under which you can distribute this program.
fakecertify: Save a .txt summary of a fake session that uses the words you have
             loaded. This is for if you do not actually want to use the program,
             but Ms. McMillan is making you.
       help: Show all the commands that can be run, or get help about a command.
       load: Load words to quiz yourself on. This can be by lines, from a save,
             or from a list. Type `help load' to find out how to use this
             command.
       QUIT: Quits the program. Can be used at any time. If you are currently
             quizzing, the program will ask you whether or not you want to save
             your session first, and then it will quit to the aenquiz prompt.
       quiz: Start quizzing, using the words you've loaded. Run `load' first.
   warranty: Show the warranty of this program.
END
    }
    elsif(lc $responsewords[1] eq "certify") {
      $doc = <<END;
Makes a file, certification.txt, that summarizes your session for Ms. McMillan.
You can print this out and give it to her to show her that you've done the
assignment.
END
    }
    elsif(lc $responsewords[1] eq "conditions") {
      $doc = <<END;
Shows the conditions under which you can distribute this program. Please follow
these.
END
    }
    elsif(lc $responsewords[1] eq "fakecertify") {
      $doc = <<END;
Makes a file, certification.txt, that summarizes the results of a fake session
that uses the words you've loaded. It's indistinguishable from a real
certification. You can print it out and show it to Ms. McMillan that you've
"done" the assignment.
END
    }
    elsif(lc $responsewords[1] eq "help") {
      $doc = <<END;
Show a list of commands that you can run. If you type the name of a command
after it, it will give you help about that command.
END
    }
    elsif(lc $responsewords[1] eq "load") {
      $doc = <<END;
Load words to quiz yourself on. You can run this command multiple times to load
words from multiple places, or `load clear' to clear the words you loaded. The
words you've loaded get reset every time you finish getting quizzed. You can use
this command with the following arguments:

    backup: When you are getting quizzed, the program makes a backup of your
            session whenever you learn a new word. You can load this backup if
            your session quits by accident.
            Ex.: `load backup'
     clear: Clear The words you've loaded. If you want to get quizzed again, you
            will have to load more words.
            Ex.: `load clear'
<filename>: Load a CSV file in resources/lists/ with words in it. If you are
            using this program for the first time, then the only file in there
            is mcmillan.csv, which contains all of the important words
            Ms. Macmillan put online. You may also enter a range of lines after
            the filename to get quizzed on words only from those lines of the
            Aeneid. You may leave off the file extension.
            Ex.: `load mcmillan', `load mcmillan 187-209'
     lines: Load all of the words from a part of the Aeneid. You may enter a
            range of lines to load, or you may leave it blank to load all of the
            words in the entire Aeneid.
            Ex.: `load lines', `load lines 1-10'
      save: Load the words you saved most recently. Your save never gets
            deleted; you just save over your previous save when you save again.
            Ex.: `load save'
END
    }
    elsif(lc $responsewords[1] eq "QUIT") {
      $doc = <<END;
Quits the program. Can be used at any time. If you are currently quizzing, the
program will ask you whether or not you want to save your session first, and will
then exit to the aenquiz prompt.
END
    }
    elsif(lc $responsewords[1] eq "quiz") {
      $doc = <<END;
Starts quizzing you on the words you loaded with `load'. Check the README for
information about how quizzing works. Your loaded words get cleared after you
finish getting quizzed, whether you learn all of the words or just quit.
END
    }
    elsif(lc $responsewords[1] eq "warranty") {
      $doc = "Shows the warranty of this program.\n";
    }
    print $doc;
  }
  elsif($responsewords[0] eq "certify") {
    my $result = open my $certification, ">", "certification.txt";
    if(!$result) {
      print "Could not open certification.txt for writing: ".$!;
    }
    print $certification "Load commands run:\n".join("\n",@loadsrun)."\n";
    print $certification "Words memorized: ".$wordsmemorized."\n";
    print $certification "All words loaded:\n".join(", ",@allloaded);
  }
  elsif($responsewords[0] eq "conditions") {
    my $doc = <<END;
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
END
    print $doc;
  }
  elsif($responsewords[0] eq "fakecertify") {
    if(scalar @loaded) {
      my $result = open my $certification, ">", "certification.txt";
      if(!$result) {
        print "Could not open certification.txt for writing: ".$!;
      }
      print $certification "Load commands run:\n".join("\n",@loadsrun)."\n";
      print $certification "Words memorized: ".(scalar @loaded)."\n";
      print $certification "All words loaded:\n".join(", ",@loaded);
    }
    else {
      print "Sorry, you have no words loaded! Try `help load'.\n";
    }
  }
  elsif($responsewords[0] eq "load") {
    push @loadsrun, $response;
    my @toload = ();
    if(scalar @responsewords == 1) {
      my $doc = <<END;
This command can only be run with arguments. Type `help load' for details.
END
      print $doc;
    }
    elsif(lc $responsewords[1] eq "backup") {
      my $result = open my $backup, "<", "resources/backup";
      if(!$result) {
        print "Couldn't open backup: ".$!."\n";
        next PROMPT;
      }
      @toload = split(", ", readline $backup);
    }
    elsif(lc $responsewords[1] eq "clear") {
      @loaded = ();
    }
    elsif(lc $responsewords[1] eq "lines") {
      my $result = open my $aeneid, "<", "resources/aeneid-1.txt";
      if(!$result) {
        print "Couldn't open Aeneid: ".$!."\n";
        if($^O eq "MSWin32") {
          print "Maybe you haven't extracted the contents of the zip file?\n"
        }
        next PROMPT;
      }
      my $linen = 1;
      my $endn  = 756;
      if($responsewords[2]) {
        if($responsewords[2] =~ m/^([0-9]+)-([0-9]+)$/ && $1 <= $2) {
          $responsewords[2] =~ m/^([0-9]+)-([0-9]+)$/;
          $linen = $1;
          $endn  = ($2, 756)[$2 > 756];
        }
        else {
          my $doc = <<END;
Incorrect format for line numbers. You must write `load <source> a-b', where a
and b are numbers such that b is greater than or equal to a.
END
          print $doc;
          next PROMPT;
        }
      }
      # Read in words from text
      if($linen > 1) {
        foreach my $i (1 .. ($linen-1)) {
          readline $aeneid;
        }
      }
      while($linen <= $endn) {
        my $line = readline $aeneid;
        chomp $line;
        my @linewords = split(" ", $line);
        foreach my $word (@linewords) {
          $word =~ s/[\.,;!\?"'`\(\)\[\]]//g;
          if($word ne lc $word) {
            push @linewords, lc $word;
          }
        }
        push @toload, @linewords;
        $linen += 1;
      }
    }
    elsif(lc $responsewords[1] eq "save") {
      my $result = open my $save, "<", "resources/save";
      if(!$result) {
        print "Couldn't open save: ".$!."\n";
        next PROMPT;
      }
      @toload = split(", ", readline $save);
    }
    elsif((-T "lists/".$responsewords[1] && substr $responsewords[1], -4 eq ".csv") || -T "lists/".$responsewords[1].".csv") {
      my $result;
      my $csv;
      if(-T "lists/".$responsewords[1] && substr $responsewords[1], -4 eq ".csv") {
        $result = open $csv, "<", "lists/".$responsewords[1];
      }
      elsif(-T "lists/".$responsewords[1].".csv") {
        $result = open $csv, "<", "lists/".$responsewords[1].".csv";
      }
      if(!$result) {
        print "Couldn't open list: ".$!."\n";
        next PROMPT;
      }
      my $linen = 1;
      my $endn  = 756;
      if($responsewords[2]) {
        if($responsewords[2] =~ m/^([0-9]+)-([0-9]+)$/ && $1 <= $2) {
          $responsewords[2] =~ m/^([0-9]+)-([0-9]+)$/;
          $linen = $1;
          $endn  = (756, $2)[756 > $2];
        }
        else {
          my $doc = <<END;
Incorrect format for line numbers. You must write `load lines a-b', where a and
b are numbers such that b is greater than or equal to a.
END
          print $doc;
          next PROMPT;
        }
      }
      my $linecount = 1;
      while(!eof $csv) {
        my $line = readline $csv;
        if($linecount == 1 && $line =~ m/#/) {
          next;
        }
        my @items = split(",", $line);
        if(scalar @items != 2 || $items[0] !~ m/^\d+$/) {
          my $doc = <<END;
Incorrect format for list. It must be a CSV file, with the first item on each
line being a line number, and the second item on each line being a Latin word,
and there being no other items on the line. For an example of the correct format
download the second page of Ms. McMillan's online document as a CSV and examine
it in a text editor.
END
          print $doc;
          next PROMPT;
        }
        foreach my $item (@items) {
          $item =~ s/^\s+|\s+$//g;
        }
        if($linen <= $items[0] && $items[0] <= $endn) {
          push @toload, $items[1];
        }
        $linecount += 1;
      }
      if(!scalar @toload) {
        my $doc = <<END;
Warning: no words were loaded. (Maybe they weren't in the range you specified?)
END
        print $doc;
        next PROMPT;
      }
    }
    else {
      my $doc = <<END;
Sorry, either the file you wanted to load was not found, or the argument you
passed to `load' was invalid.
END
      print $doc;
    }
    push @loaded, @toload;
    push @allloaded, @toload;
  }
  elsif($responsewords[0] eq "quiz") {
    if(!scalar @loaded) {
      my $doc = <<END;
You have no words loaded to get quizzed on. Load some with `load'; type
`help load' for more information about loading.
END
      print $doc;
      next PROMPT;
    }
    $wordsmemorized = quiz(@loaded);
    @loaded = ();
  }
  elsif($responsewords[0] eq "warranty") {
    my $doc = <<END;
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
END
    print $doc;
  }
  else {
    print "That command doesn't exist. Try `help'.\n";
  }
}

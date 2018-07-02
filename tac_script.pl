#!/usr/bin/perl -w

use warnings;
use Data::Dumper qw(Dumper);
$Data::Dumper::Sortkeys = 1;
use HTML::Entities;
use Encode;

my @files = sort(<data\/PMC[0-9]*.xml>);
my @textFiles = sort(<data\/PMC[0-9]*.txt>);

my %data;
my %window_hash;
my %span_hash;
my %features;
my $filename = $ARGV[0];

window_size();
print_hash();
#parses_xml();
#print_span();


##
sub parses_xml{
    foreach my $file (@files)
    {
        open(DATA, "$file") || die "$!";
        my $tempNum = 0;
        while(<DATA>)
        {
            chomp($_);
            if($_=~/<Mention id=\"(.*?)\" label=\"(.*?)\" span=\"(.*?)\" str=\"(.*?)\"\/>/) { 
                my $label = $2; my $span = $3; my $str = $4; 
                $str = lc($str);
                chomp($label);
                chomp($span);
                chomp($str);

                ##Analytics for label location##
                my @temp_span = split(' ', $span);
                $span_hash{$file}{$label}{$tempNum} = $temp_span[0];
                $tempNum++;
                
                ### This should likely be moved elsewhere, just a temporary thing to look at species data
                if($label eq "Species"){
                    $str =~ s/[[:punct:]]//g;
                }
                ###

                ## I don't remember what issue this is handling
                if($str =~ m/[a-z0-9]+\s*\((.*?)\)/)
                {
                    $str =~ s/\((.*?)\)//g;
                }
                elsif($str =~ m/\((.*?)\)\s*[a-z0-9]+/)
                {
                    $str =~ s/\((.*?)\)//g;
                }
                elsif($str =~ m/[a-z0-9]+\s*\((.*?)\)\s*[a-z0-9]+/)
                {
                    $str =~ s/\((.*?)\)//g;
                }

                #Text Sanatization, not removing all punctuation
                $str = remove_non_utf_8($str);
                $str =~ s/(\,|\:|\!|\.|\'|\(|\)|\;)//g;
                $str =~ s/\+{2,}//g;
                
                #Remove white space
                $str =~ s/^\s+|\s+$//g;

                if(exists $data{$str})
                {
                    $data{$str}{FREQUENCY}++;
                }
                else
                {
                    $data{$str}{FREQUENCY} = 1;
                    $data{$str}{LABEL} = $label;
                    $data{$str}{CATEGORY} = return_category_of_label_tag($label);
                    $data{$str}{FILENAME} = $file;
                    $data{$str}{SPAN} = $span;                   
                }
            }
        }
    }
}

#returns the category to each label tag; used for data analytics
sub return_category_of_label_tag{
    if(($_[0] eq "TestArticle") || ($_[0] eq "Vehicle") || ($_[0] eq "TestArticlePurity") || ($_[0] eq "TestArticleVerification"))
    {
        return "EXPOSURE";
    }
    elsif(($_[0] eq "GroupName") || ($_[0] eq "GroupSize") || ($_[0] eq "SampleSize") || ($_[0] eq "Species") || ($_[0] eq "Strain") || ($_[0] eq "Sex") || ($_[0] eq "CellLine"))
    {
        return "ANIMAL GROUP";
    }
    elsif(($_[0] eq "Dose") || ($_[0] eq "DoseUnits") || ($_[0] eq "DoseFrequency") || ($_[0] eq "DoseDuration") || ($_[0] eq "DoseDurationUnits") || ($_[0] eq "DoseRoute") || ($_[0] eq "TimeAtDose") || ($_[0] eq "TimeUnits") || ($_[0] eq "TimeAtFirstDose") || ($_[0] eq "TimeAtLastDose"))
    {
        return "DOSE GROUP";
    }
    elsif(($_[0] eq "Endpoint") || ($_[0] eq "EndpointUnitOfMeasure") || ($_[0] eq "TimeEndpointAssessed"))
    {
        return "ENDPOINT";
    }
    else{
        return "ERROR NOT ONE OF FOUR GROUPS";
    }
}

#Processes text files of the TAC data set 
sub window_size{
    my $windowSize = shift;
    foreach my $file (@files){
        open(DATA, "$file") || die "$!";
        my $str;
        while(<DATA>)
        {
            chomp($_);
            $str .= $_;
        }
        #cleaning data
        $str =~ s/(\,|\:|\!|\.|\'|\(|\)|\;)//g; #should probably pull this out and create subroutines
        $str = lc($str);
        ####
        my @val = split(' ', $str);
        for(my $i = 0; $i < scalar(@val); $i++){
            for(my $j = 1; $j <= $windowSize; $j++){
                if(($i-$j) >= 0){
                    $features{$val[$i]}{$val[$i-$j]}++;
                }
                if(($i+$j) < scalar(@val)){
                    $features{$val[$i]}{$val[$i+$j]}++;
                }
            }
        }
    }
}

#Count the number of characters within a file
sub character_count_in_file{
  foreach $file (@files)
    {
        open(DATA, "$file") || die "$!";
        my $chars;
        while(<DATA>)
        {
            $chars += length($_);
        }
        $span_hash{$file}{SIZE} = $chars;
    }
}

#############################################
#
#   Below are subroutines that sanatize data
#
#############################################

#Remove characters that do not fall within the UTF-8 character set spectrum
#TAC represents their decimal format
sub remove_non_utf_8{
    $_[0] =~ s/&#215;/x/g; #replaces multiplication
    $_[0] =~ s/&#8201;/ /g; #replaces thin space with space
    $_[0] =~ s/&#8211;/-/g; #en dash
    $_[0] =~ s/&#8212;/-/g; #em dash
    $_[0] =~ s/&#160;/ /g; #replaces no-break space with space 
    $_[0] =~ s/&#8805;/>=/g; #replaces great than or equal to
    $_[0] =~ s/&lt;/</g; #less than sign
    $_[0] =~ s/&#8722;/-/g; #minus sign
    $_[0] =~ s/&gt;/>/g; #greater than
    $_[0] =~ s/&#8220;/"/g; #left quote
    $_[0] =~ s/&#8221;/"/g; #right quote
    $_[0] =~ s/&#177;/+=/g; #plusminus sign
    $_[0] =~ s/&#180;/'/g; #acute accent
    $_[0] =~ s/&#8208;/-/g; #hypen
    $_[0] =~ s/&#8217;/'/g; #right quote
    $_[0] =~ s/&#8216;/'/g; #right quote
    $_[0] =~ s/&#8226;/ /g; #bullet
    $_[0] =~ s/&#8202/ /g; #hair space
    $_[0] =~ s/&#8203//g; #zerowidth space
    $_[0] =~ s/&#174;//g; #register symbol
    $_[0] =~ s/&#8482;//g; #trademark
    $_[0] =~ s/&#239;/i/g; #i
    $_[0] =~ s/&#8764;/~/g; #tilde 
    $_[0] =~ s/&#183;/*/g; #dot -> star

    #Greek Charaters
    $_[0] =~ s/&#945;(\s?)/alpha$1/g;
    $_[0] =~ s/&#956;/mu/g;
    $_[0] =~ s/&#181;/mu/g;
    $_[0] =~ s/&#946;/beta/g;
    $_[0] =~ s/&#947;/gamma/g;
    $_[0] =~ s/&#954;/kappa/g;
    $_[0] =~ s/&#176;/ degree /g;

    $_[0] =~ s/&#8710;/ increment /g;
    $_[0] =~ s/&#916;/ delta /g;
    #&#181;g is microgram


    return $_[0];
}

###########################################
#
#   Below are subroutines that print data
#
###########################################

#Puts data into the format that is used by Sam Henry for CUIs
sub print_data_for_cui{
    foreach $key(keys %data){
        print "$data{$key}{LABEL}\t$key\n";
    }
}

#Puts data into the format that used to help with data sanatizaiton (EXCEL)
sub print_clean_data{
    foreach $key(keys %data){
        print "$key\t$data{$key}{LABEL}\t$data{$key}{CATEGORY}\t$data{$key}{FREQUENCY}\n";
    }
}

#Puts data into the format that is used to evaluate location of labels (EXCEL)
sub print_location_span{
    foreach $key(keys %span_hash){
        foreach $labelKey(keys %{$span_hash{$key}}){
            foreach $valueKey(keys %{$span_hash{$key}{$labelKey}}){
                print "$key,$labelKey,$span_hash{$key}{SIZE},$span_hash{$key}{$labelKey}{$valueKey}\n";
            }
        }
    }
}

#puts data into the format that is used to analyze window size data (EXCEL)
sub print_window_size_data{
    foreach $key ($keys %features){
        foreach $word (keys %{features{$key}}){
            print "$key,$word,$features{$key}{$word}\n";
        }
    }
}

sub print_hash{
	print "########################################\n";
	#print Dumper \%data;
    #print Dumper \%window_hash;
    print Dumper \%features;
	print "########################################\n";
}
#!/usr/bin/perl

# Author: Michael Larson <mike@vyatta.com>
# Date: 2010
# Description: Perl script for activating/deactivating portions of the configuration

# **** License ****
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2006, 2007, 2008, 2009, 2010 Vyatta, Inc.
# All Rights Reserved.
# **** End License ****

use strict;
use warnings;
use File::Copy;

# Looking for a comment something like this...
#
#             /*    --- CONFIGURATION COMMENTED OUT DURING MIGRATION BELOW ---
#            resp-time 5
#     --- CONFIGURATION COMMENTED OUT DURING MIGRATION ABOVE ---   */
#
#
#

my $file = $ARGV[0];

if (!defined $file) {
    $file = "/opt/vyatta/etc/config/config.boot";
}

my $backup = "$file.boot.strip-migration-comments-bu";
print "copying original configuration $file to $backup\n";
cp($file, $backup)
    or die "Error! Unable to copy $file to $backup: $!";

open(my $inputfile, '<', $file)
    or die "Error! Unable to open file for input \"$file\". $!";

my $contents = "";
my $in_mig_com = 0;
while(<$inputfile>) {
    if ($_ =~ /CONFIGURATION COMMENTED OUT DURING MIGRATION BELOW/) {
	$in_mig_com = 1;
    }
    elsif ($_ =~ /CONFIGURATION COMMENTED OUT DURING MIGRATION ABOVE/) {
	$in_mig_com = 0;
    }
    elsif ($in_mig_com == 1) {
	#do nothing here
    }
    else {
	$contents .= $_;
    }
}
close($inputfile);

open(my $outputfile, '>', $file)
    or die "Error! Unable to open file for output \"$file\". $!";

print $outputfile $contents;
close($outputfile);

print "done\n";

#!/usr/bin/perl -w
#
# cint2c.pl
# Script to convert logs generated by the CINT API logger into a executable
# CINT
# 
# This license is set out in https://raw.githubusercontent.com/Broadcom-Network-Switching-Software/OpenBCM/master/Legal/LICENSE file.
# 
# Copyright 2007-2020 Broadcom Inc. All rights reserved.


# ! /tools/oss/packages/x86_64-rhel5/perl/5.8.8/bin/perl -w

my $in_struct_or_arr = 0;
my $braces = 0;
my $PBMP_COUNT = 0;
my $PBMP = [];

my $UINT64_COUNT = 0;
my $UINT64 = [];

$\ = "\n";
$/ = "\n";
my $indent = "";

while (<STDIN>) {

chomp;

my $ln = $_;

$ln =~ s/\/\*.*\*\///g;
if ($ln =~ /^(\s+)/) {
    $indent = $1;
}

# bcm_bbmp_t ports = { 1 2 201 }
if ($ln =~ /^\s+bcm_pbmp_t\s+([[:alnum:]_\[\]]+)\s+=\s+{([[:space:][:digit:]]*)}\s*$/) {
    my ($name, $ports) = ($1, $2);
    if ($in_struct_or_arr) {
	$ports =~ s/^ //g;
	if ($ports eq "") {
	    printf("%-80s /* %-100s */\n", $indent . "EMPTY_PBMP,", "$ln --> how to initialize PBMP in struct or array?");
	} else {
	    printf("%-80s /* %-100s */\n", $indent . "PBMP_$PBMP_COUNT,", "$ln --> how to initialize PBMP in struct or array?");
	    my @ports = split / /, $ports;
	    push @$PBMP, \@ports;

	    #printf("%-80s /* %-100s */\n", $indent . "", "bcm_pbmp_t PBMP_$PBMP_COUNT;");
	    #foreach my $port (@ports) {
		#printf("%-80s /* %-100s */\n", $indent . "", "BCM_PBMP_PORT_ADD(PBMP_$PBMP_COUNT, $port);");
	    #}
	    $PBMP_COUNT++;
	}
	next;
    }

    printf("%-80s /* %-100s */\n", $indent . "bcm_pbmp_t $name;", "$ln --> is PBMP");
    $ports =~ s/^ //g;
    my @ports = split / /, $ports;
    foreach my $port (@ports) {
	printf("%-80s\n", $indent . "BCM_PBMP_PORT_ADD($name, $port);");
    }

    next;
}

# uint64 value = {0x00000000 0x00000000}
if ($ln =~ /^\s+(u?int64)\s+([[:alnum:]_\[\]]+)\s+=\s+{(0x[[:xdigit:]]+)\s+(0x[[:xdigit:]]+)}\s*$/) {
    my ($type, $name, $hi, $lo) = ($1, $2, $3, $4);
    my $is_zero = ((hex($hi) == 0) && (hex($lo) == 0));
    if ($in_struct_or_arr) {
	if ($is_zero || 1) {
	    printf("%-80s /* %-100s */\n", $indent . "UINT64_ZERO,", "$ln --> how to initialize PBMP in struct or array?");
	} else {
	    printf("%-80s /* %-100s */\n", $indent . "UINT64_$UINT64_COUNT,", "$ln --> how to initialize PBMP in struct or array?");
	    push @$UINT64, { 'hi' => $hi, 'lo' => $lo };
	    $UINT64_COUNT++;
	}
	next;
    }

    printf("%-80s /* %-100s */\n", $indent . "$type $name;", "$ln --> is PBMP");
    printf("%-80s\n", $indent . "COMPILER_64_SET(&$name, $hi, $lo);");

    next;
}

# char* api = 0xabcd1234 "bcm_vlan_port_create"
if ($ln =~ /^\s*(char\*)\s+([[:alnum:]_\[\]]+)\s+=\s+(0x[[:xdigit:]]+|NULL)\s+(\".*\")\s*$/) {
    my ($type, $name, $val, $val2) = ($1, $2, $3, $4);

    $val2 = $val if ($val eq "NULL");

    if ($in_struct_or_arr) {
	printf("%-80s /* %-100s */\n", $indent . "$val2,", "$ln --> atomic, is struct or array member");
	next;
    }

    printf("%-80s /* %-100s */\n", $indent . "$type $name = $val;", "$ln --> is atomic");
    next;
}

if ($ln =~ /^\s*([[:alnum:][:space:]_\[\]\*]+)\s+([[:alnum:]_\[\]]+)\s+=\s+([-[:alnum:]_]+)\s+\(([[:digit:]]+|0x[[:xdigit:]]+)\)\s*$/) {
    my ($type, $name, $val, $val2) = ($1, $2, $3, $4);

#$val = $val2 if ($val < 0);

    if ($in_struct_or_arr) {
	printf("%-80s /* %-100s */\n", $indent . "$val,", "$ln --> atomic, is struct or array member");
	next;
    }

    if ($type =~ s/(\[[[:digit:]]+\])$//) {
	$name .= $1;
    }
    printf("%-80s /* %-100s */\n", $indent . "$type $name = $val;", "$ln --> is atomic");
    next;
}

# int arr[10] = 100
if ($ln =~ /^\s*([[:alnum:][:space:]_\[\]\*]+)\s+([[:alnum:]_\[\]]+)\s+=\s+([[:xdigit:]:]+)\s*$/) {
    my ($type, $name, $val) = ($1, $2, $3);

    if ($in_struct_or_arr) {
	$val =~ s/:/, 0x/g; $val = "{ 0x" . $val . " }";
	printf("%-80s /* %s */\n", $indent . "$val,", "$ln --> atomic mac, is struct or array member");
	next;
    }

    if ($type =~ s/(\[[[:digit:]]+\])$//) {
	$name .= $1;
    }
    $val =~ s/:/, 0x/g; $val = "{ 0x" . $val . " }";
    printf("%-80s /* %-100s */\n", $indent . "$type $name = $val;", "$ln --> is atomic mac");
    next;
}

# ip address
if ($ln =~ /^\s*([[:alnum:][:space:]_\[\]\*]+)\s+([[:alnum:]_\[\]]+)\s+=\s+([[:digit:].]+)\s*$/) {
    my ($type, $name, $val) = ($1, $2, $3);

    if ($in_struct_or_arr) {
	$val = "0x" . join('', map(unpack("H*", pack("C", $_)), split(/\./, $val)));
	printf("%-80s /* %s */\n", $indent . "$val,", "$ln --> atomic ip address, is struct or array member");
	next;
    }

    if ($type =~ s/(\[[[:digit:]]+\])$//) {
	$name .= $1;
    }
    $val = "0x" . join('', map(unpack("H*", pack("C", $_)), split(/\./, $val)));
    printf("%-80s /* %-100s */\n", $indent . "$type $name = $val;", "$ln --> is atomic ip address");
    next;
}

# int *ptr = 100
if ($ln =~ /^\s*([[:alnum:][:space:]_\[\]\*]+)\s+([[:alnum:]_\[\]]+)\s+=\s+([[:alnum:]_]+|[[:digit:]]+|0x[[:xdigit:]]+)\s*$/) {
    my ($type, $name, $val) = ($1, $2, $3);
    if ($in_struct_or_arr) {
#printf("%-80s /* %-100s */\n", $indent . "NULL,", "$ln --> atomic likely pointer, is struct or array member");
	printf("%-80s /* %-100s */\n", $indent . "(void*)$val,", "$ln --> atomic likely pointer, is struct or array member");
	next;
    }

    if ($type =~ s/(\[[[:digit:]]+\])$//) {
	$name .= $1;
    }
#printf("%-80s /* %-100s */\n", $indent . "$type $name = NULL;", "$ln --> is atomic likely pointer");
    printf("%-80s /* %-100s */\n", $indent . "$type $name = (void*)$val;", "$ln --> is atomic likely pointer");
    next;
}

# int arr[100] = {
if ($ln =~ /^\s*([[:alnum:][:space:]_\[\]\*]+)\s+([[:alnum:]_\[\]]+)\s+=\s+{\s*$/) {
    my ($type, $name) = ($1, $2);

    $braces++;

    if ($in_struct_or_arr) {
	printf("%-80s /* %-100s */\n", $indent . "{", "$ln --> is struct or array member");
	next;
    }

    if ($type =~ s/(\[[[:digit:]]+\])$//) {
	$name .= $1;
    }
    printf("%-80s /* %-100s */\n", $indent . "$type $name = {", "$ln --> is struct or array");
    $in_struct_or_arr = 1;
    next;
}

# close braces }
if ($ln =~ /^\s*}/) {
    if ($in_struct_or_arr) {
	$braces--;
	if ($braces) {
	    printf("%-80s /* %-100s */\n", $indent . "},", "$ln --> is struct or array member closure");
	} else {
	    printf("%-80s /* %-100s */\n", $indent . "};", "$ln --> is struct or array closure");
	    $in_struct_or_arr = 0;
	}
	next;
    }
}


printf("%-80s /* %-100s */\n", "$ln", "$ln --> unclassified");

}


$PBMP_COUNT = 0;
foreach my $ports (@$PBMP) {
    my $name = "PBMP_$PBMP_COUNT";
    printf("bcm_pbmp_t $name;\n");
    printf("BCM_PBMP_CLEAR($name);\n");
    foreach my $port (@$ports) {
	printf("%-80s\n", $indent . "BCM_PBMP_PORT_ADD($name, $port);");
    }
    $PBMP_COUNT++;
}

print <<EOT;
uint64 UINT64_ZERO;
bcm_pbmp_t EMPTY_PBMP;
BCM_PBMP_CLEAR(EMPTY_PBMP);
bcm_pbmp_t ALL_PBMP;
{
    int p;
    for (p = 0; p <= BCM_PBMP_PORT_MAX; p++) {
        BCM_PBMP_PORT_ADD(ALL_PBMP, p);
    }
}
EOT


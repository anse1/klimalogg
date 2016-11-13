#!/usr/bin/perl -w

use strict;
use IO::Socket;
use DBI;
use DBD::Pg;

my $dbh = DBI->connect("dbi:Pg:dbname=sensors");
$dbh->do("set application_name to 'klimalogg.pl'");

my $sth = $dbh->prepare('INSERT INTO klimalogg(hygro, temp, raw) VALUES (?,?,?)');
my $server = IO::Socket::INET->new(LocalPort => 35000,
                                Proto     => "udp")
    or die "Couldn't be a UDP server: $@\n";

sub bin2dec ($){
    return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

while (my$sender = $server->recv($_, 1500)) {
    y/\x00\x01/01/;
    print STDERR "$_\n";
    
    foreach my$telegram (/(?:01){5,10}1101111(.{168})1(?:01){20}0{10}/g) {
	$telegram =~ s/1([01])/$1/g;

	my ($prefix, $id, $bcd0, $bcd1, $bcd2, $bcd3, $hygro,
	     $unk, $count, $sum) =
	    $telegram =~ m/^([01]{12}) # prefix
                           ([01]{16})  # id
                           ([01]{4})   # bcd0
                           ([01]{4})   # bcd1
                           ([01]{4})   # bcd2
                           ([01]{4})   # bcd3
                           ([01]{8})   # hygro
                           ([01]{12})  # unk
                           ([01]{4})   # count
                           01101010
                           ([01]{8})   # sum/x;

	next unless defined($count);

#	print $telegram . "\n";
	print "decoded: hygro=" . bin2dec(reverse("$hygro")) . "%";
	my $temp = (bin2dec(reverse("$bcd0")) - 4) * 10 +
	    (bin2dec(reverse("$bcd3"))) + 0.1 * (bin2dec(reverse("$bcd2")));
	printf " temp=%02.1f°C"	, $temp;
	printf " count=%x"	, bin2dec(reverse("$count"));
	printf " id=%x"		, bin2dec(reverse("$id"));
	printf " sum=%02x"	, bin2dec(reverse("$sum"));
	printf " unk=%x"	, bin2dec(reverse("$unk"));
	printf " bcd1=%x"	, bin2dec(reverse("$bcd1"));
	printf " prefix=%x"	, bin2dec(reverse("$prefix"));
	print "\n";

	$sth->execute(bin2dec(reverse("$hygro")), $temp, $telegram)
    }
}




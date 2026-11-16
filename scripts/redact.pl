#!/usr/bin/env perl
# Redact secrets and personal identifiers from stdin -> stdout.
# Secrets: every value in ./.env whose key contains PASSWORD|SECRET|TOKEN|KEY.
# Identifiers: host name, OS user name, home directory, git user.email (read at runtime,
# so this script itself contains none of them).
use strict; use warnings;
binmode STDIN; binmode STDOUT;

my @secrets;
if (open my $fh, '<', '.env') {
    while (<$fh>) {
        s/\r?\n$//;
        next if /^\s*#/ || !/=/;
        my ($k, $v) = split /=/, $_, 2;
        push @secrets, $v if $k =~ /PASSWORD|SECRET|TOKEN|KEY/i && length($v) >= 4;
    }
}
push @secrets, 'bloodhoundcommunityedition';   # upstream default, never used here but redact anyway

my $host  = $ENV{REDACT_HOST}  // '';
my $user  = $ENV{REDACT_USER}  // '';
my $email = $ENV{REDACT_EMAIL} // '';

while (my $l = <STDIN>) {
    for my $s (@secrets) { $l =~ s/\Q$s\E/<redacted>/g; }
    $l =~ s/(Initial Password Set To:\s*)\S+/$1<redacted>/gi;
    $l =~ s/("(?:session_token|token|password|secret|jwt)"\s*:\s*")[^"]*"/$1<redacted>"/gi;
    $l =~ s/(Bearer\s+)[A-Za-z0-9._~+\/=-]+/$1<redacted>/g;
    $l =~ s/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/<redacted-jwt>/g;
    $l =~ s/\Q$email\E/<email>/gi if length $email;
    if (length $user) {
        # home dir in Windows / Git Bash / WSL forms
        $l =~ s{[A-Za-z]:[\\/]+Users[\\/]+\Q$user\E}{~}gi;
        $l =~ s{/(?:mnt/)?[a-z]/Users/\Q$user\E}{~}gi;
        $l =~ s{/home/\Q$user\E}{~}gi;
        $l =~ s/\Q$user\E/<user>/gi;
    }
    $l =~ s/\b\Q$host\E\b/<host>/gi if length $host;
    print $l;
}

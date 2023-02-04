package Smokeping::probes::TraceroutePingPlus;

=head1 301 Moved Permanently

This is a Smokeping probe module. Please use the command

C<smokeping -man Smokeping::probes::TraceroutePingPlus>

to view the documentation or the command

C<smokeping -makepod Smokeping::probes::TraceroutePingPlus>

to generate the POD document.

=cut

use warnings;
use strict;
use base qw(Smokeping::probes::basefork);
# or, alternatively
# use base qw(Smokeping::probes::base);
use Carp;
use IPC::Open3;
use Symbol;
use Socket qw(:addrinfo unpack_sockaddr_in inet_ntoa);


sub pod_hash {
    return {
    name => <<'DOC',
Smokeping::probes::TraceroutePing - use traceroute to obtain RTT for a router
DOC
        description => <<'DOC',
Integrates standard traceroute as a probe into smokeping.  The use
case for this probe is gateways that do not respond to TCP/UDP/ICMP
packets addressed to them, but do return ICMP TTL_EXCEEDED packets for
traceroute packets to a host they route to.  It is best used in
situations where routing for the path is static or nearly so;
attempting to use this on networks with changing routing will yield
poor results.  The best place to use this probe is on first- and
last-mile links, which are more likely to have static routing and
also more likely to have firewalls that ignore ICMP ECHO_REQUEST.

The mandatory probe variable B<binary> must have an executable path for
traceroute.

The optional probe variable B<binaryv6> sets an executable path for
your IPv6 traceroute.  If this is set to the same value as B<binary>,
TraceroutePing will use the -6 flag when running traceroute for IPv6
addresses.  If this variable is not set, TraceroutePing will try to
find an functioning IPv6 traceroute.  It will first try appending "6"
to the path in B<binary>, then try including the "-6" flag in a test
command.  Note that Linux appears to have a wide variety of IPv6
traceroute implementations.  My Ubuntu 14.04 machine has
/usr/sbin/traceroute6 from iputils, but /usr/bin/traceroute (from
Dmitry Butskoy) accepts the -6 flag and is actually a better
implementation.  You may need to let TraceroutePing autodetect this, or
experiment to find the best traceroute.

The mandatory target variable B<desthost> must name a destination host
for the probe.  The destination host itself is not of interest and no
data is gathered on it, its only purpose is to route traffic past your
actual target.  Selection of a destination just past your target, with
static or strongly preferred routing through your target, will get
better data.

The mandatory target variable B<host> must name the target host for
the probe.  This is the router that you want to collect RTT data for.
This variable must either be the valid reverse-lookup name of the
router, or its IP address.  Using the IP address is preferable since
it allows us to tell traceroute to avoid DNS lookups.

The target variables B<minttl> and B<maxttl> can be used to describe
the range of expected hop counts to B<host>.  On longer paths or paths
through unresponsive gateways or ending in unresponsive hosts, this
reduces the amount of time this probe takes to execute.  These default
to 1 and 30.

The target variables B<wait> sets the traceroute probe timeout in
seconds.  This defaults to 1, instead of the traditionally higher
value used by LBL traceroute.  Traceroute programs often enforce a
lower bound on this value.
DOC
    authors => <<'DOC',
John Hood <cgull@glup.org>,
DOC
    see_also => <<'DOC'
L<smokeping_extend>
DOC
    };
}

sub new($$$)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);

    $self->do_debug("command: $self->{properties}{binary}, " . $self->{properties}{binary});
    # Do we need to find an IPv6 traceroute?  We can't make it a mandatory probe variable,
    # there are likely people out there still using IPv4-only OS installs.
    if ($self->{properties}{binaryv6}) {
    $self->do_debug("configured v6 command: $self->{properties}{binaryv6}, " .
            $self->{properties}{binaryv6});
    } else {
    my $tail = " -n -q1 -f1 -m1 -w1 ::1 >/dev/null 2>&1";
    # First try "traceroute -6 ..."
    system($self->{properties}{binary} . " -6 ${tail}");
    if ($? == 0) {
        $self->{properties}{binaryv6} = $self->{properties}{binary};
    } else {
        # Then try "traceroute6 ..."
        system($self->{properties}{binary} . "6 ${tail}");
        if ($? == 0) {
        $self->{properties}{binaryv6} = $self->{properties}{binary} . "6";
        } else {
        $self->{properties}{binaryv6} = "/bin/false";
        }
    }
    $self->do_debug("discovered v6 command: $self->{properties}{binaryv6}, " .
            $self->{properties}{binaryv6});
    }
    return $self;
}

sub ProbeDesc($){
    my $self = shift;
    return "Traceroute Pings";
}

# Probe-specific variables.

sub probevars {
    my $class = shift;
    return $class->_makevars($class->SUPER::probevars, {
    _mandatory => [ 'binary' ],
    binary => {
        _doc => "The location of your traceroute binary.",
        _example => '/usr/bin/traceroute',
        _sub => sub {
        my $val = shift;
        return "ERROR: traceroute '$val' does not point to an executable"
            unless -f $val and -x _;
        return undef;
        },
    },
    binaryv6 => {
        _doc => "The location of your IPv6 traceroute binary.",
        _example => '/usr/bin/traceroute6',
        _sub => sub {
        my $val = shift;
        return "ERROR: IPv6 traceroute '$val' does not point to an executable"
            unless -f $val and -x _;
        return undef;
        },
    },
                 });
}

# Target-specific variables.

sub targetvars {
    my $class = shift;
    return $class->_makevars($class->SUPER::targetvars, {
    _mandatory => [ 'host' ],
    host => {
        _doc => "Host of interest to monitor.  Must be either the host's reverse-lookup name, or an IP address.",
        _example => 'www-net-router.example.com',
        _sub => sub {
        my $val = shift;
        return undef;
        },
    },
    port => {
        _doc => "Set the destination port to use. It is either initial udp port value for \"default\" method (incremented by each probe, default is 33434), or initial seq for \"icmp\" (incremented as well, default from 1), or some constant destination port for other methods (with default of 80 for \"tcp\", 53 for \"udp\", etc.)",
        _example => '53',
        _sub     => sub {
        my $val = shift;
        return undef;
        },
    },
    mode => {
        _doc => "Traceroute mode, 'icmp', 'tcp', 'udp' or 'dccp'.  Defaults to icmp.",
        _example => 'udp',
        _sub     => sub {
        my $val = shift;
        return undef;
        },
    },
    iptype => {
        _doc => "If host is an numberic address, this is not used.  If the host is a name, this is the type of IP address to use. Option '4' or '6' Defaults to '4'.",
        _example => '4',
        _sub     => sub {
        my $val = shift;
        return undef;
        },
    },
    interface => {
        _doc => "Interface to use for traceroute probes.  Defaults to none.",
        _example => 'eth0',
        _sub     => sub {
        my $val = shift;
        return undef;
        },
    },
    minttl => {
        _doc => "Minimum TTL.  Set to the minimum expected number of hops to host.",
        _example => '11',
        _sub => sub {
        my $val = shift;
        return undef;
        }
    },
    maxttl => {
        _doc => "Maximum TTL.  Set to the maximum expected number of hops to host.",
        _example => '15',
        _sub => sub {
        my $val = shift;
        return undef;
        },
    },
    wait => {
        _doc => "Waittime.  The timeout value for traceroute's probes, in seconds.",
        _example => '3',
        _sub => sub {
        my $val = shift;
        return undef;
        },
    },
                 });
}

sub pingone ($) {
    my $self = shift;
    my $target = shift;

    # Defaults
    my $minttl = 1;
    my $maxttl = 30;
    my $wait = 1;

    my $port = undef;
    my $mode = 'icmp';
    my $iptype = '4';
    my $interface = undef;

    # Fish out args
    my $binary = $self->{properties}{binary};
    # my $weight = $target->{vars}{weight}
    my $count = $self->pings($target); # the number of pings for this target
    my $host = $target->{vars}{host};
    $port = $target->{vars}{port} if $target->{vars}{port};
    $iptype = $target->{vars}{iptype} if $target->{vars}{iptype};
    $mode = $target->{vars}{mode} if $target->{vars}{mode};

    $interface = $target->{vars}{interface} if $target->{vars}{interface};

    $minttl = $target->{vars}{minttl} if $target->{vars}{minttl};
    $maxttl = $target->{vars}{maxttl} if $target->{vars}{maxttl};
    $wait = $target->{vars}{wait} if $target->{vars}{wait};

    # check name is numberic.
    my %hints = ( flags => Socket::AI_NUMERICHOST );
    my ($err, @res) = getaddrinfo($host, 0, \%hints);
    my $use_numeric = ! $err;
    my $hostinfo = $res[0];

    my $targetIp = undef;
    if (!$use_numeric) {
        # resolve host
        if($iptype eq '6') {
            %hints = ( family => Socket::AF_INET6 );
        } else {
            %hints = ( family => Socket::AF_INET );
        }
        ($err, @res) = getaddrinfo($host, 0, \%hints);
        if($err) {
            $self->log("error", "getaddrinfo: $err");
            return;
        }
        $hostinfo = $res[0];
        my ($hostInfoPort, $hostInfoIp) = unpack_sockaddr_in($hostinfo->{addr});
        $targetIp = inet_ntoa($hostInfoIp);
    } else {
        my ($hostInfoPort, $hostInfoIp) = unpack_sockaddr_in($hostinfo->{addr});
        $targetIp = inet_ntoa($hostInfoIp);
        $iptype = '6' if( $hostinfo->{family} eq Socket::AF_INET6 );
    }

    # ping one target
    my @cmd;
    # if (!$v6) {
    #     push @cmd, $self->{properties}{binary};
    # } else {
    #     push @cmd, $self->{properties}{binaryv6};
    #     my $same_binaries = $self->{properties}{binaryv6} eq $self->{properties}{binary};
    #     if ($same_binaries) {
    #         push @cmd, "-6";
    #     }
    # }

    push @cmd, $self->{properties}{binary};
    if($iptype eq '6') {
        push @cmd, "-6";
    } else {
        push @cmd, "-4";
    }

    push @cmd, (
    '-w', $wait,
    '-f', $minttl,
    '-m', $maxttl,
    '-q', '1',
    '-n'
    );

    $self->do_debug("Mode $mode");
    if ($mode eq 'tcp') {
        push @cmd, '--tcp';
        $port = 80 if !defined($port);
        push @cmd, ('-p', $port);
    } elsif ($mode eq 'udp') {
        push @cmd, '--udp';
        $port = 53 if !defined($port);
        push @cmd, ('-p', $port);
    } elsif ($mode eq 'dccp') {
        push @cmd, '--dccp';
    } else {
        push @cmd, '--icmp';
    }

    if (defined($interface)) {
        push @cmd, ('-i', $interface);
    }

    push(@cmd, $targetIp);

    $self->do_debug("Executing @cmd");

    # Run traceroute for only one iteration in an external loop, to
    # avoid various parsing problems that can come up with >1 iteration.
    my @times;
    for (1..$count) {
    $self->do_debug("Executing @cmd");
    my $killed;
    my $f_stdin = gensym;
    my $f_stdout = gensym;
    my $f_stderr = gensym;
    my $pid = open3($f_stdin, $f_stdout, $f_stderr, @cmd);
    while (<$f_stdout>){
        my $line = $_;
        chomp($line);
        $self->do_debug("stdout: $line");
        next unless $line =~ /^\s*\d+\s+\S+\s+[\d\.,]+\s+\S+\s*$/; # only match RTT output

        my @fields = split(/\s+/,$line);
        shift @fields if $fields[0] eq ''; # discard empty first field
        $self->do_debug("fields: " . join(', ',@fields));
        next unless $targetIp eq $fields[1];

        # shift @fields if !$use_numeric; # discard hostnames to get fields in the same position

        my $time = $fields[2];
        # Adjust time units to smokeping's preferred units.  One
        # enhanced LBL implementation has a -u option for microseconds.
        for ($fields[3]) {
        /^s(|ec(|ond))$/i && do { next; };
        /^(m|milli)s(|ec(|ond))$/i && do { $time /= 1000; next; };
        /^(u|micro)s(|ec(|ond))$/i && do { $time /= 1000000; next; };
        $time /= 1000; # default
        };
        $self->do_debug("time: $time");
        push @times, $time;

        # now we have a time to our target $host-- there's no
        # point in waiting for traceroute to finish the trace to
        # $desthost
        $killed = kill(15, $pid);
        last;
    }
    while (<$f_stderr>){
        my $line = $_;
        chomp($line);
        $self->do_debug("stderr: $line");
    }
    waitpid $pid,0;
    my $rc = $?;
    carp join(" ",@cmd) . " returned with exit code $rc. run with debug enabled to get more information" unless ($rc == 0 || $killed);
    close $f_stdin;
    close $f_stdout;
    close $f_stderr;
    }
    @times = sort {$a <=> $b} @times;
    $self->do_debug("Times: " . join(' ', @times));
    return @times;
}
# That's all, folks!

1;

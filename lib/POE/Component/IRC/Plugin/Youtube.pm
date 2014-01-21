package POE::Component::IRC::Plugin::Youtube;

use strict;
use warnings;

use POE::Component::IRC::Plugin::Youtube::Tools;

use POE::Component::IRC;
use POE::Component::IRC::Plugin qw( :ALL );

# needed to avoid: Net::SSL from Crypt-SSLeay cant verify hostnames; either install IO::Socket::SSL or turn off verification by setting the PERL_LWP_SSL_VERIFY_HOSTNAME environment variable to 0 at /usr/share/perl5/LWP/Protocol/http.pm line 51.
use IO::Socket::SSL;

use HTTP::Request;
use XML::RSS;

sub new {
    my ($package, %args) = @_;

    my $self = bless \%args, $package;

    $self->{rss} = XML::RSS->new();

    return $self;
}

sub PCI_register {
    my ($self, $irc) = @_;

    $irc->plugin_register($self, 'SERVER', 'ping');
    $irc->plugin_register($self, 'SERVER', 'botcmd_channels');
    $irc->plugin_register($self, 'SERVER', 'botcmd_check');

    my $botcmd;
    foreach my $plugin ( values %{ $irc->plugin_list } ){
        if ( $plugin->isa('POE::Component::IRC::Plugin::BotCommand') ){
            $botcmd = $plugin;
            last;
        }
    }
    die __PACKAGE__ . " depends on BotCommand plugin\n" unless defined $botcmd;

    $botcmd->add(channels => 'usage: channels');
    $botcmd->add(check    => 'usage: check');

    return 1;
}

sub PCI_unregister {
    return 1;
}

sub S_botcmd_channels {
    my ($self, $irc) = (shift, shift);

    my $nick = shift;
    my $channel = shift;
    my $message = shift;

    $irc->yield(
        notice => $$channel,
        "Following: [@{[ join ', ', @{ $self->{channels} } ]}]",
    );

    return PCI_EAT_NONE;
}

sub S_botcmd_check {
    my ($self, $irc) = (shift, shift);

    my $nick = shift;
    my $channel = shift;
    my $message = shift;

    POE::Component::IRC::Plugin::Youtube::Tools::periodic_check( $self, $irc, $self->{channels} );

    return PCI_EAT_NONE;
}

sub S_ping {
    my ($self, $irc) = (shift, shift);

    $self->{last_check_time} //= time;
    my $secs_past = time - $self->{last_check_time};

    warn " -- last_check_time:$self->{last_check_time} secs_past:$secs_past\n" if $self->{debug};

    if ($secs_past >= $self->{minutes_between_checks} * 60){
        warn "re-checking youtube feeds\n" if $self->{debug};

        POE::Component::IRC::Plugin::Youtube::Tools::periodic_check( $self, $irc, $self->{channels} );

        $self->{last_check_time} = time;
    }

    return PCI_EAT_NONE;
}

1;

__END__

# vim: tabstop=4 shiftwidth=4 expandtab cindent:

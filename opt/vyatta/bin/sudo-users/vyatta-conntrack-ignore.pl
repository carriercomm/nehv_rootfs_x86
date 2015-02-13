#!/usr/bin/perl

use lib "/opt/vyatta/share/perl5";
use warnings;
use strict;

use Vyatta::Config;
use Vyatta::Conntrack::RuleCT;
use Vyatta::Conntrack::RuleIgnore;
use Vyatta::IpTables::AddressFilter;
use Vyatta::Conntrack::ConntrackUtil;
use Getopt::Long;
use Vyatta::Zone;
use Sys::Syslog qw(:standard :macros);

#for future use when v6 ignore s need to be set
my %cmd_hash = ( 'ipv4'        => 'iptables',
		 'ipv6'   => 'ip6tables');
# Enable printing debug output to stdout.
my $debug_flag = 0;

# Enable sending debug output to syslog.
my $syslog_flag = 0;
my $nfct = "sudo /usr/sbin/nfct";
my ($create, $delete, $update);
my $CTERROR = "Conntrack ignore  error:";
GetOptions("create=s"        => \$create,
           "delete=s"        => \$delete,
           "update=s"        => \$update,
);

update_config();

openlog("vyatta-conntrack", "pid", "local0");

sub remove_ignore_policy {
    my ($rule_string) = @_;
    my $iptables_cmd1 = "iptables -D VYATTA_CT_IGNORE -t raw $rule_string -j NOTRACK";
    my $iptables_cmd2 = "iptables -D VYATTA_CT_IGNORE -t raw $rule_string -j RETURN";
    run_cmd($iptables_cmd2);
    if ($? >> 8) {
     print "$CTERROR failed to run $iptables_cmd2\n";    
      #dont exit, try to clean as much. 
    }
    run_cmd($iptables_cmd1);
    if ($? >> 8) {
      print "$CTERROR failed to run $iptables_cmd1\n";    
    }
}

sub apply_ignore_policy {
   my ($rule_string, $rule, $num_rules) = @_;
   # insert at num_rules + 1 as there are so many rules already. 
   my $iptables_cmd1 = "iptables -I VYATTA_CT_IGNORE $num_rules -t raw $rule_string -j NOTRACK";
   $num_rules +=1;
   my $iptables_cmd2 = "iptables -I VYATTA_CT_IGNORE $num_rules -t raw $rule_string -j RETURN";
   run_cmd($iptables_cmd1);
    if ($? >> 8) {
     print "$CTERROR failed to run $iptables_cmd1\n";    
     exit 1; 
   }
   run_cmd($iptables_cmd2);
    if ($? >> 8) {
     print "$CTERROR failed to run $iptables_cmd2\n";    
     exit 1; 
   }
}

sub handle_rule_creation {
  my ($rule, $num_rules) = @_;
  my $node = new Vyatta::Conntrack::RuleIgnore;
  my ($rule_string);

  do_minimalrule_check($rule);
  $node->setup("system conntrack ignore rule $rule");
  $rule_string = $node->rule();
  apply_ignore_policy($rule_string, $rule, $num_rules);
}

# mandate atleast inbound interface / source ip / dest ip or protocol per rule
sub do_minimalrule_check {
  my ($rule) = @_;
  my $config = new Vyatta::Config;
  my $intf = $config->exists("system conntrack ignore rule $rule inbound-interface");
  my $src = $config->exists("system conntrack ignore rule $rule source address");
  my $dst = $config->exists("system conntrack ignore rule $rule destination address");
  my $protocol = $config->exists("system conntrack ignore rule $rule protocol");

  if ( (!$intf) and (!$src) and (!$dst) and (!$protocol)) {
    Vyatta::Config::outputError(["Conntrack"], "Conntrack config error: No inbound-interface, source / destination address, protocol found in rule @_ ");
    exit 1;
  }
}

sub handle_rule_modification {
  my ($rule, $num_rules) = @_;
  do_minimalrule_check($rule);
  handle_rule_deletion($rule);
  handle_rule_creation($rule, $num_rules);
}

sub handle_rule_deletion {
  my ($rule) = @_;
  my $node = new Vyatta::Conntrack::RuleIgnore;
  my ($rule_string);
  $node->setupOrig("system conntrack ignore rule $rule");
  $rule_string = $node->rule();
  remove_ignore_policy($rule_string);
}

sub numerically { $a <=> $b; }

sub update_config {
  my $config = new Vyatta::Config;
  my %rules = (); #hash of ignore config rules  
  my $iptables_cmd = $cmd_hash{'ipv4'};

  $config->setLevel("system conntrack ignore rule");
  %rules = $config->listNodeStatus();

  my $iptablesrule = 1;
  foreach my $rule (sort numerically keys %rules) { 
    if ("$rules{$rule}" eq 'static') {
      $iptablesrule+=2;
    } elsif ("$rules{$rule}" eq 'added') {      
        handle_rule_creation($rule, $iptablesrule);
        $iptablesrule+=2;
    } elsif ("$rules{$rule}" eq 'changed') {
        handle_rule_modification($rule, $iptablesrule);
        $iptablesrule+=2;
    } elsif ("$rules{$rule}" eq 'deleted') {
        handle_rule_deletion($rule);
    }  
  }
}


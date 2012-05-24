# And an NTP nodes class that can be used in other descriptions.  This updates the 
# default NTP server added via cobbler (if used for node deployments)
# NOTE: Puppet gets unhappy if NTP is out of sync. 
node ntp_nodes { class { ntp:
  servers => [ "ntp.esl.cisco.com", "2.ntp.esl.cisco.com", "3.ntp.esl.cisco.com", ],
  ensure => running,
  autoupdate => true,
 }
}

# A node definition for cobbler, note that it inherets ntp, just to make sure
# You will likely want ot change the name regex, either to match the FQDN, or
# to match an appropriate subset.
# You will likely also want to change the IP addresses, domain name, and perhaps
# even the proxy address
# If you are not using UCS blades, don't worry about the org-EXAMPLE, and if you are
# and aren't using an organization domain, just leave the value as ""
# An example MD5 crypted password is ubuntu: .DO/SOAPxKem.dRDx6UbyMd0HM6RQl1fxHYxPRuYFrRB04OcbO7c1
# which is used by the cobbler preseed file to set up the default admin user.
node /cobbler\.example\.com/ inherits ntp_nodes {

 class { puppet:
  run_master => true,
  run_agent => false,
  puppetmaster_address => "cobbler.example.com",
 }

 
 class { cobbler:
  node_subnet      => "192.168.1.0",
  node_netmask     => "255.255.255.0",
  node_gateway     => "192.168.1.1",
  node_dns         => "192.168.1.1",
  domain_name      => "example.com",
  ip               => "192.168.1.5",
 }

# Add cobbler::node definitions here:


# Let's also make sure we have cloned the appropriate cobbler boot isos (UBUNTU SPECIFIC)

 cobbler::ubuntu { "precise":
 }

# And we need a preseed file before we get ahead of ourselves.

cobbler::ubuntu::preseed { "cisco-preseed":
 packages => "openssh-server ntp bridge-utils puppet dnsmasq",
 late_command => "sed -e \"/logdir/ a pluginsync=true\" -i /target/etc/puppet/puppet.conf ; sed -e \"s/START=no/START=yes/\" -i /target/etc/default/puppet ; echo \"server \$http_server iburst\" > /target/etc/ntp.conf ; wget -O /dev/null http://\$http_server:\$http_port/cblr/svc/op/nopxe/system/\$system_name ",
 proxy => "http://128.107.252.163:3142/",
 password_crypted => '$6$5NP1.NbW$WOXi0W1eXf9GOc0uThT5pBNZHqDH9JNczVjt9nzFsH7IkJdkUpLeuvBU.Zs9x3P6LBGKQh6b0zuR8XSlmcuGn.',
}

# Add a node into the cobbler system
# Change as appropriate (mac address and IP at least) to match
# your environment
 cobbler::node { "sdu-os-1":
  mac                => "00:25:b5:00:00:08",
  profile            => "precise-x86_64-auto",
  ip                 => "192.168.1.5",
  domain             => "example.com",
  preseed            => "/etc/cobbler/preseeds/cisco-preseed",
  power_address      => "192.168.6.15:org-EXAMPLE",
  power_type         => "ucs",
  power_user         => "admin",
  power_password     => "Sdu!12345",
  power_id           => "EXAMPLE-1",
  boot_disk          => "/dev/sdc",
  add_hosts_entry    => true,
  extra_host_aliases => ["nova","keystone","glance","horizon"],
 }


}

# A node definition to make sure that puppet points to the puppet master for your 
# cloud.  Likely you will want to change the name here as well (by default puppet
# will look for "puppet", this adds the FQDN instead)
# Also note, this inhereits ntp again
node cloud_nodes inherits ntp_nodes { class { puppet:
  run_agent => true,
  puppetmaster_address => "puppet.example.com",
 }
}

# Node Definitions

# This is a definition of a controller node, that also includes compute
# Principally, this node, runs nova, glance, keystone, and eventually could run 
# horizon, quantum, melange, etc.
# The IP here should point back to the the all-in-one host
# (in this case cloud-ctrl-5 is 192.168.1.5)
node /could-ctrl-5\.example\.com/ inherits cloud_nodes {class { "openstack::all-in-one":
 }
 bridge_ip => '192.168.2.5',
 nova::db::host_access { "192.168.1.5":
  user      => "nova",
  password  => $openstack::all-in-one::nova_db_password,
  database  => "nova",
 }
}

# This is a definition for a cloud compute node only.
# Change the bridge IP, glance IP, and mysql IP as appropriate
node /cloud-cmp-10\.example\.com/ inherits cloud_nodes { class { "openstack::compute-node":
  bridge_ip => '192.168.2.10',
  glance_api_servers => '192.168.1.5:9292',
  mysql_ip => "192.168.1.5",
 }
}

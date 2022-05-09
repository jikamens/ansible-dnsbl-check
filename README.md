Monitor for your server on DNS blocklists
=========================================

This repository contains a shell script which checks if the host it's running on is listed in any [DNS blackhole lists][dnsbl] (DNSBLs); a list of DNSBLs to check; and an Ansible playbook to deploy the script.

The script needs the `perl`, `curl`, a version of `hostname` that supports `--fqdn`, `host`, `awk`, `sort`, and `comm`. The script is silent if there are no hits or errors; any DNSBL matches are reported to stdout.

To install the script by hand:

1. Copy `dnsbls` to `/etc/dnsbls`.
2. Copy `dnsbl-check.sh` to `/usr/bin`, `/usr/local/bin`, or wherever else you want to put it.
3. Configure a cron job or whatever to run the script periodically; make sure cron is properly configured to email you job output so you'll see the script output when it has DNSBL hits to report.

As an alternative to steps 2 and 3 above, you can copy the script directly to `/etc/cron.hourly`, but if you do that, you need to remove the `.sh` extension, because `cron` won't run files in `/etc/cron.hourly` that have periods in their names.

The Ansible playbook uses the latter approach. To use the playbook, the host(s) you want to install the script on need to be listed in an inventory group called `dnsbl_check_hosts`. The playbook attempts to be compatible with both DEB- and RPM-based Linux distributions.

If you end up listed in a DNSBL and there's nothing you can do about it and you don't want to keep learning about it, then create /etc/dnsbls.bad and copy the host name of the bad DNSBL from /etc/dnsbls into /etc/dnsbls.bad, and then you won't get alerted about it anymore, but if/when you _stop_ being listed in that DNSBL you'll be notified about that.

All of the code here is pretty straightforward, so if you have any other questions the first thing to do is read the code. If that doesn't work, you can [start a discussion][discussions] or [create an issue][issues].

The code lives in [GitHub][github].

Author: Jonathan Kamens <<jik@kamens.us>>.

Copyright: The author releases this code into the public domain. You can do whatever you want with it.

[dnsbl]: https://en.wikipedia.org/wiki/Domain_Name_System-based_blackhole_list
[discussions]: https://github.com/jikamens/ansible-dnsbl-check/discussions
[issues]: https://github.com/jikamens/ansible-dnsbl-check/issues
[github]: https://github.com/jikamens/ansible-dnsbl-check

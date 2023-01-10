# nethserver-flashstart-hybrid

This work is forked from https://github.com/nethesis/nethserver-flashstart

This package is forked from implements DNS filtering using Flashstart servers.

Every request from local zones to port tcp/udp 53, is redirected to Unbound.

Unbound is configured as follow:

- Forward queries for server machine domain to dnsmasq
- Forward reverse queries for all green interfaces to dnsmasq
- Forward every remaining query to Flashstart DNS (``188.94.192.215`` and ``45.76.84.187``)

Please note that queries from the server itself are never filtered.

*Note:* When this package is installed, DNSBL from nethserver-mail-filter may not correctly work.

### Database

Properties:
- ``Bypass``: comma-separeted list of firewall object (or ip addresses) which are not redirect to Unbound.
  Flashstart DNS can't be bypassed if the client is using Squid to surf the web.
- ``Password``: password for Flashstart service
- ``Roles``: comma-separated list of Roles, default to ``green``. The ``red`` role is not allowed.
- ``Username``: user name for Flashstart service
- ``status``: can be ``enabled`` or ``disabled``. Default to ``disabled``.
- ``UpdateInterval``: a cronjob to update the WAN IP address is executed each ``UpdateInterval`` minutes. Default 30.
- ``PortalUrl``: portal URL to be used inside the UI

Example:
```
flashstart=configuration
    Bypass=
    Password=11223344
    PortalUrl=https://flashstart.nethesis.it
    Roles=green
    Username=test@nethesis.it
    status=enabled

```


## Usage from command line

After registering at https://flashstart.nethesis.it,
configure Flashstart and enable access to Unbound:

```
config setprop flashstart status enabled
config setprop unbound access $(config getprop flashstart Roles)
config setprop flashstart Password <pass>
config setprop flashstart Username <user>

signal-event nethserver-flashstart-hybrid-save
```

Changing the update interval:

```
config setprop flashstart UpdateInterval 5
signal-event nethserver-flashstart-hybrid-save
```

## Force IP renewal

If you need to notify a public IP has change, execute:
```
/etc/e-smith/events/actions/nethserver-flashstart-hybrid-auth-ip
```

## Testing

Execute a DNS query using unbound:

```
dig -t A +noall +answer <domain> @localhost -p $(config getprop unbound UDPPort)
```

If ``<domain>`` is blocked, the server will respond ``188.94.192.215`` or ``45.76.84.187``.

## Cockpit API

### `read` API

This api can return:

- `flashstart` configuration
- the list of network roles configured on the system: only `green`, `blue` and `hotspot` roles are considered.

#### Input

- `config`: `flashstart`, `networkRoles` or `dashboard`

#### Input example (`flashstart`)

```
{
  "config": "flashstart"
}
```

#### Output example (`flashstart`)
```
{
  "configuration": {
    "type": "configuration",
    "name": "flashstart",
    "props": {
      "status": "enabled",
      "Username": "user@company.com",
      "Roles": "green",
      "Bypass": "10.20.30.40,11.22.33.0/24",
      "UpdateInterval": "30",
      "Password": "s3cr3t!"
    }
  }
}
```

#### Input example (`networkRoles`)
```
{
  "config": "networkRoles"
}
```

#### Output example (`networkRoles`)
```
{
  "configuration": {
    "networkRoles": [
      "blue",
      "green"
    ]
  }
}
```

#### Input example (`dashboard`)

```
{
  "config": "dashboard"
}
```

#### Output example (`dashboard`)
```
{
  "configuration": {
    "loginOk": true,
    "flashstartEnabled": "enabled"
  }
}
```

### `validate` API

This api validates the input before updating `flashstart` configuration.

#### Input

- `enableFlashstart`: toggles FlashStart activation, can be `enabled` or `disabled`
- `username`: username of FlashStart account
- `password`: password of FlashStart account
- `rolesFilter`: specifies on which types of networks FlashStart filter should be enabled
- `bypass`: list of source IP addresses and/or networks in CIDR notation on which FlashStart filter should be disabled

#### Input example

```
{
  "enableFlashstart": "enabled",
  "username": "user@company.com",
  "password": "s3cr3t!",
  "rolesFilter": [
    "green"
  ],
  "bypass": [
    "10.20.30.40",
    "11.22.33.0/24"
  ]
}
```

#### Output example
```
{
  "state": "success"
}
```

### `update` API

This api updates `flashstart` configuration.

#### Input

Same input as `validate`.

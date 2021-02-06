# Users and SSH Keys

For **Dockerfile** and **Buildpack** based application deploys via `git push`, Deis Workflow identifies users via SSH
keys. SSH keys are pushed to the platform and must be unique to each user. Users may have multiple SSH keys as needed.

## Generate an SSH Key

If you do not already have an SSH key or would like to create a new key for Deis Workflow, generate a new key using
`ssh-keygen`:

```
$ ssh-keygen -f ~/.ssh/id_deis -t rsa
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /Users/admin/.ssh/id_deis.
Your public key has been saved in /Users/admin/.ssh/id_deis.pub.
The key fingerprint is:
3d:ac:1f:f4:83:f7:64:51:c1:7e:7f:80:b6:70:36:c9 admin@plinth-23437.local
The key's randomart image is:
+--[ RSA 2048]----+
|              .. |
|               ..|
|           . o. .|
|         o. E .o.|
|        S == o..o|
|         o +.  .o|
|        . o + o .|
|         . o =   |
|          .   .  |
+-----------------+
$ ssh-add ~/.ssh/id_deis
Identity added: /Users/admin/.ssh/id_deis (/Users/admin/.ssh/id_deis)
```

## Adding and Removing SSH Keys

By publishing the **public** half of your SSH key to Deis Workflow the component responsible for receiving `git push`
will be able to authenticate the user and ensure that they have access to the destination application.

```
$ deis keys:add ~/.ssh/id_deis.pub
Uploading id_deis.pub to deis... done
```

You can always view the keys associated with your user as well:

```
$ deis keys:list
=== admin Keys
admin@plinth-23437.local ssh-rsa AAAAB3Nz...3437.local
admin@subgenius.local ssh-rsa AAAAB3Nz...nius.local
```

Remove keys by their name:
```
$ deis keys:remove admin@plinth-23437.local
Removing admin@plinth-23437.local SSH Key... don
```

## Troubleshooting

### Allowing Keytypes
Latest version of openssh-client i.e 8.0 on Ubuntu Focal (20.04) and Fedora 32,33 are not accepting key types sent by severs running older version of openssh-server. This leads to autentication failure.

- Check your SSH version and follow the troubleshooting steps.
```bash
ssh -V
OpenSSH_8.4p1, OpenSSL 1.1.1i FIPS  8 Dec 2020
```

To Resolve this error:
Add the following to your user’s ssh config, or global ssh config at /etc/ssh/ssh_config

```bash
PubkeyAcceptedKeyTypes +rsa-sha2-256,rsa-sha2-512
```
### Generating New Keys with `ed25519` algorithm as Documented on [Github](https://docs.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

- Another workaroud is to generate a new key-pair using ed25519, this way you can still keep the id_rsa, and use it to connect to systems which don't support `ed25519` algorithm.

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```
- Adding to hephy

```bash
deis keys:add your_email@example.com ~/.ssh/id_ed25519.pub
```

# Doorbellian

Doorbellian is the internal name for the "Iris" smart doorbell product. Doorbellian is focused on creating a doorbell that provides real privacy to a user. User data ***never*** touches a cloud server, so there is no way to leak your private video, or for us to sell your data. The only server interaction occurs when sending out a mobile push notification to your mobile devices, and that contains no personal data, only initiating a connection between your mobile device and the doorbell. A technical explanation will be provided when that service is implemented. <ins>[TODO](#)</ins>

## Quickstart

```bash
git clone -b \<branch\> https://github.com/nucleus-labs/doorbellian-docker
cd doorbellian-docker

# ONLY IF YOU'RE USING NIX!! (the package manager or nixos)
./dhelper --ignore-deps env

# If you aren't using nix or otherwise have not run `nix develop`,
# this will tell you if you're missing any dependencies
./dhelper

# if not, proceed:
./dhelper init
./dhelper --mode tina build
./dhelper --mode tina extract "/artifacts/tina/out/;tina/"
```

## Users

## Developers

This repo makes use of a [dhelper](https://github.com/nucleus-labs/dhelper.template) script quite heavily. It is a developer tool that has sped up internal development immensely. For usage help, please use `./dhelper -h` or `./dhelper --help`.


### Common

## Internal

### TODO

- [ ] Push notification handshake, technical explanation

# Doorbellian

Doorbellian is the internal name for a product "Iris" smart doorbell product. Doorbellian is focused on creating a doorbell that provides real privacy to a user. User data ***never*** touches a cloud server, so there is no way to leak your private video, or for us to sell your data. The only server interaction occurs when sending out a mobile push notification to your mobile devices, and that contains no personal data, only initiating a connection between your mobile device and the doorbell. A technical explanation will be provided when that service is implemented. <ins>[TODO](#)</ins>


## Users

## Developers

This repo makes use of a `dhelper` script quite heavily. It is a developer tool that has sped up internal development immensely. For usage help, please use `./dhelper -h` or `./dhelper --help`.

dhelper operates on 2 levels: `common` and `target`. `common` functionality occurs prior to `target` functionality. `dhelper` assumes the presence of a directory `target/` and a provided target bash file `target/common.bash`, and this is how targets are defined. When you specify a target to use, `./arg_parse.bash`

### Common

## Internal

### TODO

- [ ] Push notification handshake, technical explanation

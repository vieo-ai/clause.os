# `.ssh` — Hermetic Identity & Key Management

> **Subsystem Role:** Cryptographic Key & SSH Profile Vault

The `.ssh` directory contains SSH keys, host fingerprints, and SSH daemon configurations specific to the ClauseOS profile environment.

---

## Directory Function

* **Profile Security Isolation:** Prevents ClauseOS from reading or using host system SSH keys stored in standard user locations (`~/.ssh` or `%USERPROFILE%\.ssh`).
* **Cloud & Git Authentication:** Houses dedicated SSH keys used for Git remote signing and cluster node access during cloud bursting workflows.

---

## Files

* `config`: Custom SSH client config forcing identity file targets to stay within `/clause/.ssh`.
* `known_hosts`: Profile-confined list of trusted remote host fingerprints.
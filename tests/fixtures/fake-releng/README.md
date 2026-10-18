# fake-releng test fixture

A tiny stand-in for `/usr/share/archiso/configs/releng` used by
`tests/test-prepare-profile.sh`. `profiledef.sh` mirrors upstream verbatim;
the package list is abbreviated. Upstream enablement symlinks
(`multi-user.target.wants/iwd.service` etc.) are created by the test at run
time because symlinks do not survive Windows checkouts.

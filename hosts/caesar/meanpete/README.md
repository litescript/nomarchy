# meanpete — the second-user envelope

`meanpete` is a Windows/WSL user who SSHes into caesar to rsync large files into
`~meanpete/incoming`, then runs `movie` or `tv` to stage them onto the NAS. Caesar is a
staging point that happens to have the NAS mounted; nothing in the homelab depends on it.

Audited in `docs/migration/06-post-install-audit.md` §11, rebuilt here on 2026-09-13.

**These files are deployed by copy, not symlink.** `/home/peter` is `drwx------`, so a
symlink from meanpete's home into this repo would dangle for him. That means the copies
drift silently — edit here, then reinstall.

**Lifecycle: this directory is temporary.** It exists so the envelope can be dropped onto
the final NVMe install in one step. Delete it after the cutover.

## What changed from the old box, and why

The old chain was:

```
meanpete runs  movie  ->  sudo /usr/local/bin/plex-movie  (root-owned, 0755)
plex-movie     does   ->  exec ~meanpete/Scripts/move-to-plex.sh "$TARGET"
move-to-plex.sh is    ->  -rwxr-xr-x  meanpete:media
```

A root-owned wrapper executing a script owned and writable by the invoking user, with a
sudo grant naming the wrapper. That is not "meanpete can stage files"; it is **meanpete
has root on caesar**, one compromised Windows box away from a NAS-mounted workstation.

None of it was necessary. The destinations are `drwxrwsr-x`, group `media` (gid 1004 on
both boxes and on the NAS itself), setgid. Verified against the live NAS before porting:

| operation the scripts perform | as a `media` member, unprivileged |
| --- | --- |
| `rsync` a file into `Movies` / `TV` | works, lands `664` group `media` |
| `install -d -m 2775` a Show/Season dir | works, setgid carries the group down |
| `rm` source files in `~/incoming` | his own files |
| `test -e` a destination path | world-readable |

So the port removes **every** `sudo` (six call sites) and drops the root side entirely:
no `/usr/local/bin/plex-movie`, no `plex-tv`, no sudoers grant. The ingest scripts are
otherwise byte-for-byte the originals — diff them against the old disk and the only
changes are those six lines plus comments. Faithful where it can be, changed only where
the old shape was the flaw.

## Install

```bash
sudo groupadd -g 1003 meanpete
sudo useradd -u 1001 -g 1003 -G media -m -s /bin/bash meanpete
sudo passwd meanpete

sudo install -d -o meanpete -g meanpete -m 0755 /home/meanpete/incoming
sudo install -d -o meanpete -g meanpete -m 0755 /home/meanpete/Scripts
sudo install -o meanpete -g meanpete -m 0755 Scripts/* /home/meanpete/Scripts/
sudo install -o meanpete -g meanpete -m 0644 bashrc      /home/meanpete/.bashrc
sudo install -o meanpete -g meanpete -m 0644 bash_profile /home/meanpete/.bash_profile
```

uid 1001 / gid 1003 match the old box's `/etc/passwd`, and `media` is 1004 in both places
and on the NAS content, so NFS's numeric AUTH_SYS ownership needs no translation.

Then the access policy, which is not optional — it is what makes a password-authenticated
remote account reasonable:

```bash
sudo install -m 0644 ../ssh/10-nomarchy.conf /etc/ssh/sshd_config.d/10-nomarchy.conf
sudo sshd -t && sudo systemctl reload sshd
sudo ../ufw/apply-rules
```

## Acceptance tests

1. `id meanpete` → `uid=1001 gid=1003(meanpete) groups=1003(meanpete),1004(media)`
2. As meanpete: `install -d -m 2775 "/mnt/nas/PlexMedia/TV/.probe"` then remove it. This is
   the one that proves the whole no-sudo design, and it tests the NFS server's view of his
   uid, not just the client's.
3. Effective sshd config, as root — this is what actually proves the Match block scopes
   correctly, rather than trusting the file to read the way it looks:

   ```bash
   sshd -T | grep -E 'passwordauthentication|authorizedkeysfile|subsystem'   # no, intact
   sshd -T -C user=meanpete,host=localhost,addr=127.0.0.1 | grep passwordauth  # yes
   ```
4. `ssh meanpete@localhost` → password prompt, accepted.
5. `ssh peter@localhost` → password refused (`Permission denied (publickey)`).
6. meanpete runs `movie` on a real file and it lands in `/mnt/nas/PlexMedia/Movies`.
7. `sudo -l -U meanpete` → no sudo entitlement at all.

## Known quirk, deliberately not fixed

Both ingest scripts do `set -euo pipefail` and then `rsync ...` followed by
`local rsync_exit=$?`. Under `set -e` a failing rsync exits immediately, so the error
branch never runs. Harmless — the script still stops before deleting anything — but the
"Source files NOT removed" message never prints. Left as-is: this port changes the
security shape and nothing else, so any behaviour change is attributable.

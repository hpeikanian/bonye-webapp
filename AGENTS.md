# bonYe! companion development

The user requires Android and web to evolve together. `lib/`, `assets/`, `test/`, `pubspec.yaml`, `pubspec.lock`, and `analysis_options.yaml` are snapshots of the canonical hpeikanian/bonyeapp source. Do not independently edit those files here. Make feature changes in bonyeapp, run its checks, then run `python3 tool/sync_source.py /workspace/bonyeapp` here and verify the web build. Web-only shell and deployment changes belong here. Preserve the independent repositories and folders.

Every feature change must be checked on both targets; platform exceptions must be explicit. Do not claim production deployment, iPhone Safari verification, or live checkout unless actually verified. Use existing checkouts; do not create worktrees unless explicitly requested. Never commit tokens or customer data.

### Bumping the version

While working on a release via `git flow release start X.X.X`, you should increment the version number. Simply `bump (major|minor|patch)` and you're done. Bump will increment the `VERSION` file, run `bundle`, and commit for you. Then you can `git flow release finish` whenever you're done.

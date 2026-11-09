# SA2-TD hosting repository contents

This directory is prepared to become the root of **yyvape-dev/SA2-TD**, a separate public test repository. Do not install this workflow into yyvape-dev/SA. Existing SA/main and its Pages source must stay unchanged.

The user approved creation and GitHub Pages publication. Creation attempt on 2026-11-09 JST failed with GitHub HTTP403 `Resource not accessible by integration`; the available integration cannot create repositories. No new repository, release or Pages site has yet been created.

After the owner creates SA2-TD and enables this GitHub connection for it:

1. Copy these files, including `.github/workflows/pages.yml`, into the new repository. Commit its README/landing/workflow only; do not commit the 103MiB PCK into Git.
2. Create release `web-903b0b9` in SA2-TD and upload verified `sa2-td-web-903b0b9.zip` (117458018 bytes; SHA256 `063e58453af76e3b9c26116dc19c2257db6ec81b189380d65edcc80d10315ffb`). This archive is the actual browser-verified build, not an engine rebuild.
3. Configure only SA2-TD Pages with REST `POST /repos/yyvape-dev/SA2-TD/pages`, JSON `{"build_type":"workflow"}`; then dispatch `pages.yml`. This operation is already user-authorized. Do not modify SA's Pages configuration.
4. Confirm deployment success, HTTP200 HTML/WASM/PCK and hashes, and actual browser T0/spot navigation from `https://yyvape-dev.github.io/SA2-TD/`. Until then that URL is a proposed address, not a live verified site.
5. Give the URL to the user for iPhone16/Safari testing, with device-record.md. No physical-device PASS before actual results.

Official references checked:
- https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages
- https://docs.github.com/en/rest/pages/pages#create-a-github-pages-site
- https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits

The site preparation script verifies archive size/SHA, CRC, source SHA, engine/clean state, and every Web resource hash. Deployment workflow is prepared but NOT TESTED on GitHub until the new repository is available. Public hosting is approved; a second approval is not required after the owner unblocks repository access.

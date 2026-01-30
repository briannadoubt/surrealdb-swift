# Documentation Deployment Setup

This repository automatically deploys documentation to GitHub Pages on every merge to `main`.

## First-Time Setup

To enable documentation deployment, configure GitHub Pages for this repository:

1. Go to **Settings** → **Pages**
2. Under **Source**, select **GitHub Actions**
3. Save the settings

That's it! The next merge to `main` will automatically deploy documentation.

## Accessing Documentation

Once deployed, documentation will be available at:
```
https://<username>.github.io/surrealdb-swift/documentation/surrealdb/
```

Replace `<username>` with the GitHub username or organization name.

## Manual Deployment

You can manually trigger a documentation deployment:

1. Go to **Actions** tab
2. Select **Deploy Documentation** workflow
3. Click **Run workflow**
4. Select `main` branch
5. Click **Run workflow**

## Local Documentation Preview

To preview documentation locally before deploying:

```bash
# Generate and preview documentation
swift package --disable-sandbox preview-documentation --target SurrealDB
```

This will start a local server (typically at http://localhost:8000) where you can browse the documentation.

## Troubleshooting

### Documentation not deploying

Check the Actions tab for workflow errors. Common issues:
- GitHub Pages not enabled (see First-Time Setup above)
- Repository visibility (must be public or have GitHub Pages enabled for private repos)
- Insufficient permissions (the workflow needs `contents: read` and `pages: write`)

### Build failures

If the documentation build fails:
1. Check the workflow logs in the Actions tab
2. Verify documentation builds locally: `swift package generate-documentation --target SurrealDB`
3. Fix any documentation warnings or errors in the source code

### Wrong base path

If links in the deployed documentation don't work:
1. Check the `--hosting-base-path` in `.github/workflows/docs.yml`
2. It should match your repository name
3. Update if needed and push to `main`

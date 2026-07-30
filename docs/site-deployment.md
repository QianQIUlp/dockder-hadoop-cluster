# Deploy the project site with Cloudflare Pages

The project site is a static bundle in `site/`. Cloudflare Pages can publish
that directory directly from the repository without installing a framework or
running a site generator.

## One-time Git connection

The first connection is an account-level operation. Repository files can make
the site deployable, but they cannot authorize Cloudflare to access GitHub or
create the Pages project on the owner's behalf. An account owner must complete
the following steps in the Cloudflare dashboard:

1. Open **Workers & Pages**, create a Pages application, and choose the Git
   integration.
2. Select GitHub, complete **Install & Authorize**, and grant Cloudflare access
   to `QianQIUlp/docker-hadoop-cluster`.
3. Select the repository and configure the deployment exactly as follows:

   | Setting | Value |
   | --- | --- |
   | Production branch | `main` |
   | Framework preset | `None` |
   | Root directory | Leave empty |
   | Build command | `exit 0` |
   | Build output directory | `site` |

4. Select **Save and Deploy**. After the first deployment finishes, keep the
   generated `*.pages.dev` URL as the baseline URL for deployment checks.

Cloudflare documents both the authorization flow and the deployment settings
in its [Pages Git integration guide][git-start]. Its [build configuration
reference][build-config] explains that an empty root means the repository root,
that the output directory is uploaded as the site, and that `exit 0` is the
no-framework build command.

Do not add Cloudflare account IDs, API tokens, or GitHub credentials to this
repository. The Git integration handles deployments after the one-time manual
authorization: pushes to `main` update production, while other enabled branches
produce preview deployments.

## Preview branches

Keep `main` as the production branch. For changes to the site, push a separate
branch and review the Cloudflare Pages preview before merging. Pages assigns a
unique hash URL to each preview deployment and also maintains a branch alias;
preview deployments do not replace the production `*.pages.dev` URL or its
custom domains. Pull requests from branches in this repository can also receive
preview URLs.

Preview branch inclusion and exclusion rules are available under the Pages
project's branch controls. Cloudflare's [preview deployments reference][preview]
describes preview URLs, aliases, access control, and the default search-engine
`noindex` response header.

## Custom domain

Deploy and verify the `*.pages.dev` address before attaching a custom domain.
Then open the Pages project, go to **Custom domains**, choose **Set up a domain**,
and follow the ownership and DNS prompts.

- For an apex domain, the domain must be a zone in the same Cloudflare account
  and use Cloudflare nameservers.
- For a subdomain, complete the Pages **Set up a domain** flow first. If DNS is
  hosted elsewhere, create the requested CNAME pointing to the project's
  `*.pages.dev` hostname only after Pages associates the domain.
- Do not create only a manual CNAME and skip the Pages association step;
  Cloudflare documents that this can produce a `522` response.

See Cloudflare's [Pages custom-domain guide][custom-domain] for the current DNS
requirements and dashboard workflow.

## Checks after each deployment

Set `SITE_URL` to the deployment under review, without a trailing slash. Run the
same checks first against the production `*.pages.dev` URL and then against the
custom domain, if one is configured:

```bash
SITE_URL=https://your-project.pages.dev

curl -fsS "$SITE_URL/" >/dev/null
curl -fsS "$SITE_URL/zh/" >/dev/null
curl -fsS "$SITE_URL/styles.css" >/dev/null
curl -fsS "$SITE_URL/site.js" >/dev/null
curl -fsS "$SITE_URL/site.webmanifest" >/dev/null
curl -fsS "$SITE_URL/robots.txt" >/dev/null
curl -fsSI "$SITE_URL/"
test "$(curl -sS -o /dev/null -w '%{http_code}' "$SITE_URL/this-page-must-not-exist")" = 404
```

Also verify in a browser that:

1. the English home page and `/zh/` Chinese page render without layout or
   console errors;
2. language switching, navigation, and GitHub repository links work;
3. favicon and manifest requests succeed and no mixed-content warning appears;
4. the response headers declared in `site/_headers` are present; and
5. an unknown path returns the custom `site/404.html` with HTTP status `404`,
   rather than falling back to the home page with status `200`; and
6. the Pages deployment details point to the expected `main` commit for
   production, or the expected feature-branch commit for a preview.

Cloudflare's [serving Pages reference][serving-pages] explains how `_headers`
affects responses. If a newly attached domain does not resolve immediately,
allow DNS propagation to complete and repeat the checks.

[git-start]: https://developers.cloudflare.com/pages/get-started/git-integration/
[build-config]: https://developers.cloudflare.com/pages/configuration/build-configuration/
[preview]: https://developers.cloudflare.com/pages/configuration/preview-deployments/
[custom-domain]: https://developers.cloudflare.com/pages/configuration/custom-domains/
[serving-pages]: https://developers.cloudflare.com/pages/configuration/serving-pages/

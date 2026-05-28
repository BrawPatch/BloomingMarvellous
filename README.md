# BloomingMarvellous

Mobile app to plan garden planting schedules.

## Repository layout

```
BloomingMarvellousApp/
├── App/                       SwiftUI demo entry point
├── Sources/                   iOS app sources (Config, Models, Services, Networking, ViewModels, UI)
├── Tests/                     XCTest / Swift Testing suites
├── Package.swift              SPM manifest (BloomingMarvellous + BloomingMarvellousUI libraries)
└── backend/                   AWS backend serving the app
    ├── DEPLOYMENT_GUIDE.md    step-by-step turn-up instructions
    ├── lambda/                Node.js Lambda (auth + content filtering)
    ├── scripts/               deploy.sh, seed-content.mjs, create-user.mjs
    └── infrastructure/terraform/
        ├── modules/api/       parameterised stack (S3, DynamoDB, Lambda, API GW, CloudFront, optional ACM/alias)
        └── environments/
            ├── dns/           singleton — Route 53 hosted zone for brawpatch.com
            ├── development/   dev stack (api-dev.brawpatch.com)
            └── production/    prod stack (api.brawpatch.com)
```

## Environments

Each environment is a fully isolated AWS stack — its own KMS key, DynamoDB
tables, S3 bucket, Lambda, API Gateway and CloudFront distribution.

| Env          | iOS build  | Base URL                          |
|--------------|------------|-----------------------------------|
| development  | DEBUG      | `https://api-dev.brawpatch.com/v1` |
| staging      | STAGING    | `https://api-staging.brawpatch.com/v1` (reserved) |
| production   | Release    | `https://api.brawpatch.com/v1`     |

Until the brawpatch.com nameservers have propagated from Route 53, the
custom domain stays off (`custom_domain_enabled = false`) and each env is
reachable on its `*.cloudfront.net` hostname.

## Tier and pack model

* Users are `tier ∈ {free, pro}`, with optional `purchasedPacks ⊆
  {pack_exotic, pack_edible}` — see `Sources/Models/UserModel.swift`.
* S3 content is tagged per-item with `access ∈ {free, pro, pack_exotic, pack_edible}`.
* The Lambda filters items server-side based on the caller's session.
* Login snapshots tier + packs into the session; mid-session purchases
  require a re-login.

See `backend/DEPLOYMENT_GUIDE.md` for the end-to-end deployment flow,
custom-domain turn-up, and per-env seeding instructions.

## Local development

Open `BloomingMarvellousiOS.xcodeproj` in Xcode and build the iOS target.
The DEBUG build points at the development backend via `AppConfig.swift`.
Override the base URL at runtime by setting `BM_API_BASE_URL` in the scheme's
environment variables (useful while DNS is still propagating).

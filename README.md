# urbanghosthunters

Swift Package Manager (SwiftPM) executable package.

## Requirements

- Swift **6.3+** (or an Xcode toolchain that includes Swift 6.3)

## Quick start

Build:

```bash
swift build
```

Run:

```bash
swift run urbanghosthunters
```

Test:

```bash
swift test
```

## CI / CD

- **CI**: GitHub Actions runs `swift build` + `swift test` on pushes and pull requests.
- **Release (CD)**: pushing a tag like `v0.1.0` runs tests and creates a GitHub Release.

Workflows live in `.github/workflows/`.

## DTAP branches (required)

This repo follows **DTAP** promotion via long-lived branches:

- **D (Development)**: `dev`
- **T (Test)**: `test`
- **A (Acceptance/UAT)**: `acceptance`
- **P (Production)**: `main`

Promotion happens by pull request only, in this order: `dev` → `test` → `acceptance` → `main`.

Full details: `docs/DTAP.md`.

## Contributing

- Create a feature branch from `dev`: `feat/<name>` or `fix/<name>`
- Open a PR back into `dev`
- Keep PRs small and ensure CI is green

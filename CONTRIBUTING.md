# Contributing to Claude Session Topics

## Development Setup

### Prerequisites

- Node.js 18+ and npm
- Bash 4.0+
- jq

### Install Dependencies

```bash
npm install

# Optional: development tools
brew install shellcheck bats-core  # macOS
```

### Set Up Git Hooks

```bash
git config core.hooksPath .githooks
```

## Running Tests

```bash
# All tests
./test.sh

# Individual suites
bats tests/integration/
npm test
npm run lint
```

## Release Process

Releases are automated via GitHub Actions when you push a tag:

```bash
npm version patch  # or minor, major
npm run version:sync
git add .
git commit -m "chore: bump version to x.x.x"
git tag v$(node -p "require('./package.json').version")
git push && git push --tags
```

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

# GitHub Actions

Sharable across all projects.


## Version

Verify that app was successfully deployed—compare the app version in health check response.

### Inputs

| Input      | Required | Description                       |
|------------|----------|-----------------------------------|
| `url`      | Yes      | Health check endpoint URL         |
| `expected` | Yes      | Expected app version to verify    |
| `username` | No       | Username for basic authentication |
| `password` | No       | Password for basic authentication |

### Usage

**Basic usage (no authentication)**

```yaml
  check_deploy:
    name: 'verify deployment'
    needs: [build_docker, deploy_azure]
    runs-on: ubuntu-latest
    timeout-minutes: 1

    steps:
      - name: '🤌 Checkout'
        uses: actions/checkout@v4

      - name: 'Verify app version'
        uses: softopus-io/actions/version@main
        with:
          expected: 1.0.0
          url: https://www.softopus.cz/health
```

**With basic authentication**

```yaml
  check_deploy:
    name: 'verify deployment'
    needs: [build_docker, deploy_azure]
    runs-on: ubuntu-latest
    timeout-minutes: 1

    steps:
      - name: '🤌 Checkout'
        uses: actions/checkout@v4

      - name: 'Verify app version'
        uses: softopus-io/actions/version@main
        with:
          expected: 1.0.0
          url: https://www.softopus.cz/health
          username: api-user
          password: ${{ secrets.HEALTH_CHECK_PASSWORD }}
```

### Expected Health Check Response

```json
{
  "appVersion": "1.0.0"
}
```
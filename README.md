# GitHub Actions

Sharable across all projects.


## Version

Verify that app was successfully deployed—compare the app version in health check response.

**Workflow**

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

**Health Check response**

```JSON
{
  "appVersion": "1.0.0"
}
```
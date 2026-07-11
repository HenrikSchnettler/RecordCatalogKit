# Contributing

Use Swift 6 concurrency-safe code and avoid adding dependencies without a clear
public-API or security justification. New endpoint work must include synthetic
request and response tests, public documentation, and an update to the endpoint
coverage table.

Before submitting changes, run:

```sh
swift build
swift test
```

Never commit Discogs credentials, real restricted user data, or long-lived API
response captures. Keep fixtures synthetic and minimal.

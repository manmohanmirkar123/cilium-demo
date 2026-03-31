# Contributing

Thanks for contributing to this Cilium demo repository.

## Local Workflow

1. Make your changes.
2. Run the demo validation:

```bash
./scripts/validate.sh
```

3. Update the README if the demo flow changes.
4. Add screenshots to `docs/screenshots/` when they improve the walkthrough.

## Suggested Contribution Areas

- Add more Cilium policy examples
- Add FQDN or egress policy demos
- Add L7 HTTP policy examples
- Improve observability screenshots and walkthroughs
- Add CI checks for manifest validation

## Notes

- Keep the demo simple and easy to reproduce.
- Prefer changes that work well for local demos and GitHub sharing.
- Avoid introducing unnecessary dependencies.

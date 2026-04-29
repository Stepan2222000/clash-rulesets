# clash-rulesets

Auto-converted [runetfreedom/russia-blocked-geosite](https://github.com/runetfreedom/russia-blocked-geosite) `ru-blocked.txt` into a Clash/Stash/mihomo rule-provider in YAML format.

A GitHub Action runs every 6 hours, downloads the upstream list, converts it, and commits the result back to this repo.

## Use as rule-provider

```yaml
rule-providers:
  ru-blocked:
    type: http
    behavior: domain
    format: yaml
    url: https://raw.githubusercontent.com/Stepan2222000/clash-rulesets/main/ru-blocked-domain-provider.yaml
    path: ./ruleset/ru-blocked-domain-provider.yaml
    interval: 21600

rules:
  - RULE-SET,ru-blocked,PROXY
  - MATCH,DIRECT
```

JSDelivr mirror (если raw тормозит):
`https://cdn.jsdelivr.net/gh/Stepan2222000/clash-rulesets@main/ru-blocked-domain-provider.yaml`

## Manual rebuild

```bash
./scripts/build.sh
```

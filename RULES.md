# Fraud Detection Rules

Rules are seeded during `make dev.setup` from `core-fraud-detection/rules/default_rules.yaml`. Each rule defines a condition evaluated against incoming transactions. Scores from triggered rules are summed to produce a final risk score.

## Rule Format

Rules are stored as structured YAML:

```yaml
- code: "AMT_001"
  name: "High Value Transaction"
  description: "Transaction exceeds R50,000"
  category: "amount"
  severity: "high"
  score: 60
  enabled: true
  conditions:
    field: "amount"
    operator: "greater_than"
    value: 50000
```

The Ops Portal accepts a shorthand syntax in the Logic Condition field:

```
amount greater_than 50000
```

This is converted to the structured format automatically.

## Default Rules

| Rule | Trigger Condition | Score |
|------|-------------------|------:|
| AMT_001 | amount > 50,000 | +60 |
| AMT_002 | amount > 100,000 | +80 |
| AMT_003 | amount is exactly 10,000 / 20,000 / 50,000 | +30 |
| GEO_001 | high-risk country (NG, GH, KE, RU, UA, BY) | +65 |
| GEO_002 | sanctioned country (IR, KP, SY, CU) | +95 |
| BEH_001 | gambling/crypto/adult merchant | +40 |
| BEH_002 | online channel + amount > 25,000 | +55 |
| DEV_001 | missing device fingerprint | +35 |
| COMB_001 | online + amount > 20,000 + foreign country | +70 |

## Decision Tiers

The fraud engine uses [pylitmus](https://pypi.org/project/pylitmus/) to evaluate rules and assign a decision based on the cumulative risk score. Thresholds are configured in `core-fraud-detection/app/core/fraud_detector.py` as `DecisionTier` objects and can be adjusted without changing application logic.

The defaults:

- **APPROVE** (0 -- 40) — Low risk. Transaction passes through.
- **REVIEW** (40 -- 80) — Medium risk. An alert is created for manual review.
- **FLAG** (80+) — High risk. An alert is created and auto-escalated for investigation.

# Kernel Check Report

**Status:** {{summary_status}} | Pass: {{summary_pass}} | Warn: {{summary_warn}} | Fail: {{summary_fail}}

| Field | Value |
|-------|-------|
| Kernel | {{kernel}} |
| Board | {{board}} |
| Profile | {{profile}} |
| Hostname | {{hostname}} |
| Time | {{timestamp}} |

## Checklist

{{checks_block}}

## Problems

{{problems_block}}

## Changes

{{diff_summary}}

## Check Details

{{checks_detail_block}}

## dmesg

<details>
<summary>dmesg excerpts</summary>

```
{{dmesg_block}}
```

</details>

## Diff

{{diff_detail_block}}

## Raw Data

Snapshot: `{{snapshot_path}}`

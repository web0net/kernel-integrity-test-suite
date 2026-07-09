<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Kernel Check Report (Developer)</title>
  <style>
    :root { color-scheme: light dark; }
    body { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; margin: 2rem; line-height: 1.5; max-width: 60rem; }
    h1 { font-family: system-ui, sans-serif; margin-top: 0; }
    .banner { padding: 1rem 1.25rem; border-radius: 8px; margin: 1rem 0 1.5rem; font-weight: 600; color: #fff; font-family: system-ui, sans-serif; }
    .banner.pass { background: #2e7d32; }
    .banner.warn { background: #ed6c02; }
    .banner.fail { background: #c62828; }
    table.meta { border-collapse: collapse; width: 100%; margin-bottom: 1.5rem; font-family: system-ui, sans-serif; }
    table.meta th, table.meta td { border: 1px solid #8884; padding: 0.5rem 0.75rem; text-align: left; }
    table.meta th { width: 8rem; background: #8882; }
    section { margin-bottom: 1.75rem; }
    h2 { font-family: system-ui, sans-serif; font-size: 1.15rem; border-bottom: 1px solid #8884; padding-bottom: 0.35rem; }
    pre { background: #8881; padding: 1rem; overflow-x: auto; border-radius: 6px; }
    details { margin: 0.5rem 0; font-family: system-ui, sans-serif; }
    details summary { cursor: pointer; font-weight: 600; }
    .status-pass { color: #2e7d32; }
    .status-warn { color: #ed6c02; }
    .status-fail { color: #c62828; }
    code.path { word-break: break-all; }
  </style>
</head>
<body>
  <h1>Kernel Check Report</h1>
  <div class="banner {{summary_status}}">
    Status: {{summary_status}} &mdash; Pass: {{summary_pass}} &mdash; Warn: {{summary_warn}} &mdash; Fail: {{summary_fail}}
  </div>
  <table class="meta">
    <tr><th>Kernel</th><td>{{kernel}}</td></tr>
    <tr><th>Board</th><td>{{board}}</td></tr>
    <tr><th>Profile</th><td>{{profile}}</td></tr>
    <tr><th>Hostname</th><td>{{hostname}}</td></tr>
    <tr><th>Time</th><td>{{timestamp}}</td></tr>
  </table>
  <section>
    <h2>Checklist</h2>
    {{checks_block}}
  </section>
  <section>
    <h2>Problems</h2>
    {{problems_block}}
  </section>
  <section>
    <h2>Changes</h2>
    <p>{{diff_summary}}</p>
  </section>
  <section>
    <h2>Check Details</h2>
    {{checks_detail_block}}
  </section>
  <section>
    <h2>dmesg</h2>
    <details>
      <summary>dmesg excerpts</summary>
      <pre>{{dmesg_block}}</pre>
    </details>
  </section>
  <section>
    <h2>Diff</h2>
    {{diff_detail_block}}
  </section>
  <section>
    <h2>Raw Data</h2>
    <p>Snapshot: <code class="path">{{snapshot_path}}</code></p>
  </section>
</body>
</html>

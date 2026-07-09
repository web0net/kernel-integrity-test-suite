<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Kernel Check Report</title>
  <style>
    :root { color-scheme: light dark; }
    body { font-family: system-ui, -apple-system, Segoe UI, sans-serif; margin: 2rem; line-height: 1.5; max-width: 52rem; }
    h1 { margin-top: 0; }
    .banner { padding: 1rem 1.25rem; border-radius: 8px; margin: 1rem 0 1.5rem; font-weight: 600; color: #fff; }
    .banner.pass { background: #2e7d32; }
    .banner.warn { background: #ed6c02; }
    .banner.fail { background: #c62828; }
    table.meta { border-collapse: collapse; width: 100%; margin-bottom: 1.5rem; }
    table.meta th, table.meta td { border: 1px solid #8884; padding: 0.5rem 0.75rem; text-align: left; }
    table.meta th { width: 8rem; background: #8882; }
    section { margin-bottom: 1.75rem; }
    h2 { font-size: 1.15rem; border-bottom: 1px solid #8884; padding-bottom: 0.35rem; }
    .status-pass { color: #2e7d32; }
    .status-warn { color: #ed6c02; }
    .status-fail { color: #c62828; }
    ul { padding-left: 1.25rem; }
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
</body>
</html>

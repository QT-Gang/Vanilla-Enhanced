#!/usr/bin/env bash

install -Dm644 /dev/stdin ./index.html <<'EOF'
<!doctype html>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="github-markdown.css">
<style>
    .markdown-body {
        box-sizing: border-box;
        min-width: 200px;
        max-width: 980px;
        margin: 0 auto;
        padding: 45px;
    }

    @media (max-width: 767px) {
        .markdown-body {
            padding: 15px;
        }
    }

    @media (prefers-color-scheme: dark) {
        body {
            background-color: #0d1117;
        }
    }
</style>
<article class="markdown-body">
EOF

curl -L \
  -X POST \
  -H "Accept: text/html" \
  -H "X-GitHub-Api-Version: 2026-03-10" \
  https://api.github.com/markdown \
  --variable "text@README.md" \
  --expand-data '{"text":"{{text:json}}", "mode": "gfm"}' \
  -sS >> ./index.html

echo -e '\n</article>' >> ./index.html

RAW_CONTENT_URL="https://raw.githubusercontent.com"
CSS_OWNER_REPO="sindresorhus/github-markdown-css"
curl -sS -o ./github-markdown.css \
  "$RAW_CONTENT_URL"/"$CSS_OWNER_REPO"/gh-pages/github-markdown.css

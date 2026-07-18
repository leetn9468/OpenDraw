#!/bin/sh
set -eu

app_dir="Sources/VectorFoundryApp"
failure=0

if rg -n 'NSColor\.|NSFont\.' "$app_dir" --glob '!Theme.swift'; then
    echo "UI theme violation: AppKit colors/fonts must be referenced through Theme."
    failure=1
fi

if rg -n '#[0-9A-Fa-f]{6}|(spacing|cornerRadius|lineWidth)\s*=\s*[0-9]|equalToConstant:\s*[0-9]' \
    "$app_dir/ShellViews.swift"; then
    echo "UI theme violation: shell color/metric literals must live in Theme."
    failure=1
fi

exit "$failure"

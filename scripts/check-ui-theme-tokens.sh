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

for token in \
    selectionBoundsLineWidth selectionHandleSize selectionHandleStrokeWidth \
    rotationRingSize rotationStemOffset anchorSize directionDotSize \
    directionStemWidth marqueeLineWidth marqueeDragThreshold snapGuideLineWidth \
    snapGuideCrossSpan badgeCornerRadius badgePointerOffset inlineTextOutlineWidth
do
    if ! rg -q "Theme\\.Metric\\.$token" "$app_dir/main.swift"; then
        echo "UI theme violation: canvas chrome does not reference Theme.Metric.$token."
        failure=1
    fi
done

if rg -n 'setLineWidth\((1|1\.5) / zoom\)|width: (4|5|6|7|8|10) / zoom|height: (4|5|6|7|8|10) / zoom' \
    "$app_dir/main.swift"; then
    echo "UI theme violation: canvas chrome metrics must be referenced through Theme."
    failure=1
fi

exit "$failure"

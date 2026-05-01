#!/bin/bash

# expect 1 argument: path to the notebook that must be exported
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <notebook_path>"
    exit 1
fi

NOTEBOOK_PATH="$1"

source .venv/bin/activate

# Export normally
jupyter nbconvert --to html --execute "$NOTEBOOK_PATH"

# Fix visited link color to purple
sed -i '/\.jp-RenderedHTMLCommon a:visited/,/}/ s/color: var(--jp-content-link-color);/color: var(--md-purple-900);/' "${NOTEBOOK_PATH%.ipynb}.html"
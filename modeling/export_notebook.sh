#!/bin/bash
source .venv/bin/activate

# Export normally
jupyter nbconvert --to html --execute notebooks/car_price_pca_analysis.ipynb

# Fix visited link color to purple
sed -i '/\.jp-RenderedHTMLCommon a:visited/,/}/ s/color: var(--jp-content-link-color);/color: var(--md-purple-900);/' notebooks/car_price_pca_analysis.html
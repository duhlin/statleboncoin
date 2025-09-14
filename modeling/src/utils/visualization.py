"""
Visualization utilities for car price analysis notebooks.
Contains formatters, display functions, and interactive table utilities.
"""

import pandas as pd
import itables
from itables import JavascriptFunction


# JavaScript formatters for interactive tables
pub_date_formatter = JavascriptFunction(
    """
    function (td, cellData, rowData, row, col) {
        if (cellData == 0) {
            $(td).html("Today").css('color', 'red').css('font-weight', 'bold');
        } else if (cellData == 1) {
            $(td).html("Yesterday").css('color', 'orange').css('font-weight', 'bold');
        } else if (cellData <= 7) {
            $(td).html(cellData + " d").css('color', 'orange').css('font-weight', 'bold');
        } else {
            $(td).html(cellData + " d");
        }
    }
    """
)
    
distance_formatter = JavascriptFunction(
    """
    function (td, cellData, rowData, row, col) {
        if (cellData > 500) {
            $(td).html(cellData + " km").css('color', 'red')
        } else if (cellData > 300) {
            $(td).html(cellData + " km").css('color', 'orange')
        } else if (cellData > 200) {
            $(td).html(cellData + " km").css('color', '#b8860b')
        } else {
            $(td).html(cellData + " km").css('color', 'green')
        }
    }
    """
)

thumb_url_formatter = JavascriptFunction(
    """
    function (td, cellData, rowData, row, col) {
        if (cellData) {
            $(td).html("<img src='" + cellData + "' style='margin: auto; display: block;'/>").css('min-width', '150px');
        } else {
            $(td).html("No Image");
        }
    }
    """
)

price_formatter = JavascriptFunction(
    """
    function (td, cellData, rowData, row, col) {
        $(td).html(cellData + " €");
    }
    """
)

percent_formatter = JavascriptFunction(
    """
    function (td, cellData, rowData, row, col) {
        $(td).html(cellData + ' %');
    }
    """
)

seats_formatter = JavascriptFunction(
    """
    function (td, cellData, rowData, row, col) {
        if (cellData == 999999) {
            $(td).html("7+");
        } else if (cellData == 'None') {
            $(td).html("-");
        } else {
            $(td).html(cellData);
        }
    }
    """
)

# add a link to Google Maps
city_formatter = JavascriptFunction(
    """
    function (td, cellData, rowData, row, col) {
        if (cellData) {
            var url = "https://www.google.com/maps/search/?api=1&query=" + encodeURIComponent(cellData);
            $(td).html("<a href='" + url + "' target='_blank'>" + cellData + "</a>");
        } else {
            $(td).html("Unknown");
        }
    }
    """
)

# Column mappings and formatters
COLUMN_ALIAS = {
    "predicted_price": "Pred. Price",
    "relative_difference": "Rel. Diff.",
    "first_publication_date": "Pub. Date",
    "price": "Price",
    "seats": "Seats",
    "distance": "Distance",
    "model": "Model",
    "mileage": "Mileage",
    "issuance_date": "Iss. Date",
    "subject": "Subject",
    "cluster": "Cluster",
    "rank_cluster": "Rank in Cluster",
    "rank": "Rank",
    "city": "City",
    "thumb_url": "Image",
}

FORMATTERS = {
    COLUMN_ALIAS["price"]: lambda x: x.astype(int),
    COLUMN_ALIAS["predicted_price"]: lambda x: x.astype(int),
    COLUMN_ALIAS["relative_difference"]: lambda x: (x*100).round(0).astype(int),
    COLUMN_ALIAS["mileage"]: lambda x: x.astype(int),
    COLUMN_ALIAS["first_publication_date"]: lambda x: (pd.to_datetime('today') - pd.to_datetime(x)).dt.days,
    COLUMN_ALIAS["seats"]: lambda x: x.fillna('0').astype(int),
    COLUMN_ALIAS["distance"]: lambda x: x.astype(int),
}


def show_cars(df, filters=None, order=None):
    """
    Display cars in an interactive table with formatting and filtering.
    
    Args:
        df: DataFrame containing car data
        filters: List of tuples (column, condition, value) for pre-filtering
        order: List of tuples (column, direction) for sorting
    """
    interesting_cars = df.copy()
    filters = filters or []
    order = order or []

    # Create HTML links for subjects (URLs)
    interesting_cars['subject'] = interesting_cars.apply(
        lambda row: f"<a target='_blank' href='{row['url']}'>{row['subject']}</a>", axis=1
    )
    
    # Select and rename columns
    columns = ['model', 'mileage', 'issuance_date', 'price', 'thumb_url', 'subject', 'city', 'seats', 
               'first_publication_date', 'distance', 'relative_difference', 
               'predicted_price', 'cluster', 'rank_cluster', 'rank']
    columns = [col for col in columns if col in interesting_cars.columns]
    rename = {col: COLUMN_ALIAS[col] for col in columns if col in COLUMN_ALIAS}
    format_funcs = {col: FORMATTERS[col] for col in rename.values() if col in FORMATTERS}
    
    interesting_cars = interesting_cars.rename(columns=rename)
    interesting_cars = interesting_cars[rename.values()]

    # Apply formatting
    for col, fmt in format_funcs.items():
        if col in interesting_cars.columns:
           interesting_cars[col] = fmt(interesting_cars[col])

    def column_id(name):
        return interesting_cars.columns.get_loc(name)+1

    # Configure interactive table
    column_defs = []
    for formatter_name, formatter in [
        ("Price", price_formatter),
        ("Pred. Price", price_formatter),
        ("Rel. Diff.", percent_formatter),
        ("Distance", distance_formatter),
        ("Pub. Date", pub_date_formatter),
        ("Seats", seats_formatter),
        ("Image", thumb_url_formatter),
        ("City", city_formatter),
    ]:
        if formatter_name in interesting_cars.columns:
            column_defs.append({
                "targets": [column_id(formatter_name)],
                "createdCell": formatter
            })

    itables.show(
        interesting_cars, 
        pageLength=25, 
        allow_html=True,
        columnDefs=column_defs,
        layout={"top1": "searchBuilder"},
        searchBuilder={
            "preDefined": {
                "criteria": [
                    {"data": column, "condition": condition, "value": [value]} 
                    for (column, condition, value) in filters
                ]
            }
        },
        order=[[column_id(col), dir] for (col, dir) in order],
        autoWidth=False,
    )

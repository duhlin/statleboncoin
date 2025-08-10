from typing import Any, Dict
import pandas as pd

def extract_features(data: pd.DataFrame) -> pd.DataFrame:
    """
    Extract and transform features from the input DataFrame.

    Parameters:
    - data: pd.DataFrame containing the raw data from the car_items table.

    Returns:
    - pd.DataFrame with the extracted features: model, age_in_days, and mileage.
    """
    # Ensure the necessary columns are present
    required_columns = ['model', 'issuance_date', 'mileage']
    if not all(col in data.columns for col in required_columns):
        raise ValueError(f"Input data must contain the following columns: {required_columns}")

    # Calculate age in days
    data['age_in_days'] = (pd.to_datetime('today') - pd.to_datetime(data['issuance_date'])).dt.days

    # Select relevant features
    features = data[['model', 'age_in_days', 'mileage']].copy()

    return features

def preprocess_data(data: pd.DataFrame) -> pd.DataFrame:
    """
    Preprocess the data for model training.

    Parameters:
    - data: pd.DataFrame containing the raw data.

    Returns:
    - pd.DataFrame ready for model training.
    """
    # Extract features
    features = extract_features(data)

    # Additional preprocessing steps can be added here

    return features
import pytest
from src.features.feature_engineering import extract_features

def test_extract_features():
    # Sample input data
    sample_data = [
        {'model': 'Model A', 'age_in_days': 30, 'mileage': 10000},
        {'model': 'Model B', 'age_in_days': 60, 'mileage': 20000},
        {'model': 'Model C', 'age_in_days': 90, 'mileage': 30000},
    ]
    
    # Expected output after feature extraction
    expected_output = [
        {'model': 'Model A', 'age_in_days': 30, 'mileage': 10000, 'feature_1': 1, 'feature_2': 0.1},
        {'model': 'Model B', 'age_in_days': 60, 'mileage': 20000, 'feature_1': 1, 'feature_2': 0.2},
        {'model': 'Model C', 'age_in_days': 90, 'mileage': 30000, 'feature_1': 1, 'feature_2': 0.3},
    ]
    
    # Call the function to test
    output = extract_features(sample_data)
    
    # Assert that the output matches the expected output
    assert output == expected_output

def test_extract_features_empty_input():
    # Test with empty input
    sample_data = []
    
    # Expected output should also be empty
    expected_output = []
    
    # Call the function to test
    output = extract_features(sample_data)
    
    # Assert that the output matches the expected output
    assert output == expected_output

def test_extract_features_invalid_data():
    # Test with invalid input data
    sample_data = [
        {'model': 'Model A', 'age_in_days': 'invalid', 'mileage': 10000},
    ]
    
    # Call the function to test and expect it to raise a ValueError
    with pytest.raises(ValueError):
        extract_features(sample_data)
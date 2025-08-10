import pytest
from src.data.database import get_car_items

def test_get_car_items():
    # Test the retrieval of car items from the DuckDB database
    car_items = get_car_items()
    assert isinstance(car_items, list), "Expected a list of car items"
    assert len(car_items) > 0, "Expected non-empty list of car items"
    assert all('model' in item for item in car_items), "Each item should have a 'model' key"
    assert all('age_in_days' in item for item in car_items), "Each item should have an 'age_in_days' key"
    assert all('mileage' in item for item in car_items), "Each item should have a 'mileage' key"
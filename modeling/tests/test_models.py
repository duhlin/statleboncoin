import pandas as pd
from src.models.gradient_boosting import GradientBoostingPerModel
def test_gradient_boosting_per_model_training_and_prediction():
    # Create mock data for two car models
    data = pd.DataFrame({
        'model': ['A', 'A', 'B', 'B'],
        'age_in_days': [100, 200, 150, 250],
        'mileage': [10000, 20000, 15000, 25000],
        'price': [5000, 4500, 6000, 5500]
    })

    gb_models = GradientBoostingPerModel()
    # Patch load_data to use mock data
    gb_models.load_data = lambda: data
    gb_models.train_all()

    # Test predictions for each car model
    pred_a = gb_models.predict('A', 120, 11000)
    pred_b = gb_models.predict('B', 160, 16000)
    assert isinstance(pred_a, float)
    assert isinstance(pred_b, float)
    # Ensure models exist for both car models
    assert 'A' in gb_models.models
    assert 'B' in gb_models.models
import pandas as pd
from src.models.gradient_boosting import GradientBoostingPerModel

def test_gradient_boosting_per_model_training_and_prediction():
    # Create mock data for two car models
    data = pd.DataFrame({
        'model': ['A', 'A', 'B', 'B'],
        'age_in_days': [100, 200, 150, 250],
        'mileage': [10000, 20000, 15000, 25000],
        'price': [5000, 4500, 6000, 5500]
    })

    gb_models = GradientBoostingPerModel()
    # Patch load_data to use mock data
    gb_models.load_data = lambda: data
    gb_models.train_all()

    # Test predictions for each car model
    pred_a = gb_models.predict('A', 120, 11000)
    pred_b = gb_models.predict('B', 160, 16000)
    assert isinstance(pred_a, float)
    assert isinstance(pred_b, float)
    # Ensure models exist for both car models

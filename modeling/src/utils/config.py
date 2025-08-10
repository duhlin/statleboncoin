# Configuration settings for the project

DATABASE_CONFIG = {
    'database': 'statleboncoin.duckdb',
    'table': 'car_items'
}

MODEL_HYPERPARAMETERS = {
    'n_estimators': 100,
    'learning_rate': 0.1,
    'max_depth': 3,
    'subsample': 0.9,
    'random_state': 42
}
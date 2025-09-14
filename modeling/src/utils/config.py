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

# Car analysis configuration
LUDOSPACE_MODELS = [
    'RENAULT_Kangoo', 
    'TOYOTA_PROACE CITY Verso', 
    'PEUGEOT_Rifter', 
    'CITROEN_Berlingo', 
    'OPEL_Combo', 
    'OPEL_Combo Life', 
    'FIAT_Doblo', 
    'MERCEDES-BENZ_EQT',
    'NISSAN_Townstar'
]

# URLs to ignore in analysis (outliers or problematic listings)
IGNORE_URLS = [
    'https://www.leboncoin.fr/ad/utilitaires/2881783262',
    'https://www.leboncoin.fr/ad/utilitaires/3037379996',
    'https://www.leboncoin.fr/ad/utilitaires/3032920162',
    'https://www.leboncoin.fr/ad/utilitaires/2986559704',
    'https://www.leboncoin.fr/ad/utilitaires/3029388180',
    'https://www.leboncoin.fr/ad/utilitaires/3033045893',
    'https://www.leboncoin.fr/ad/utilitaires/3041724626',
    'https://www.leboncoin.fr/ad/utilitaires/2959800932',
    'https://www.leboncoin.fr/ad/utilitaires/3046683749',
    'https://www.leboncoin.fr/ad/utilitaires/3041723386',
    'https://www.leboncoin.fr/ad/utilitaires/2879353914',
    'https://www.leboncoin.fr/ad/utilitaires/3042301395',
    'https://www.leboncoin.fr/ad/utilitaires/3012155472',
    'https://www.leboncoin.fr/ad/utilitaires/2422504570'
]

# Analysis parameters
ANALYSIS_CONFIG = {
    'max_distance': 1500,
    'ignore_horse_power': [47, 67],  # Small battery EVs
    'ignore_seats': [2, 3, 4],       # Focus on family cars
    'max_price': 35000,
    'min_price': 3000,
    'clustering_k': 8,
    'train_size': 0.6,
    'random_state': 42
}

# Default filters for car display
DEFAULT_FILTERS = {
    'max_distance': 500,
    'max_price': 28000,
    'min_seats': 5
}
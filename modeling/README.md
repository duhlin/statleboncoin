# Gradient Boosted Trees Regression for Car Models

This project implements a gradient boosted trees regression model using scikit-learn to predict car prices based on various features. The model is trained using data retrieved from a DuckDB database, specifically from the `car_items` table.

## Project Structure

```
modeling
├── src
│   ├── __init__.py
│   ├── main.py
│   ├── data
│   │   ├── __init__.py
│   │   └── database.py
│   ├── models
│   │   ├── __init__.py
│   │   ├── gradient_boosting.py
│   │   └── model_trainer.py
│   ├── features
│   │   ├── __init__.py
│   │   └── feature_engineering.py
│   └── utils
│       ├── __init__.py
│       └── config.py
├── tests
│   ├── __init__.py
│   ├── test_database.py
│   ├── test_models.py
│   └── test_features.py
├── notebooks
│   └── exploratory_analysis.ipynb
├── requirements.txt
├── setup.py
└── README.md
```

## Installation

To install the required dependencies, run:

```
pip install -r requirements.txt
```

## Usage

1. **Data Retrieval**: The data is retrieved from the DuckDB database using the functions defined in `src/data/database.py`.
2. **Feature Engineering**: Features are prepared for model training in `src/features/feature_engineering.py`.
3. **Model Training**: The gradient boosted trees model is implemented in `src/models/gradient_boosting.py` and trained using the `src/models/model_trainer.py`.
4. **Running the Application**: The entry point for the application is `src/main.py`, which orchestrates the data loading, model training, and evaluation processes.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue for any suggestions or improvements.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.
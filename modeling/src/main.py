import pandas as pd
from data.database import get_car_data
from models.model_trainer import ModelTrainer

def main():
    # Load data from DuckDB
    car_data = get_car_data()

    # Initialize the model trainer
    trainer = ModelTrainer()

    # Train models for each car model
    for model in car_data['model'].unique():
        model_data = car_data[car_data['model'] == model]
        trainer.train_model(model_data)

if __name__ == "__main__":
    main()
"""
Plotting utilities for car price analysis.
"""

import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np


def plot_data_distributions(df, figsize=(12, 6)):
    """
    Plot distributions of age, mileage, and price.
    
    Args:
        df: Dataset containing age_in_days, mileage, and price columns
        figsize: Figure size tuple
    """
    fig, axs = plt.subplots(3, 1, figsize=figsize)
    
    # Age distribution
    sns.histplot(df['age_in_days']/365.25, bins=30, ax=axs[0], kde=True, color='blue')
    axs[0].set_title('Distribution of Age (in years)')
    axs[0].set_xlabel('Age (in years)')
    axs[0].set_ylabel('Frequency')
    
    # Mileage distribution
    sns.histplot(df['mileage'], bins=30, ax=axs[1], kde=True, color='orange')
    axs[1].set_title('Distribution of Mileage')
    axs[1].set_xlabel('Mileage')
    axs[1].set_ylabel('Frequency')
    
    # Price distribution
    sns.histplot(df['price'], bins=30, ax=axs[2], kde=True, color='green')
    axs[2].set_title('Distribution of Price')
    axs[2].set_xlabel('Price')
    axs[2].set_ylabel('Frequency')
    
    plt.tight_layout()
    plt.show()


def plot_clustering_results(clustering_features, cluster_labels, cluster_centers, prices, figsize=(12, 6)):
    """
    Plot clustering results with age/mileage clusters and price coloring.
    
    Args:
        clustering_features: DataFrame with mileage and age_in_years
        cluster_labels: Cluster assignments
        cluster_centers: Cluster center coordinates
        prices: Price values for color mapping
        figsize: Figure size tuple
    """
    fig, axes = plt.subplots(1, 2, figsize=figsize)
    
    # Plot 1: Clusters colored by cluster ID
    scatter1 = axes[0].scatter(
        clustering_features['mileage'], clustering_features['age_in_years'], 
        c=cluster_labels, cmap='viridis', alpha=0.6
    )
    axes[0].scatter(
        cluster_centers[:, 0], cluster_centers[:, 1], 
        c='red', marker='X', s=200, label='Centroids'
    )
    axes[0].set_xlabel('Mileage (km)')
    axes[0].set_ylabel('Age (years)')
    axes[0].set_title('Clusters by Age and Mileage')
    axes[0].legend()
    axes[0].grid(True)
    
    # Plot 2: Same points colored by price
    scatter2 = axes[1].scatter(
        clustering_features['mileage'], clustering_features['age_in_years'], 
        c=prices, cmap='plasma', alpha=0.6
    )
    axes[1].set_xlabel('Mileage (km)')
    axes[1].set_ylabel('Age (years)')
    axes[1].set_title('Cars colored by Price')
    plt.colorbar(scatter2, ax=axes[1], label='Price (€)')
    axes[1].grid(True)
    
    plt.tight_layout()
    plt.show()


def plot_model_predictions_vs_actual(y_actual, predictions_dict, figsize=(12, 6)):
    """
    Plot predicted vs actual prices for multiple models.
    
    Args:
        y_actual: Actual price values
        predictions_dict: Dict mapping model names to predictions
        figsize: Figure size tuple
    """
    plt.figure(figsize=figsize)
    
    colors = ['blue', 'orange', 'green', 'purple', 'red']
    alphas = [0.4, 0.4, 0.6, 0.1, 0.8]
    
    for i, (model_name, predictions) in enumerate(predictions_dict.items()):
        color = colors[i % len(colors)]
        alpha = alphas[i % len(alphas)]
        plt.scatter(y_actual, predictions, label=model_name, alpha=alpha, color=color)
    
    # Perfect prediction line
    plt.plot([y_actual.min(), y_actual.max()], [y_actual.min(), y_actual.max()], 
             'r--', lw=2, label='Ideal Prediction')
    
    plt.xlabel('True Price')
    plt.ylabel('Predicted Price')
    plt.title('Model Predictions vs True Price')
    plt.legend()
    plt.grid()
    plt.show()


def plot_relative_error_histograms(X_test, y_test, models_dict, figsize=(12, 8)):
    """
    Plot histograms of relative errors for multiple models.
    
    Args:
        X_test: Test features
        y_test: Test targets
        models_dict: Dict mapping model names to trained models
        figsize: Figure size tuple
    """
    n_models = len(models_dict)
    fig, axs = plt.subplots(n_models, 1, figsize=figsize, sharex=True, sharey=True)
    
    if n_models == 1:
        axs = [axs]
    
    colors = ['blue', 'orange', 'green', 'purple']
    
    for i, (model_name, model) in enumerate(models_dict.items()):
        y_pred = model.predict(X_test)
        relative_error = (y_test - y_pred) / y_test
        
        axs[i].hist(relative_error, bins=30, alpha=0.7, color=colors[i % len(colors)])
        axs[i].set_ylabel('Frequency')
        axs[i].set_title(model_name)
        axs[i].grid(True)
    
    axs[-1].set_xlabel('Relative Error')
    fig.suptitle('Histogram of Relative Error for Each Model', fontsize=16)
    plt.tight_layout(rect=[0, 0, 1, 0.97])
    plt.show()

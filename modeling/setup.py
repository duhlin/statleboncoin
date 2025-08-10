from setuptools import setup, find_packages

setup(
    name='modeling',
    version='0.1.0',
    author='Your Name',
    author_email='your.email@example.com',
    description='A project for gradient boosted trees regression using scikit-learn with data from DuckDB.',
    packages=find_packages(where='src'),
    package_dir={'': 'src'},
    install_requires=[
        'scikit-learn',
        'duckdb',
        'pandas',
        'numpy'
    ],
    classifiers=[
        'Programming Language :: Python :: 3',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
    ],
    python_requires='>=3.6',
)
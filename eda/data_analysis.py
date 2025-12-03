"""
Exploratory Data Analysis (EDA) Module

This module demonstrates basic exploratory data analysis techniques
using Python's built-in libraries and the csv module.
"""

import csv
import os
from statistics import mean, median, stdev


def load_data(filename):
    """
    Load data from a CSV file and return it as a list of dictionaries.

    Args:
        filename: Path to the CSV file

    Returns:
        List of dictionaries where each dictionary represents a row
    """
    data = []
    with open(filename, 'r', newline='', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        for row in reader:
            data.append(row)
    return data


def get_column_values(data, column_name, convert_type=None):
    """
    Extract values from a specific column.

    Args:
        data: List of dictionaries
        column_name: Name of the column to extract
        convert_type: Optional function to convert values (e.g., int, float)

    Returns:
        List of values from the specified column
    """
    values = [row[column_name] for row in data]
    if convert_type:
        values = [convert_type(v) for v in values]
    return values


def calculate_basic_stats(values):
    """
    Calculate basic statistics for a list of numerical values.

    Args:
        values: List of numerical values

    Returns:
        Dictionary containing count, mean, median, min, max, and std_dev
    """
    return {
        'count': len(values),
        'mean': round(mean(values), 2),
        'median': round(median(values), 2),
        'min': min(values),
        'max': max(values),
        'std_dev': round(stdev(values), 2) if len(values) > 1 else 0
    }


def group_by_column(data, column_name):
    """
    Group data by a specific column value.

    Args:
        data: List of dictionaries
        column_name: Name of the column to group by

    Returns:
        Dictionary where keys are unique values and values are lists of rows
    """
    groups = {}
    for row in data:
        key = row[column_name]
        if key not in groups:
            groups[key] = []
        groups[key].append(row)
    return groups


def count_unique_values(data, column_name):
    """
    Count the frequency of each unique value in a column.

    Args:
        data: List of dictionaries
        column_name: Name of the column to analyze

    Returns:
        Dictionary with value counts
    """
    counts = {}
    for row in data:
        value = row[column_name]
        counts[value] = counts.get(value, 0) + 1
    return counts


def display_data_summary(data):
    """
    Display a summary of the dataset.

    Args:
        data: List of dictionaries
    """
    if not data:
        print("No data to summarize.")
        return

    print("=" * 50)
    print("DATA SUMMARY")
    print("=" * 50)
    print(f"Total Records: {len(data)}")
    print(f"Columns: {', '.join(data[0].keys())}")
    print(f"Number of Columns: {len(data[0].keys())}")
    print("=" * 50)


def display_column_stats(data, column_name, is_numeric=False):
    """
    Display statistics for a specific column.

    Args:
        data: List of dictionaries
        column_name: Name of the column to analyze
        is_numeric: Whether the column contains numeric values
    """
    print(f"\n--- Statistics for '{column_name}' ---")

    if is_numeric:
        values = get_column_values(data, column_name, float)
        stats = calculate_basic_stats(values)
        for stat_name, stat_value in stats.items():
            print(f"  {stat_name}: {stat_value}")
    else:
        counts = count_unique_values(data, column_name)
        print(f"  Unique values: {len(counts)}")
        for value, count in sorted(counts.items()):
            print(f"    {value}: {count}")


def create_histogram(values, bins=5, width=40):
    """
    Create a simple text-based histogram.

    Args:
        values: List of numerical values
        bins: Number of bins
        width: Maximum width of the histogram bars
    """
    if not values:
        print("No values to display.")
        return

    min_val = min(values)
    max_val = max(values)
    bin_width = (max_val - min_val) / bins

    # Count values in each bin
    bin_counts = [0] * bins
    for v in values:
        bin_index = min(int((v - min_val) / bin_width), bins - 1)
        bin_counts[bin_index] += 1

    max_count = max(bin_counts)

    print("\nHistogram:")
    for i in range(bins):
        lower = min_val + i * bin_width
        upper = lower + bin_width
        bar_length = int((bin_counts[i] / max_count) * width) if max_count > 0 else 0
        bar = "█" * bar_length
        print(f"  {lower:8.1f} - {upper:8.1f} | {bar} ({bin_counts[i]})")


def analyze_correlation(data, col1, col2):
    """
    Calculate the Pearson correlation coefficient between two numeric columns.

    Args:
        data: List of dictionaries
        col1: Name of the first column
        col2: Name of the second column

    Returns:
        Correlation coefficient
    """
    values1 = get_column_values(data, col1, float)
    values2 = get_column_values(data, col2, float)

    mean1 = mean(values1)
    mean2 = mean(values2)

    numerator = sum((v1 - mean1) * (v2 - mean2) for v1, v2 in zip(values1, values2))
    denom1 = sum((v1 - mean1) ** 2 for v1 in values1) ** 0.5
    denom2 = sum((v2 - mean2) ** 2 for v2 in values2) ** 0.5

    if denom1 == 0 or denom2 == 0:
        return 0

    return round(numerator / (denom1 * denom2), 4)


def main():
    """
    Main function demonstrating exploratory data analysis.
    """
    # Get the path to the sample data file
    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_file = os.path.join(script_dir, 'sample_data.csv')

    # Load the data
    print("Loading data from sample_data.csv...")
    data = load_data(data_file)

    # Display data summary
    display_data_summary(data)

    # Display first few rows
    print("\nFirst 5 records:")
    for i, row in enumerate(data[:5]):
        print(f"  {i+1}. {row}")

    # Analyze categorical column
    display_column_stats(data, 'department', is_numeric=False)

    # Analyze numeric columns
    display_column_stats(data, 'age', is_numeric=True)
    display_column_stats(data, 'salary', is_numeric=True)
    display_column_stats(data, 'years_experience', is_numeric=True)
    display_column_stats(data, 'performance_score', is_numeric=True)

    # Create histogram for salary
    print("\n" + "=" * 50)
    print("SALARY DISTRIBUTION")
    print("=" * 50)
    salaries = get_column_values(data, 'salary', float)
    create_histogram(salaries, bins=5)

    # Group analysis
    print("\n" + "=" * 50)
    print("ANALYSIS BY DEPARTMENT")
    print("=" * 50)
    groups = group_by_column(data, 'department')
    for dept, employees in groups.items():
        dept_salaries = get_column_values(employees, 'salary', float)
        stats = calculate_basic_stats(dept_salaries)
        print(f"\n{dept}:")
        print(f"  Employees: {stats['count']}")
        print(f"  Average Salary: ${stats['mean']:,.2f}")
        print(f"  Salary Range: ${stats['min']:,.2f} - ${stats['max']:,.2f}")

    # Correlation analysis
    print("\n" + "=" * 50)
    print("CORRELATION ANALYSIS")
    print("=" * 50)
    corr_exp_salary = analyze_correlation(data, 'years_experience', 'salary')
    corr_exp_perf = analyze_correlation(data, 'years_experience', 'performance_score')
    corr_salary_perf = analyze_correlation(data, 'salary', 'performance_score')

    print(f"Years Experience vs Salary: {corr_exp_salary}")
    print(f"Years Experience vs Performance: {corr_exp_perf}")
    print(f"Salary vs Performance: {corr_salary_perf}")

    print("\n" + "=" * 50)
    print("EDA Complete!")
    print("=" * 50)


if __name__ == "__main__":
    main()

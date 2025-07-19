import json
import numpy as np
import polars as pl
from scipy.optimize import nnls, lsq_linear
import boto3
from io import StringIO

def create_optimal_meals(event, context):
    """
    Lambda function that creates optimal meals based on user targets and products from S3

    Expected event structure:
    {
        "user": {
            "target_array": [tdee, protein_cal, lipid_g, glucides_g],
            "calculations": {...},
            "targets": {...}
        },
        "s3_config": {
            "bucket_name": "your-bucket-name",
            "file_key": "path/to/products.csv"
        },
        "solveur": "nnls" | "lsq" | "hybride" (optional, defaults to "nnls"),
        "meal_fraction": number (optional, defaults to 0.3 for 30% of daily targets),
        "sample_size": number (optional, for random sampling of products),
        "filter_options": {
            "exclude_snacks": true,
            "exclude_desserts": true,
            "exclude_drinks": true,
            "exclude_condiments": true,
            "exclude_complements": true
        }
    }

    Alternative: You can still pass products directly as before:
    {
        "user": {...},
        "products": [...],  // Direct product array
        ...
    }

    Returns:
    {
        "statusCode": 200,
        "body": {
            "plan": [...],
            "nutritional_check": {...},
            "solver_info": {...}
        }
    }
    """
    try:
        # Extract parameters from event
        user_data = event.get('user')
        products_data = event.get('products')
        s3_config = event.get('s3_config')
        solveur = event.get('solveur', 'nnls')
        meal_fraction = event.get('meal_fraction', 0.3)
        sample_size = event.get('sample_size')
        filter_options = event.get('filter_options', {
            'exclude_snacks': True,
            'exclude_desserts': True,
            'exclude_drinks': True,
            'exclude_condiments': True,
            'exclude_complements': True
        })

        # Validate required parameters
        if not user_data:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required parameter: user'})
            }

        if not products_data and not s3_config:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Must provide either products array or s3_config'})
            }

        # Validate user data structure
        if 'target_array' not in user_data:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'User data must contain target_array'})
            }

        # Validate solver
        valid_solvers = ['nnls', 'lsq', 'hybride']
        if solveur not in valid_solvers:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Invalid solver. Must be one of: {valid_solvers}'})
            }

        # Load products data
        if s3_config:
            # Load from S3
            bucket_name = s3_config.get('bucket_name')
            file_key = s3_config.get('file_key')

            if not bucket_name or not file_key:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'S3 config must include bucket_name and file_key'})
                }

            try:
                # Initialize S3 client
                s3_client = boto3.client('s3')

                # Download CSV file from S3
                response = s3_client.get_object(Bucket=bucket_name, Key=file_key)
                csv_content = response['Body'].read().decode('utf-8')

                # Read CSV with Polars
                products_df = pl.read_csv(StringIO(csv_content))

            except Exception as s3_error:
                return {
                    'statusCode': 500,
                    'body': json.dumps({'error': f'Failed to read from S3: {str(s3_error)}'})
                }
        else:
            # Load from direct products array
            products_df = pl.DataFrame(products_data)

        # Apply filters
        filter_conditions = []
        if filter_options.get('exclude_snacks', True):
            filter_conditions.append(pl.col("snacks") == False)
        if filter_options.get('exclude_desserts', True):
            filter_conditions.append(pl.col("desserts") == False)
        if filter_options.get('exclude_drinks', True):
            filter_conditions.append(pl.col("drinks") == False)
        if filter_options.get('exclude_condiments', True):
            filter_conditions.append(pl.col("condiments") == False)
        if filter_options.get('exclude_complements', True):
            filter_conditions.append(pl.col("complements") == False)

        # Apply all filters
        if filter_conditions:
            filtered_products = products_df.filter(pl.all_horizontal(filter_conditions))
        else:
            filtered_products = products_df

        # Sample products if requested
        if sample_size and sample_size < len(filtered_products):
            products = filtered_products.sample(sample_size)
        else:
            products = filtered_products

        if len(products) == 0:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'No products available after filtering'})
            }

        # Get targets from user data and apply meal fraction
        user_targets = np.array(user_data['target_array']) * meal_fraction

        # The user target array has 4 elements: [tdee, protein_cal, lipid_g, glucides_g]
        # We need to convert protein_cal to protein_g and add fiber target
        targets = np.array([
            user_targets[0],  # energy-kcal (tdee)
            user_targets[1] / 4,  # proteins in grams (protein_cal / 4)
            user_targets[2],  # fat in grams
            user_targets[3],  # carbohydrates in grams
            25 * meal_fraction  # fiber target (assume 25g daily, scaled by meal fraction)
        ])

        # Prepare nutrition matrix
        nutr_cols = ["energy-kcal", "proteins", "fat", "carbohydrates", "fiber"]

        # Check if all required nutrition columns exist
        missing_cols = [col for col in nutr_cols if col not in products.columns]
        if missing_cols:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Missing nutrition columns: {missing_cols}'})
            }

        # Create nutrition matrix (per 100g)
        arr = products.select(nutr_cols).to_numpy() / 100.0
        M = arr.T

        # Bounds for optimization
        lwr_bound = np.zeros(M.shape[1])
        higher_bound = products["portion_maximale"].to_numpy()

        # Solve optimization problem based on selected solver
        if solveur == "nnls":
            # NNLS: No portion max, might be too rich in one element
            x, residuals = nnls(M, targets)

            plan_data = {
                "product_name": products["product_name"].to_list(),
                "quantité_g": x.tolist()
            }

            obtained = M @ x
            solver_info = {
                "method": "nnls",
                "residuals": float(residuals) if residuals is not None else None,
                "products_used": int(np.sum(x > 1e-6))
            }

        elif solveur == "lsq":
            # LSQ_Linear: Uses all foods from database, doesn't make choices on products
            result = lsq_linear(
                M,
                targets,
                bounds=(lwr_bound, higher_bound),
                method="bvls",
            )
            x = result.x

            plan_data = {
                "product_name": products["product_name"].to_list(),
                "quantité_g": x.tolist()
            }

            obtained = M @ x
            solver_info = {
                "method": "lsq_linear",
                "success": result.success,
                "cost": float(result.cost),
                "products_used": int(np.sum(x > 1e-6))
            }

        elif solveur == "hybride":
            # Hybrid: First use NNLS to select products, then LSQ_Linear with bounds
            x_init, _ = nnls(M, targets)
            masque_x = x_init > 0

            if not np.any(masque_x):
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'No products selected by initial NNLS solver'})
                }

            indices_conserves = np.where(masque_x)[0]

            M_filtre = M[:, masque_x]
            products_filtre = products.filter(pl.Series(range(len(products))).is_in(indices_conserves))

            lwr_bound_filtre = np.zeros(M_filtre.shape[1])
            uppr_bound_filtre = products_filtre["portion_maximale"].to_numpy()

            result = lsq_linear(
                M_filtre,
                targets,
                bounds=(lwr_bound_filtre, uppr_bound_filtre),
                method="bvls",
            )
            x = result.x

            plan_data = {
                "product_name": products_filtre["product_name"].to_list(),
                "quantité_g": x.tolist()
            }

            obtained = M_filtre @ x
            solver_info = {
                "method": "hybride",
                "success": result.success,
                "cost": float(result.cost),
                "products_selected_nnls": int(np.sum(masque_x)),
                "products_used": int(np.sum(x > 1e-6))
            }

        # Create meal plan DataFrame and filter significant quantities
        plan_df = pl.DataFrame(plan_data).filter(pl.col("quantité_g") > 1e-6).sort("quantité_g", descending=True)

        # Convert to list of dictionaries for JSON response
        meal_plan = plan_df.to_dicts()

        # Create nutritional check
        nutritional_check = {
            "nutriments": ["energy-kcal", "proteins", "fat", "carbohydrates", "fiber"],
            "obtained": obtained.tolist(),
            "targets": targets.tolist(),
            "achievement_percentage": (obtained / targets * 100).tolist() if not np.any(targets == 0) else None
        }

        # Add detailed nutritional comparison
        nutritional_comparison = []
        nutrient_names = ["energy-kcal", "proteins", "fat", "carbohydrates", "fiber"]
        for i, nutrient in enumerate(nutrient_names):
            nutritional_comparison.append({
                "nutrient": nutrient,
                "obtained": float(obtained[i]),
                "target": float(targets[i]),
                "difference": float(obtained[i] - targets[i]),
                "achievement_pct": float(obtained[i] / targets[i] * 100) if targets[i] != 0 else None
            })

        response_data = {
            "meal_plan": meal_plan,
            "nutritional_check": nutritional_check,
            "nutritional_comparison": nutritional_comparison,
            "solver_info": solver_info,
            "meal_fraction": meal_fraction,
            "total_products_available": len(products),
            "products_in_plan": len(meal_plan),
            "data_source": "s3" if s3_config else "direct"
        }

        return {
            'statusCode': 200,
            'body': json.dumps(response_data)
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

# Example usage and testing
def test_meal_optimizer():
    """Test function to demonstrate usage with local file"""

    # Sample user data (from previous computeTargets function)
    user_data = {
        "target_array": [2000, 480, 60, 225],  # [tdee, protein_cal, lipid_g, glucides_g]
        "calculations": {
            "tdee": 2000,
            "bmr": 1600
        },
        "targets": {
            "protein_g": 120,
            "protein_cal": 480,
            "lipid_g": 60,
            "lipid_cal": 540,
            "glucides_g": 225,
            "glucides_cal": 900
        }
    }

    # Read the CSV file from local directory
    try:
        file_path = "/home/torel/IdeaProjects/NutriaIngestionAndSolver/data_prep/data/products_names_with_macro_nutriments(in).csv"
        print(f"Reading CSV file from: {file_path}")

        # Try different CSV reading strategies
        products_df = None

        # Try different CSV reading strategies
        products_df = None

        # Strategy 1: Use pandas with maximum error tolerance
        try:
            import pandas as pd
            print("Trying pandas with error handling...")

            df_pandas = pd.read_csv(
                file_path,
                sep=',',
                quotechar='"',
                on_bad_lines='skip',  # Skip problematic lines
                dtype={'code': str},
                low_memory=False,
                encoding='utf-8',
                engine='python'  # More tolerant parser
            )

            # Convert pandas to polars without pyarrow
            products_df = pl.DataFrame(df_pandas.to_dict('list'))
            print("✓ Successfully read CSV with pandas + manual conversion")

        except Exception as e1:
            print(f"Strategy 1 (pandas) failed: {e1}")

            # Strategy 2: Manual CSV processing for very problematic files
            try:
                print("Trying manual CSV processing...")
                import csv

                rows = []
                headers = None

                with open(file_path, 'r', encoding='utf-8') as f:
                    # Try to read line by line and handle errors
                    for line_num, line in enumerate(f):
                        try:
                            # Skip lines that look problematic
                            if '";;;;;' in line or line.count('"') % 2 != 0:
                                print(f"Skipping problematic line {line_num}")
                                continue

                            # Use csv module for proper parsing
                            reader = csv.reader([line.strip()])
                            row = next(reader)

                            if headers is None:
                                headers = row
                                print(f"Headers found: {headers}")
                            else:
                                if len(row) == len(headers):  # Only keep rows with correct column count
                                    rows.append(row)

                        except Exception as line_error:
                            print(f"Skipping line {line_num} due to error: {line_error}")
                            continue

                        # Limit rows for testing
                        if len(rows) >= 5000:
                            print("Limiting to first 5000 valid rows for testing")
                            break

                if headers and rows:
                    # Create dictionary for polars
                    data_dict = {header: [] for header in headers}
                    for row in rows:
                        for i, value in enumerate(row):
                            if i < len(headers):
                                data_dict[headers[i]].append(value)

                    products_df = pl.DataFrame(data_dict)
                    print(f"✓ Successfully read {len(rows)} rows with manual parsing")
                else:
                    raise Exception("No valid data found")

            except Exception as e2:
                print(f"Strategy 2 (manual) failed: {e2}")

                # Strategy 3: Create sample data for testing
                try:
                    print("Creating sample data for testing...")
                    sample_data = {
                        "code": ["001", "002", "003", "004", "005"],
                        "product_name": ["Chicken Breast", "Brown Rice", "Olive Oil", "Salmon", "Broccoli"],
                        "energy-kcal": [165, 111, 884, 208, 34],
                        "proteins": [31.0, 2.6, 0.0, 25.4, 2.8],
                        "fat": [3.6, 0.9, 100.0, 12.4, 0.4],
                        "carbohydrates": [0.0, 23.0, 0.0, 0.0, 7.0],
                        "fiber": [0.0, 1.8, 0.0, 0.0, 2.6],
                        "portion_maximale": [200, 150, 30, 150, 200],
                        "snacks": [False, False, False, False, False],
                        "desserts": [False, False, False, False, False],
                        "drinks": [False, False, False, False, False],
                        "condiments": [False, False, False, False, False],
                        "complements": [False, False, False, False, False]
                    }
                    products_df = pl.DataFrame(sample_data)
                    print("✓ Using sample data for testing")

                except Exception as e3:
                    print(f"Strategy 3 (sample) failed: {e3}")
                    raise Exception("All CSV reading strategies failed")

        if products_df is None:
            raise Exception("Failed to read CSV file")

        print(f"Loaded {len(products_df)} products from CSV")
        print("Columns:", products_df.columns)

        # Clean up the malformed column name
        if 'portion_maximale;;;;;' in products_df.columns:
            products_df = products_df.rename({'portion_maximale;;;;;': 'portion_maximale_raw'})
            print("Cleaned malformed column name")

        # Check if required columns exist
        required_cols = ["product_name", "energy-kcal", "proteins", "fat", "carbohydrates", "portion_maximale"]
        missing_cols = [col for col in required_cols if col not in products_df.columns]

        if missing_cols:
            print(f"Missing required columns: {missing_cols}")
            print("Available columns:", list(products_df.columns))

            # Try to map common column name variations
            column_mapping = {
                "product_name": ["name", "product", "nom_produit", "nom"],
                "energy-kcal": ["energy", "calories", "kcal", "energie"],
                "proteins": ["protein", "proteines", "proteine"],
                "fat": ["lipids", "lipides", "graisses", "matières grasses"],
                "carbohydrates": ["carbs", "glucides", "carbohydrate"],
                "portion_maximale": ["portion_max", "max_portion", "portion", "portion_maximale_raw"]
            }

            for required, alternatives in column_mapping.items():
                if required not in products_df.columns:
                    for alt in alternatives:
                        if alt in products_df.columns:
                            products_df = products_df.rename({alt: required})
                            print(f"Mapped column '{alt}' to '{required}'")
                            break

        # Convert numeric columns to proper types and handle errors
        numeric_columns = ["energy-kcal", "proteins", "fat", "carbohydrates", "fiber"]

        for col in numeric_columns:
            if col in products_df.columns:
                try:
                    # Clean the data: remove non-numeric characters and convert
                    products_df = products_df.with_columns(
                        pl.col(col)
                        .str.replace_all(r"[^\d.,\-]", "")  # Keep only digits, dots, commas, minus
                        .str.replace(",", ".")  # Replace comma with dot for decimal
                        .str.replace_all(r"\.+", ".")  # Remove multiple dots
                        .str.strip_chars()  # Remove whitespace
                        .map_elements(lambda x: float(x) if x and x not in ['', 'null', 'NULL', 'na', 'NA'] else 0.0, return_dtype=pl.Float64)
                        .alias(col)
                    )
                    print(f"✓ Converted {col} to numeric")
                except Exception as e:
                    print(f"Warning: Could not convert {col} to numeric: {e}")
                    # Set default values if conversion fails
                    products_df = products_df.with_columns(pl.lit(0.0).alias(col))

        # Handle portion_maximale specially (might have semicolons)
        if "portion_maximale" in products_df.columns:
            try:
                products_df = products_df.with_columns(
                    pl.col("portion_maximale")
                    .str.replace_all(r"[^\d.,\-]", "")  # Remove non-numeric including semicolons
                    .str.replace(",", ".")
                    .str.strip_chars()
                    .map_elements(lambda x: float(x) if x and x not in ['', 'null', 'NULL', 'na', 'NA'] else 150.0, return_dtype=pl.Float64)
                    .alias("portion_maximale")
                )
                print("✓ Converted portion_maximale to numeric")
            except Exception as e:
                print(f"Warning: Could not convert portion_maximale: {e}")
                products_df = products_df.with_columns(pl.lit(150.0).alias("portion_maximale"))

        # Convert boolean columns
        boolean_columns = ["snacks", "desserts", "drinks", "condiments", "complements"]
        for col in boolean_columns:
            if col in products_df.columns:
                try:
                    products_df = products_df.with_columns(
                        pl.col(col)
                        .str.to_lowercase()
                        .map_elements(lambda x: x == "true" if x in ["true", "false"] else False, return_dtype=pl.Boolean)
                        .alias(col)
                    )
                    print(f"✓ Converted {col} to boolean")
                except Exception as e:
                    print(f"Warning: Could not convert {col} to boolean: {e}")
                    products_df = products_df.with_columns(pl.lit(False).alias(col))

        # Add missing columns with default values if they don't exist
        if "fiber" not in products_df.columns:
            products_df = products_df.with_columns(pl.lit(2.0).alias("fiber"))  # Default fiber
            print("Added default fiber column")

        # Add boolean filter columns if they don't exist
        for col in boolean_columns:
            if col not in products_df.columns:
                products_df = products_df.with_columns(pl.lit(False).alias(col))
                print(f"Added default {col} column")

        if "portion_maximale" not in products_df.columns:
            products_df = products_df.with_columns(pl.lit(150.0).alias("portion_maximale"))
            print("Added default portion_maximale column")

        # Filter out rows with invalid nutrition data
        products_df = products_df.filter(
            (pl.col("energy-kcal") > 0) &
            (pl.col("proteins") >= 0) &
            (pl.col("fat") >= 0) &
            (pl.col("carbohydrates") >= 0)
        )

        print(f"After cleaning: {len(products_df)} valid products")
        print("First few rows after cleaning:")
        print(products_df.head())

        # Convert to list of dictionaries for the test
        products_data = products_df.to_dicts()

        test_event = {
            "user": user_data,
            "products": products_data,
            "solveur": "hybride",
            "meal_fraction": 0.3,
            "sample_size": 1000  # Sample 1000 products for testing
        }

        result = create_optimal_meals(test_event, None)
        print("\nMeal Optimizer Result:")
        print(json.dumps(json.loads(result['body']), indent=2))

        return result

    except FileNotFoundError:
        print(f"File not found: {file_path}")
        print("Please check the file path and try again")
        return None
    except Exception as e:
        print(f"Error reading CSV file: {str(e)}")
        return None

# Uncomment to test locally with your CSV file
if __name__ == "__main__":
    test_meal_optimizer()
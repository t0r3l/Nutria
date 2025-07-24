from flask import Flask, request, jsonify
import json
import os
import sys
import numpy as np
import polars as pl
from scipy.optimize import nnls, lsq_linear
import boto3
from io import StringIO
import logging
import traceback

# Configure logging to stdout (required for CloudWatch)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Environment detection
IS_LOCAL = os.environ.get('ENVIRONMENT', 'local').lower() in ['local', 'dev', 'development']
LOCAL_CSV_PATH = os.environ.get('LOCAL_CSV_PATH', '/home/torel/IdeaProjects/NutriaIngestionAndSolver/data_prep/data/products_names_with_macro_nutriments(in).csv')

# Log startup
logger.info("🚀 Starting Nutria Meal Optimizer...")
logger.info(f"Environment: {os.environ.get('ENVIRONMENT', 'local')}")
logger.info(f"Running mode: {'LOCAL' if IS_LOCAL else 'AWS'}")
if IS_LOCAL:
    logger.info(f"Local CSV Path: {LOCAL_CSV_PATH}")
else:
    logger.info(f"S3 Bucket: {os.environ.get('S3_BUCKET_NAME', 'unknown')}")
    logger.info(f"CSV File Key: {os.environ.get('CSV_FILE_KEY', 'unknown')}")


def load_data_hybrid():
    """Load data from local file or S3 based on environment"""
    try:
        if IS_LOCAL:
            # Load from local file
            if os.path.exists(LOCAL_CSV_PATH):
                logger.info(f"Loading data from local file: {LOCAL_CSV_PATH}")
                products_df = pl.read_csv(
                    LOCAL_CSV_PATH,
                    ignore_errors=True,
                    separator=",",
                    truncate_ragged_lines=True
                )
                return products_df
            else:
                raise FileNotFoundError(f"Local CSV file not found: {LOCAL_CSV_PATH}")
        else:
            # Load from S3
            bucket_name = os.environ.get('S3_BUCKET_NAME')
            file_key = os.environ.get('CSV_FILE_KEY')
            
            if not bucket_name or not file_key:
                raise ValueError("S3 configuration missing (S3_BUCKET_NAME or CSV_FILE_KEY)")
            
            logger.info(f"Loading data from S3: s3://{bucket_name}/{file_key}")
            s3_client = boto3.client('s3')
            response = s3_client.get_object(Bucket=bucket_name, Key=file_key)
            csv_content = response['Body'].read().decode('utf-8')
            
            products_df = pl.read_csv(
                StringIO(csv_content),
                ignore_errors=True,
                separator=",",
                truncate_ragged_lines=True
            )
            return products_df
            
    except Exception as e:
        logger.error(f"Error loading data: {str(e)}")
        raise


def create_optimal_meals_hybrid(user_targets, products_df, solveur="hybride", meal_fraction=0.3, portion_legumes=100):
    """Hybrid meal optimization method"""
    try:
        logger.info(f"Starting optimization with solver: {solveur}")

        # Apply meal fraction to targets
        targets = np.array(user_targets) * meal_fraction
        targets = np.append(targets[:4], 25 * meal_fraction)

        # Add portion_legumes to targets only if > 0
        include_legumes = portion_legumes > 0.0
        if include_legumes:
            targets = np.concatenate((targets, [portion_legumes]))

        logger.info(f"Optimization targets: {targets}")

        # Prepare nutrition matrix
        nutr_cols = ["energy-kcal", "proteins", "fat", "carbohydrates", "fiber"]
        if include_legumes:
            nutr_cols.append("portion_legumes")

        # Handle missing columns
        missing_cols = [col for col in nutr_cols if col not in products_df.columns]
        if missing_cols:
            logger.warning(f"Missing columns: {missing_cols}, using zeros")
            for col in missing_cols:
                products_df = products_df.with_columns(pl.lit(0.0).alias(col))

        # Add portion_maximale if missing
        if "portion_maximale" not in products_df.columns:
            logger.info("Adding default portion_maximale (200g)")
            products_df = products_df.with_columns(pl.lit(200.0).alias("portion_maximale"))

        # Clean data: replace NaN/inf values with 0 and ensure all values are finite
        for col in nutr_cols:
            products_df = products_df.with_columns(
                pl.when(pl.col(col).is_null() | pl.col(col).is_nan() | pl.col(col).is_infinite())
                .then(0.0)
                .otherwise(pl.col(col))
                .alias(col)
            )

        # Clean portion_maximale
        products_df = products_df.with_columns(
            pl.when(pl.col("portion_maximale").is_null() | 
                    pl.col("portion_maximale").is_nan() | 
                    pl.col("portion_maximale").is_infinite() |
                    (pl.col("portion_maximale") <= 0))
            .then(200.0)
            .otherwise(pl.col("portion_maximale"))
            .alias("portion_maximale")
        )

        # Sample products for performance
        n_products = len(products_df)
        sample_size = min(1000, n_products)

        if n_products > sample_size:
            logger.info(f"Sampling {sample_size} products from {n_products}")
            sampled_indices = np.random.choice(n_products, sample_size, replace=False)
            products_sample = products_df[sampled_indices]
        else:
            products_sample = products_df

        logger.info(f"Working with {len(products_sample)} products")

        # Create nutrition matrix
        A = products_sample[nutr_cols].to_numpy().T
        
        # Ensure A has correct shape
        logger.info(f"Nutrition matrix shape: {A.shape}")
        
        # Get bounds
        portion_max = products_sample["portion_maximale"].to_numpy()
        portion_max = np.where(np.isfinite(portion_max) & (portion_max > 0), portion_max, 200.0)

        # Solve optimization problem
        if solveur == "nnls":
            # Non-negative least squares
            x, residual = nnls(A, targets, maxiter=5000)
            x = np.minimum(x, portion_max)
        else:
            # Linear least squares with bounds
            result = lsq_linear(A, targets, bounds=(0, portion_max), max_iter=1000)
            x = result.x

        # Filter non-zero results
        threshold = 0.01
        selected = x > threshold

        if not np.any(selected):
            logger.warning("No products selected, returning empty result")
            return []

        # Get selected products with quantities
        selected_products = products_sample.filter(selected)
        selected_quantities = x[selected]

        # Calculate obtained values
        obtained = A[:, selected] @ selected_quantities

        logger.info(f"Optimization complete: {len(selected_products)} products selected")
        logger.info(f"Target vs Obtained: {targets} vs {obtained}")

        # Prepare results
        results = []
        for i, row in enumerate(selected_products.iter_rows(named=True)):
            results.append({
                'product_name': row.get('product_name', 'Unknown'),
                'quantité_g': float(selected_quantities[i])
            })

        # Sort by quantity descending
        results.sort(key=lambda x: x['quantité_g'], reverse=True)

        return results

    except Exception as e:
        logger.error(f"Optimization error: {str(e)}")
        logger.error(traceback.format_exc())
        raise


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        logger.info("Health check requested")

        # Basic health info
        health_info = {
            'status': 'healthy',
            'service': 'nutria-meal-optimizer',
            'version': '2.0.0',
            'environment': os.environ.get('ENVIRONMENT', 'local'),
            'deployment': 'local' if IS_LOCAL else 'fargate',
            'data_source': 'local_file' if IS_LOCAL else 's3'
        }

        # Test data connectivity
        try:
            if IS_LOCAL:
                if os.path.exists(LOCAL_CSV_PATH):
                    health_info['data_connectivity'] = 'ok'
                    health_info['local_file'] = os.path.basename(LOCAL_CSV_PATH)
                else:
                    health_info['data_connectivity'] = 'file_not_found'
            else:
                bucket_name = os.environ.get('S3_BUCKET_NAME')
                if bucket_name:
                    s3_client = boto3.client('s3')
                    s3_client.head_bucket(Bucket=bucket_name)
                    health_info['s3_connectivity'] = 'ok'
                else:
                    health_info['s3_connectivity'] = 'no_bucket_configured'
        except Exception as e:
            health_info['connectivity_error'] = str(e)

        return jsonify(health_info), 200

    except Exception as e:
        logger.error(f"Health check error: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/optimize', methods=['POST'])
def optimize_meal():
    """Enhanced meal optimization endpoint"""
    try:
        logger.info("Optimization request received")

        # Parse request
        data = request.get_json()
        if not data:
            logger.error("No JSON data in request")
            return jsonify({'error': 'No JSON data provided'}), 400

        user_data = data.get('user')
        meal_fraction = data.get('meal_fraction', 0.3)
        solveur = data.get('solveur', 'hybride')
        sample_size = data.get('sample_size', 1000)
        portion_legumes = data.get('portion_legumes', 100)

        logger.info(f"Request params: fraction={meal_fraction}, solver={solveur}, sample={sample_size}, portion_legumes={portion_legumes}")

        if not user_data or 'target_array' not in user_data:
            logger.error("Missing user data or target_array")
            return jsonify({'error': 'Missing user data with target_array'}), 400

        user_targets = user_data['target_array']
        if len(user_targets) < 4:
            return jsonify({'error': 'target_array must have at least 4 values'}), 400

        # Load data using hybrid method
        products_df = load_data_hybrid()
        logger.info(f"Loaded {len(products_df)} products from {('local file' if IS_LOCAL else 'S3')}")

        # Run optimization
        results = create_optimal_meals_hybrid(
            user_targets, 
            products_df,
            solveur=solveur,
            meal_fraction=meal_fraction,
            portion_legumes=portion_legumes
        )

        # Prepare response
        response = {
            'meal_plan': results[:10],  # Top 10 products
            'products_used': len(results),
            'solver': solveur,
            'deployment_info': {
                'type': 'local' if IS_LOCAL else 'fargate',
                'optimization_method': 'hybrid',
                'logs_enabled': True,
                'data_source': 'local_file' if IS_LOCAL else 's3'
            }
        }

        # Add verification if we have results
        if results:
            # Calculate obtained values for verification
            selected_products = [r['product_name'] for r in results[:10]]
            selected_quantities = [r['quantité_g'] for r in results[:10]]
            
            # This is a simplified verification
            targets = np.array(user_targets[:4] + [25]) * meal_fraction
            if portion_legumes > 0:
                targets = np.concatenate((targets, [portion_legumes]))
                
            response['verification'] = {
                'targets': targets.tolist(),
                'obtained': 'calculated'  # Simplified for this version
            }

        logger.info(f"Optimization complete: {len(results)} products")
        return jsonify(response), 200

    except Exception as e:
        logger.error(f"Optimization error: {str(e)}")
        logger.error(traceback.format_exc())
        return jsonify({'error': str(e)}), 500


@app.route('/', methods=['GET'])
def index():
    """Root endpoint"""
    return jsonify({
        'service': 'Nutria Meal Optimizer',
        'version': '2.0.0',
        'endpoints': {
            '/': 'This info',
            '/health': 'Health check (GET)',
            '/optimize': 'Meal optimization (POST)'
        },
        'mode': 'LOCAL' if IS_LOCAL else 'AWS',
        'data_source': 'local_file' if IS_LOCAL else 's3'
    }), 200


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    logger.info(f"Starting Flask app on port {port}")
    app.run(host='0.0.0.0', port=port, debug=IS_LOCAL)
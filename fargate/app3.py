from operator import contains
from typing import List

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


def apply_categories(products: pl.DataFrame, regime: str):
    filtered_products = products

    match regime:
        case "Vegan":
            filtered_products = products.filter(pl.col("vegan") == True)
        case "Vegetarian":
            filtered_products = products.filter(pl.col("vegetarian") == True | (pl.col("meat") == False))
        case "Halal":
            filtered_products = products.filter(pl.col("halal") == True | (pl.col("vegetarian") == True))
        case "Casher":
            filtered_products = products.filter(pl.col("casher") == True)
        case "Sans Gluten":
            filtered_products = filtered_products.filter(pl.col("gluten_free") == True)
        case "Bio":
            filtered_products = filtered_products.filter(pl.col("bio") == True)

    return filtered_products

def create_optimal_meals_hybrid(user_targets, products_df, solveur="hybride", meal_fraction=0.3, portion_legumes=100,
                                 regime:str= ""):
    """Hybrid meal optimization method"""
    try:

        products_df = apply_categories(products_df, regime)
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
        logger.info("Cleaning nutrition data...")
        for col in nutr_cols:
            products_df = products_df.with_columns(
                pl.col(col).fill_nan(0.0).fill_null(0.0)
            )

        arr = products_df.select(nutr_cols).to_numpy() / 100.0

        # Additional safety check: replace any remaining NaN/inf with 0
        arr = np.nan_to_num(arr, nan=0.0, posinf=0.0, neginf=0.0)

        M = arr.T

        logger.info(f"Matrix shape: {M.shape}")

        # Bounds
        lwr_bound = np.zeros(M.shape[1])
        higher_bound = products_df["portion_maximale"].to_numpy()

        if solveur == "hybride":
            logger.info("Using hybrid optimization method")
            # Step 1: NNLS selection
            x_init, _ = nnls(M, targets)
            masque_x = x_init > 0

            indices_conserves = np.where(masque_x)[0]
            logger.info(f"NNLS selected {len(indices_conserves)} products")

            if len(indices_conserves) == 0:
                logger.warning("No products selected by NNLS, using fallback")
                nutrition_scores = np.sum(arr, axis=1)
                top_indices = np.argsort(nutrition_scores)[-50:]
                indices_conserves = top_indices
                masque_x = np.zeros(len(products_df), dtype=bool)
                masque_x[indices_conserves] = True

            # Step 2: Filter and optimize
            M_filtre = M[:, masque_x]
            products_filtre = products_df.filter(
                pl.Series(range(len(products_df))).is_in(indices_conserves.tolist())
            )

            lwr_bound_filtre = np.zeros(M_filtre.shape[1])
            uppr_bound_filtre = products_filtre["portion_maximale"].to_numpy()

            logger.info(f"Running LSQ optimization on {M_filtre.shape[1]} products")
            result = lsq_linear(M_filtre, targets, bounds=(lwr_bound_filtre, uppr_bound_filtre), method="bvls")
            x = result.x
            obtained = M_filtre @ x

            plan_data = {
                "product_name": products_filtre["product_name"].to_list(),
                "quantité_g": x.tolist()
            }
        else:
            logger.info(f"Using {solveur} optimization method")
            # Simple NNLS
            x, _ = nnls(M, targets)
            obtained = M @ x
            plan_data = {
                "product_name": products_df["product_name"].to_list(),
                "quantité_g": x.tolist()
            }

        # Filter and sort
        plan_df = pl.DataFrame(plan_data).filter(pl.col("quantité_g") > 1e-6).sort("quantité_g", descending=True)
        meal_plan = plan_df.to_dicts()

        verification = {
            "obtained": obtained.tolist(),
            "targets": targets.tolist()
        }

        logger.info(f"Optimization completed. {len(meal_plan)} products in plan")
        return meal_plan, verification

    except Exception as e:
        logger.error(f"Optimization error: {str(e)}")
        logger.error(traceback.format_exc())
        raise


@app.route('/health', methods=['GET'])
def health_check():
    """Enhanced health check endpoint"""
    try:
        logger.info("Health check requested")

        # Basic health info
        health_info = {
            'status': 'healthy',
            'service': 'nutria-meal-optimizer',
            'version': '3.0.0',
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

        logger.info(f"Health check response: {health_info}")
        return jsonify(health_info), 200

    except Exception as e:
        logger.error(f"Health check error: {str(e)}")
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500


@app.route('/optimize', methods=['POST'])
def optimize_meal():
    """Enhanced meal optimization endpoint"""
    try:
        logger.info("Optimization request received")

        # Load data using hybrid method
        try:
            products_df = load_data_hybrid()
            logger.info(f"Loaded {len(products_df)} products from {('local file' if IS_LOCAL else 'S3')}")
        except Exception as e:
            logger.error(f"Failed to load data: {str(e)}")
            return jsonify({'error': f'Data loading failed: {str(e)}'}), 500

        # Parse request
        data = request.get_json()
        if not data:
            logger.error("No JSON data in request")
            return jsonify({'error': 'No JSON data provided'}), 400

        user_data = data.get('user')
        meal_fraction = data.get('meal_fraction', 0.3)
        solveur = data.get('solveur', 'hybride')
        sample_size = data.get('sample_size', 1000)
        target_legumes = data.get('target_legumes', 100)
        regime = data.get('regime', "")

        logger.info(f"Request params: fraction={meal_fraction}, solver={solveur}, sample={sample_size}, legumes={target_legumes}")

        if not user_data or 'target_array' not in user_data:
            logger.error("Missing user data or target_array")
            return jsonify({'error': 'Missing user data with target_array'}), 400

        logger.info(f"Target array: {user_data['target_array']}")

        # Sample if needed
        if len(products_df) > sample_size:
            products_df = products_df.sample(sample_size)
            logger.info(f"Sampled down to {sample_size} products")

        # Run optimization
        meal_plan, verification = create_optimal_meals_hybrid(
            user_data['target_array'], products_df, solveur, meal_fraction, target_legumes, regime
        )

        response_data = {
            "meal_plan": meal_plan,
            "verification": verification,
            "solver": solveur,
            "products_used": len(meal_plan),
            "target_legumes": target_legumes,
            "regime": regime,
            "deployment_info": {
                "type": "local" if IS_LOCAL else "fargate",
                "optimization_method": "hybrid",
                "logs_enabled": True,
                "data_source": "local_file" if IS_LOCAL else "s3"
            }
        }

        logger.info(f"Returning response with {len(meal_plan)} products")
        return jsonify(response_data), 200

    except Exception as e:
        logger.error(f"Optimization endpoint error: {str(e)}")
        logger.error(traceback.format_exc())
        return jsonify({'error': str(e)}), 500


@app.route('/', methods=['GET'])
def root():
    """Root endpoint with service info"""
    logger.info("Root endpoint accessed")
    return jsonify({
        'service': 'Nutria Meal Optimizer',
        'version': '3.0.0',
        'deployment': 'local' if IS_LOCAL else 'fargate',
        'optimization_methods': ['nnls', 'lsq', 'hybride'],
        'status': 'running',
        'mode': 'LOCAL' if IS_LOCAL else 'AWS',
        'data_source': 'local_file' if IS_LOCAL else 's3'
    }), 200


# Add error handlers
@app.errorhandler(404)
def not_found(error):
    logger.warning(f"404 error: {request.url}")
    return jsonify({'error': 'Endpoint not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    logger.error(f"500 error: {str(error)}")
    return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    logger.info(f"Starting Flask app on port {port}")

    # Test basic functionality on startup
    try:
        logger.info("Testing basic imports...")
        logger.info(f"NumPy version: {np.__version__}")
        logger.info(f"Polars version: {pl.__version__}")
        logger.info("✅ All imports successful")
    except Exception as e:
        logger.error(f"❌ Import test failed: {e}")

    app.run(host='0.0.0.0', port=port, debug=IS_LOCAL)
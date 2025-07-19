# fargate/app.py - Web server for Fargate with hybrid optimization
from flask import Flask, request, jsonify
import json
import os
import numpy as np
import polars as pl
from scipy.optimize import nnls, lsq_linear
import boto3
from io import StringIO
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

def create_optimal_meals_hybrid(user_targets, products_df, solveur="hybride", meal_fraction=0.3):
    """
    Advanced meal optimization using your hybrid method
    Combines NNLS selection with LSQ_LINEAR bounds optimization
    """
    # Apply meal fraction to targets
    targets = np.array(user_targets) * meal_fraction

    # Add fiber target (25g * meal_fraction)
    targets = np.append(targets[:4], 25 * meal_fraction)

    logger.info(f"Optimization targets: {targets}")

    # Prepare nutrition matrix
    nutr_cols = ["energy-kcal", "proteins", "fat", "carbohydrates", "fiber"]

    # Check for missing columns and handle gracefully
    missing_cols = [col for col in nutr_cols if col not in products_df.columns]
    if missing_cols:
        logger.warning(f"Missing columns: {missing_cols}, will use zeros")
        for col in missing_cols:
            products_df = products_df.with_columns(pl.lit(0.0).alias(col))

    # Check for portion_maximale column
    if "portion_maximale" not in products_df.columns:
        logger.info("No portion_maximale column found, creating default (200g)")
        products_df = products_df.with_columns(pl.lit(200.0).alias("portion_maximale"))

    arr = products_df.select(nutr_cols).to_numpy() / 100.0
    M = arr.T

    logger.info(f"Matrix shape: {M.shape}, Targets shape: {targets.shape}")

    # Bounds for optimization
    lwr_bound = np.zeros(M.shape[1])
    higher_bound = products_df["portion_maximale"].to_numpy()

    if solveur == "nnls":
        # Simple NNLS without bounds
        x, residuals = nnls(M, targets)
        obtained = M @ x

        plan_data = {
            "product_name": products_df["product_name"].to_list(),
            "quantité_g": x.tolist()
        }

    elif solveur == "lsq":
        # LSQ with bounds but uses all products
        result = lsq_linear(
            M,
            targets,
            bounds=(lwr_bound, higher_bound),
            method="bvls",
        )
        x = result.x
        obtained = M @ x

        plan_data = {
            "product_name": products_df["product_name"].to_list(),
            "quantité_g": x.tolist()
        }

    elif solveur == "hybride":
        # Your sophisticated hybrid method
        logger.info("Using hybrid optimization method...")

        # Step 1: NNLS to select relevant products
        x_init, _ = nnls(M, targets)
        masque_x = x_init > 0

        indices_conserves = np.where(masque_x)[0]
        logger.info(f"NNLS selected {len(indices_conserves)} products out of {len(products_df)}")

        if len(indices_conserves) == 0:
            logger.warning("No products selected by NNLS, falling back to top products")
            # Fallback: select products with highest overall nutrition density
            nutrition_scores = np.sum(arr, axis=1)
            top_indices = np.argsort(nutrition_scores)[-50:]  # Top 50 products
            indices_conserves = top_indices
            masque_x = np.zeros(len(products_df), dtype=bool)
            masque_x[indices_conserves] = True

        # Step 2: Filter matrix and products
        M_filtre = M[:, masque_x]
        products_filtre = products_df.filter(
            pl.Series(range(len(products_df))).is_in(indices_conserves.tolist())
        )

        # Step 3: Apply bounds optimization on filtered set
        lwr_bound_filtre = np.zeros(M_filtre.shape[1])
        uppr_bound_filtre = products_filtre["portion_maximale"].to_numpy()

        logger.info(f"Filtered matrix shape: {M_filtre.shape}")

        result = lsq_linear(
            M_filtre,
            targets,
            bounds=(lwr_bound_filtre, uppr_bound_filtre),
            method="bvls",
        )
        x = result.x
        obtained = M_filtre @ x

        plan_data = {
            "product_name": products_filtre["product_name"].to_list(),
            "quantité_g": x.tolist()
        }

    else:
        raise ValueError(f"Unknown solver: {solveur}")

    # Filter significant quantities and sort
    plan_df = pl.DataFrame(plan_data).filter(
        pl.col("quantité_g") > 1e-6
    ).sort("quantité_g", descending=True)

    meal_plan = plan_df.to_dicts()

    # Create verification data
    nutrient_names = ["energy-kcal", "proteins", "fat", "carbohydrates", "fiber"]
    verification = {
        "nutrients": nutrient_names,
        "obtained": obtained.tolist(),
        "targets": targets.tolist(),
        "achievement_ratio": (obtained / (targets + 1e-10)).tolist()  # Avoid division by zero
    }

    logger.info(f"Optimization completed. Selected {len(meal_plan)} products")
    logger.info(f"Target achievement: {[f'{r:.2%}' for r in verification['achievement_ratio']]}")

    return meal_plan, verification

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for ALB"""
    return jsonify({
        'status': 'healthy',
        'service': 'nutria-meal-optimizer',
        'deployment': 'fargate',
        'optimization_methods': ['nnls', 'lsq', 'hybride']
    }), 200

@app.route('/optimize', methods=['POST'])
def optimize_meal():
    """
    Advanced meal optimization endpoint with hybrid method
    """
    try:
        # Get S3 configuration from environment variables
        bucket_name = os.environ.get('S3_BUCKET_NAME')
        file_key = os.environ.get('CSV_FILE_KEY')

        if not bucket_name or not file_key:
            return jsonify({
                'error': 'S3 configuration missing from environment variables'
            }), 500

        # Extract parameters from request
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400

        user_data = data.get('user')
        meal_fraction = data.get('meal_fraction', 0.3)
        sample_size = data.get('sample_size', 10000)  # Increased for better optimization
        solveur = data.get('solveur', 'hybride')  # Default to your hybrid method

        # Filter options
        exclude_snacks = data.get('exclude_snacks', True)
        exclude_desserts = data.get('exclude_desserts', True)
        exclude_drinks = data.get('exclude_drinks', True)
        exclude_condiments = data.get('exclude_condiments', True)
        exclude_complements = data.get('exclude_complements', True)

        if not user_data or 'target_array' not in user_data:
            return jsonify({
                'error': 'Missing user data with target_array'
            }), 400

        logger.info(f"Processing optimization request with solver: {solveur}")

        # Load products from S3
        try:
            s3_client = boto3.client('s3')
            response = s3_client.get_object(Bucket=bucket_name, Key=file_key)
            csv_content = response['Body'].read().decode('utf-8')

            # Load with polars and apply filters like in your original code
            products_df = pl.read_csv(
                StringIO(csv_content),
                ignore_errors=True
            )

            # Apply your filtering logic
            filter_conditions = []
            if exclude_snacks and "snacks" in products_df.columns:
                filter_conditions.append(pl.col("snacks") == False)
            if exclude_desserts and "desserts" in products_df.columns:
                filter_conditions.append(pl.col("desserts") == False)
            if exclude_drinks and "drinks" in products_df.columns:
                filter_conditions.append(pl.col("drinks") == False)
            if exclude_condiments and "condiments" in products_df.columns:
                filter_conditions.append(pl.col("condiments") == False)
            if exclude_complements and "complements" in products_df.columns:
                filter_conditions.append(pl.col("complements") == False)

            if filter_conditions:
                products_df = products_df.filter(*filter_conditions)
                logger.info(f"Applied filters, {len(products_df)} products remaining")

            logger.info(f"Loaded {len(products_df)} products from S3")

        except Exception as s3_error:
            logger.error(f"S3 error: {s3_error}")
            return jsonify({
                'error': f'Failed to read from S3: {str(s3_error)}'
            }), 500

        # Sample products if needed (like your subset_produits function)
        if len(products_df) > sample_size:
            products_df = products_df.sample(sample_size)
            logger.info(f"Sampled down to {sample_size} products")

        # Run your hybrid optimization
        try:
            meal_plan, verification = create_optimal_meals_hybrid(
                user_data['target_array'],
                products_df,
                solveur=solveur,
                meal_fraction=meal_fraction
            )
        except Exception as opt_error:
            logger.error(f"Optimization error: {opt_error}")
            return jsonify({
                'error': f'Optimization failed: {str(opt_error)}'
            }), 500

        # Calculate residual for comparison
        targets = np.array(user_data['target_array']) * meal_fraction
        targets = np.append(targets[:4], 25 * meal_fraction)
        obtained = np.array(verification['obtained'])
        residual = np.linalg.norm(targets - obtained)

        response_data = {
            "meal_plan": meal_plan,
            "verification": verification,
            "solver": solveur,
            "products_used": len(meal_plan),
            "total_products_available": len(products_df),
            "residual": float(residual),
            "meal_fraction": meal_fraction,
            "filters_applied": {
                "exclude_snacks": exclude_snacks,
                "exclude_desserts": exclude_desserts,
                "exclude_drinks": exclude_drinks,
                "exclude_condiments": exclude_condiments,
                "exclude_complements": exclude_complements
            },
            "deployment_info": {
                "type": "fargate",
                "optimization_method": "hybrid_nnls_lsq",
                "full_scipy": True,
                "numpy_version": np.__version__,
                "polars_available": True,
                "container_cpu": "512m",
                "container_memory": "1024MB"
            }
        }

        logger.info(f"Returning meal plan with {len(meal_plan)} products, residual: {residual:.4f}")
        return jsonify(response_data), 200

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return jsonify({
            'error': f'Optimization failed: {str(e)}'
        }), 500

@app.route('/', methods=['GET'])
def root():
    """Root endpoint"""
    return jsonify({
        'service': 'Nutria Meal Optimizer',
        'version': '2.0.0',
        'deployment': 'fargate',
        'optimization_methods': {
            'nnls': 'Non-negative least squares (simple)',
            'lsq': 'Bounded least squares (respects portion limits)',
            'hybride': 'Hybrid method (NNLS selection + LSQ bounds)'
        },
        'endpoints': {
            '/health': 'Health check',
            '/optimize': 'POST - Advanced meal optimization'
        }
    }), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
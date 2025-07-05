import numpy as np
import polars as pl
from scipy.optimize import nnls
from algo_repas.targets import User


def create_optimal_meals(user: User, products: pl.DataFrame):
    """
    Permet de calculer un repas selon les cibles de l'utilisateur et les produits disponibles.
    """
    targets = user.get_target()

    nutr_cols = ["energy-kcal","proteins", "fat", "carbohydrates"]
    arr = products.select(nutr_cols).to_numpy() / 100.0
    M = arr.T

    x, _ = nnls(M, targets)

    # 5. Formatage du plan en polars
    plan = pl.DataFrame({
        "product_name": products["product_name"].to_list(),
        "quantité_g": x
    }).filter(pl.col("quantité_g") > 1e-6)

    # 6. Calcul des apports obtenus pour vérifier
    obtained = M @ x
    check = pl.DataFrame({
        "nutriment": ["energy-kcal","proteins", "fat", "carbohydrates"],
        "obtenu_g": obtained,
        "cible_g": targets
    })

    print("Plan optimisé :")
    print(plan)
    print("\nVérif. apports :")
    print(check)


if __name__ == "__main__":
    user = User(
        "Test",
        "male",
        26,
        178,
        68,
        "moderate",
        "weight loss",
    )

    products = pl.read_csv(
        "../data_prep/data/products_names_with_macro_nutriments.csv",
        schema_overrides={
            "code": pl.Utf8,
        }

    ).filter(
        pl.col("snacks") == False,
        pl.col("desserts") == False,
        pl.col("drinks") == False,
        pl.col("condiments") == False,
    )

    create_optimal_meals(user, products)
